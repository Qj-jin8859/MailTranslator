import AppKit
import CryptoKit
import Foundation

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let detector = LanguageDetector()
    private let extractor = MailBodyExtractor()
    private let bodyCleaner = MailBodyCleaner()
    private let translationCache = TranslationCache.shared
    private let launchAtLogin = LaunchAtLoginManager()
    private let monitor = MailMonitor()
    private let panel = TranslationPanelController()
    private lazy var settingsWindow = SettingsWindowController()
    private lazy var diagnosticsWindow = DiagnosticsWindowController()

    private var statusItem: NSStatusItem?
    private var autoEnableItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?
    private var nextDetectionIsForced = false
    private var translationTask: Task<Void, Never>?
    private var translationGeneration = 0
    private var translationIndicatorTimer: Timer?
    private var translationIndicatorDots = 1
    private var lastErrorAlertDate: Date?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        monitor.delegate = self
        monitor.start()

        Task.detached {
            await TranslationCache.shared.warmUp()
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.recoverLaunchAtLoginIfNeeded()
            DispatchQueue.main.async {
                self?.rebuildMenu()
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.showOnboardingIfNeeded()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        stopTranslationIndicator()
        monitor.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.imagePosition = .imageLeading
            button.title = ""

            if let url = Bundle.main.url(forResource: "menu-bar-icon", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                image.isTemplate = true
                image.size = NSSize(width: 25, height: 18)
                image.accessibilityDescription = "MailTranslator"
                button.image = image
            } else {
                button.image = NSImage(
                    systemSymbolName: "character.bubble",
                    accessibilityDescription: "MailTranslator"
                )
            }
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let autoItem = NSMenuItem(
            title: autoTranslateTitle(for: settings.autoTranslateLanguage),
            action: nil,
            keyEquivalent: ""
        )

        let autoMenu = NSMenu()
        let enableItem = NSMenuItem(
            title: "启用自动翻译",
            action: #selector(toggleAutoTranslate),
            keyEquivalent: ""
        )
        enableItem.target = self
        enableItem.state = settings.autoTranslateEnabled ? .on : .off
        autoEnableItem = enableItem
        autoMenu.addItem(enableItem)
        autoMenu.addItem(.separator())

        let autoLanguageCode = settings.syncTargetLanguage
            ? settings.targetLanguage
            : settings.autoTranslateLanguage
        for language in AppSettings.supportedTargetLanguages {
            let item = NSMenuItem(
                title: language.title,
                action: #selector(selectAutoTranslateLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.code
            item.state = autoLanguageCode == language.code ? .on : .off
            item.isEnabled = !settings.syncTargetLanguage
            autoMenu.addItem(item)
        }

        autoItem.submenu = autoMenu
        menu.addItem(autoItem)

        let launchItem = NSMenuItem(
            title: "开机自动启动",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = menuState(for: launchAtLogin.status())
        launchAtLoginItem = launchItem
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let translateNowItem = NSMenuItem(
            title: "立即翻译当前邮件",
            action: #selector(translateNow),
            keyEquivalent: ""
        )
        translateNowItem.target = self
        menu.addItem(translateNowItem)

        let targetItem = NSMenuItem(title: "目标语言", action: nil, keyEquivalent: "")
        targetItem.state = settings.syncTargetLanguage ? .on : .off

        let targetMenu = NSMenu()
        for language in AppSettings.supportedTargetLanguages {
            let item = NSMenuItem(
                title: language.title,
                action: #selector(selectTargetLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.code
            item.state = settings.targetLanguage == language.code ? .on : .off
            targetMenu.addItem(item)
        }
        targetItem.submenu = targetMenu

        let syncItem = NSMenuItem(
            title: "与目标语言同步",
            action: #selector(toggleSyncTargetLanguage),
            keyEquivalent: ""
        )
        syncItem.target = self
        syncItem.state = settings.syncTargetLanguage ? .on : .off
        menu.addItem(syncItem)

        menu.addItem(targetItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "偏好设置…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let diagnosticsItem = NSMenuItem(
            title: "诊断信息…",
            action: #selector(showDiagnostics),
            keyEquivalent: ""
        )
        diagnosticsItem.target = self
        menu.addItem(diagnosticsItem)

        let clearCacheItem = NSMenuItem(
            title: "清空翻译缓存",
            action: #selector(clearTranslationCache),
            keyEquivalent: ""
        )
        clearCacheItem.target = self
        menu.addItem(clearCacheItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleAutoTranslate() {
        settings.autoTranslateEnabled.toggle()
        autoEnableItem?.state = settings.autoTranslateEnabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        let shouldEnable = !launchAtLogin.isEnabled()
        settings.launchAtLoginEnabled = shouldEnable

        do {
            try launchAtLogin.setEnabled(shouldEnable)
        } catch {
            AppLog.general.error("开机自启更新失败：\(error.localizedDescription, privacy: .public)")
            presentError(message: error.localizedDescription)
        }

        rebuildMenu()

        if shouldEnable, launchAtLogin.status() == .requiresApproval {
            presentLaunchAtLoginApprovalAlert()
        }
    }

    @objc private func translateNow() {
        nextDetectionIsForced = true
        monitor.poll(force: true)
    }

    @objc private func selectTargetLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        settings.targetLanguage = code
        if settings.syncTargetLanguage {
            settings.autoTranslateLanguage = code
        }
        rebuildMenu()
    }

    @objc private func selectAutoTranslateLanguage(_ sender: NSMenuItem) {
        guard !settings.syncTargetLanguage,
              let code = sender.representedObject as? String else {
            return
        }

        settings.autoTranslateLanguage = code
        rebuildMenu()
    }

    @objc private func toggleSyncTargetLanguage() {
        let enabled = !settings.syncTargetLanguage
        settings.syncTargetLanguage = enabled
        if enabled {
            settings.autoTranslateLanguage = settings.targetLanguage
        }
        rebuildMenu()
    }

    @objc private func openSettings() {
        settingsWindow.onSettingsChanged = { [weak self] in
            self?.settingsDidChange()
        }
        settingsWindow.showSettings()
    }

    @objc private func showDiagnostics() {
        diagnosticsWindow.showDiagnostics()
    }

    @objc private func clearTranslationCache() {
        Task {
            await TranslationCache.shared.removeAll()
        }
    }

    private func settingsDidChange() {
        rebuildMenu()
        monitor.restart()
    }

    private func autoTranslateTitle(for code: String) -> String {
        let title = AppSettings.supportedTargetLanguages.first {
            $0.code == code
        }?.title ?? code
        return "自动翻译非\(title)邮件"
    }

    private func menuState(for status: LaunchAtLoginStatus) -> NSControl.StateValue {
        switch status {
        case .enabled:
            return .on
        case .requiresApproval:
            return .mixed
        case .disabled, .unavailable:
            return .off
        }
    }

    private func recoverLaunchAtLoginIfNeeded() {
        guard settings.launchAtLoginEnabled else { return }

        let status = launchAtLogin.status()
        switch status {
        case .enabled:
            return
        case .requiresApproval:
            AppLog.general.notice("开机自启需要用户授权，等待用户处理。")
            return
        case .disabled:
            settings.launchAtLoginEnabled = false
            AppLog.general.notice("开机自启已在系统设置中被关闭，已同步本机状态。")
        case .unavailable:
            do {
                try launchAtLogin.setEnabled(true)
                AppLog.general.notice("已尝试恢复开机自启。")
            } catch {
                AppLog.general.error("恢复开机自启失败：\(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func presentLaunchAtLoginApprovalAlert() {
        let alert = NSAlert()
        alert.messageText = "需要允许开机启动"
        alert.informativeText = "请在系统设置中允许 MailTranslator 开机自动启动。"
        alert.addButton(withTitle: "打开登录项设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            launchAtLogin.openSystemSettingsLoginItems()
        }
    }

    private func showOnboardingIfNeeded() {
        guard !settings.hasCompletedOnboarding else { return }

        let alert = NSAlert()
        alert.messageText = "欢迎使用 MailTranslator"
        alert.informativeText = """
        它会自动识别 Mail.app 当前选中的邮件，并在邮件不是中文时翻译成你选择的目标语言。

        首次使用需要允许“邮件”自动化权限。若希望获得更低的响应延迟，建议再到“系统设置 → 隐私与安全性 → 辅助功能”中允许 MailTranslator。

        建议将 App 放入“应用程序”文件夹，并开启菜单栏中的“开机自动启动”。
        """
        alert.addButton(withTitle: "开始使用")
        alert.addButton(withTitle: "打开辅助功能设置")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            openAccessibilitySettings()
        }

        settings.hasCompletedOnboarding = true
    }

    private func openAccessibilitySettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func handle(_ snapshot: MailSnapshot, force: Bool) {
        guard force || settings.autoTranslateEnabled else { return }

        let extractedBody = extractor.extract(
            content: snapshot.body,
            source: snapshot.source
        )
        let cleanedBody = bodyCleaner.clean(extractedBody)
        let detectionText = "\(snapshot.subject)\n\n\(cleanedBody)"
        let bodyHash = stableHash(cleanedBody)
        let targetLanguage = force
            ? settings.targetLanguage
            : settings.autoTranslateLanguage
        let detectedLanguage = detector.detect(detectionText)

        if detector.isSameLanguage(detectedLanguage, target: targetLanguage) {
            return
        }
        let sourceCode = detectedLanguage.code ?? "und"

        translationTask?.cancel()
        translationGeneration += 1
        let generation = translationGeneration
        startTranslationIndicator()

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let translator = self.makeTranslator()
                let translatorName = translator.displayName

                if !force,
                   let cached = await self.translationCache.translation(
                       messageID: snapshot.messageID,
                       sourceCode: sourceCode,
                       targetLanguage: targetLanguage,
                       bodyHash: bodyHash,
                       translatorName: translatorName
                   ) {
                    guard generation == self.translationGeneration else { return }
                    self.panel.show(
                        subject: snapshot.subject,
                        original: cleanedBody,
                        translated: cached.text,
                        source: cached.translatorName,
                        showOriginal: self.settings.showOriginalText
                    )
                    self.stopTranslationIndicator()
                    return
                }

                let translated = try await translator.translate(
                    cleanedBody,
                    from: sourceCode,
                    to: targetLanguage
                )
                guard generation == self.translationGeneration else { return }
                await self.translationCache.store(
                    messageID: snapshot.messageID,
                    sourceCode: sourceCode,
                    targetLanguage: targetLanguage,
                    bodyHash: bodyHash,
                    translatorName: translatorName,
                    translatedText: translated
                )
                self.panel.show(
                    subject: snapshot.subject,
                    original: cleanedBody,
                    translated: translated,
                    source: translatorName,
                    showOriginal: self.settings.showOriginalText
                )
                self.stopTranslationIndicator()
            } catch {
                guard generation == self.translationGeneration else { return }
                self.stopTranslationIndicator()

                if let translatorError = error as? TranslatorError,
                   case .appleTranslationFailed(let detail) = translatorError {
                    self.presentAppleTranslationHelp(detail: detail)
                } else {
                    self.presentTranslationFailure(
                        message: error.localizedDescription,
                        snapshot: snapshot,
                        force: force
                    )
                }
            }
        }

        translationTask = task
    }

    private func stableHash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func startTranslationIndicator() {
        translationIndicatorDots = 1
        updateTranslationIndicator()

        guard translationIndicatorTimer == nil else { return }
        translationIndicatorTimer = Timer.scheduledTimer(
            withTimeInterval: 0.35,
            repeats: true
        ) { [weak self] _ in
            self?.advanceTranslationIndicator()
        }
    }

    private func advanceTranslationIndicator() {
        translationIndicatorDots = translationIndicatorDots >= 3
            ? 1
            : translationIndicatorDots + 1
        updateTranslationIndicator()
    }

    private func updateTranslationIndicator() {
        statusItem?.button?.title = "正在翻译中"
            + String(repeating: ".", count: translationIndicatorDots)
    }

    private func stopTranslationIndicator() {
        translationIndicatorTimer?.invalidate()
        translationIndicatorTimer = nil
        statusItem?.button?.title = ""
    }

    private func makeTranslator() -> Translating {
        if !settings.deepSeekAPIKey.isEmpty {
            return DeepSeekTranslator(
                apiKey: settings.deepSeekAPIKey,
                model: settings.deepSeekModel
            )
        }

        if #available(macOS 26.0, *) {
            return AppleTranslator()
        }

        return PassThroughTranslator()
    }

    private func presentError(message: String) {
        DiagnosticsStore.shared.record(message)
        AppLog.general.error("\(message, privacy: .public)")

        let now = Date()
        if let last = lastErrorAlertDate, now.timeIntervalSince(last) < 5 {
            return
        }
        lastErrorAlertDate = now

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "邮件翻译失败"
        alert.informativeText = message
        alert.runModal()
    }

    private func presentTranslationFailure(
        message: String,
        snapshot: MailSnapshot,
        force: Bool
    ) {
        DiagnosticsStore.shared.record(message)
        AppLog.translation.error("\(message, privacy: .public)")

        let alert = NSAlert()
        alert.messageText = "邮件翻译失败"
        alert.informativeText = message
        alert.addButton(withTitle: "重试")
        alert.addButton(withTitle: "关闭")

        if alert.runModal() == .alertFirstButtonReturn {
            handle(snapshot, force: force)
        }
    }

    private func presentAppleTranslationHelp(detail: String) {
        let message = "Apple 翻译不可用：\(detail)"
        DiagnosticsStore.shared.record(message)
        AppLog.translation.error("\(message, privacy: .public)")

        let alert = NSAlert()
        alert.messageText = "Apple 翻译不可用"
        alert.informativeText = "可能是系统尚未下载对应语言包。你可以在偏好设置中改用 DeepSeek，或稍后重试。"
        alert.addButton(withTitle: "打开偏好设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }
}

extension AppDelegate: MailMonitorDelegate {
    func mailMonitor(_ monitor: MailMonitor, didDetect snapshot: MailSnapshot) {
        let force = nextDetectionIsForced
        nextDetectionIsForced = false
        handle(snapshot, force: force)
    }

    func mailMonitor(_ monitor: MailMonitor, didFailWith error: Error) {
        if let mailError = error as? MailReaderError {
            switch mailError {
            case .noViewer, .noSelection:
                return
            default:
                break
            }
        }

        AppLog.mail.error("邮件监听失败：\(error.localizedDescription, privacy: .public)")
        presentError(message: error.localizedDescription)
    }
}
