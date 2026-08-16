import AppKit

final class SettingsWindowController: NSWindowController {
    var onSettingsChanged: (() -> Void)?

    private let settings = AppSettings.shared

    private var autoTranslateCheckbox: NSButton!
    private var showOriginalCheckbox: NSButton!
    private var syncTargetLanguageCheckbox: NSButton!
    private var offlineOnlyCheckbox: NSButton!
    private var targetLanguagePopup: NSPopUpButton!
    private var deepSeekModelPopup: NSPopUpButton!
    private var pollingIntervalField: NSTextField!
    private var deepSeekAPIKeyField: NSTextField!
    private var pasteDeepSeekAPIKeyButton: NSButton!
    private var clearDeepSeekAPIKeyButton: NSButton!

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MailTranslator 设置"
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showSettings() {
        refreshControls()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        autoTranslateCheckbox = NSButton(
            checkboxWithTitle: "自动翻译非中文邮件",
            target: self,
            action: #selector(autoTranslateChanged)
        )

        showOriginalCheckbox = NSButton(
            checkboxWithTitle: "在浮窗中显示原文",
            target: self,
            action: #selector(showOriginalChanged)
        )

        syncTargetLanguageCheckbox = NSButton(
            checkboxWithTitle: "与目标语言同步",
            target: self,
            action: #selector(syncTargetLanguageChanged)
        )

        offlineOnlyCheckbox = NSButton(
            checkboxWithTitle: "仅离线翻译，不发送邮件到云端",
            target: self,
            action: #selector(offlineOnlyChanged)
        )

        targetLanguagePopup = NSPopUpButton()
        targetLanguagePopup.target = self
        targetLanguagePopup.action = #selector(targetLanguageChanged)
        for language in AppSettings.supportedTargetLanguages {
            targetLanguagePopup.addItem(withTitle: language.title)
        }

        deepSeekModelPopup = NSPopUpButton()
        deepSeekModelPopup.target = self
        deepSeekModelPopup.action = #selector(deepSeekModelChanged)
        deepSeekModelPopup.addItem(withTitle: "deepseek-chat")
        deepSeekModelPopup.addItem(withTitle: "deepseek-reasoner")

        pollingIntervalField = NSTextField()
        pollingIntervalField.target = self
        pollingIntervalField.action = #selector(pollingIntervalChanged)
        pollingIntervalField.delegate = self

        deepSeekAPIKeyField = NSTextField()
        deepSeekAPIKeyField.placeholderString = "粘贴 DeepSeek API Key"
        deepSeekAPIKeyField.target = self
        deepSeekAPIKeyField.action = #selector(deepSeekAPIKeyChanged)
        deepSeekAPIKeyField.delegate = self

        pasteDeepSeekAPIKeyButton = NSButton(
            title: "粘贴",
            target: self,
            action: #selector(pasteDeepSeekAPIKey)
        )
        clearDeepSeekAPIKeyButton = NSButton(
            title: "清空",
            target: self,
            action: #selector(clearDeepSeekAPIKey)
        )

        let deepSeekButtonsRow = NSStackView(views: [
            pasteDeepSeekAPIKeyButton,
            clearDeepSeekAPIKeyButton
        ])
        deepSeekButtonsRow.orientation = .horizontal
        deepSeekButtonsRow.spacing = 8

        let deepSeekContainer = NSStackView(views: [
            deepSeekAPIKeyField,
            deepSeekButtonsRow
        ])
        deepSeekContainer.orientation = .vertical
        deepSeekContainer.alignment = .leading
        deepSeekContainer.spacing = 8

        let grid = NSGridView(views: [
            [makeLabel("自动翻译"), autoTranslateCheckbox],
            [makeLabel("显示原文"), showOriginalCheckbox],
            [makeLabel("菜单同步"), syncTargetLanguageCheckbox],
            [makeLabel("隐私模式"), offlineOnlyCheckbox],
            [makeLabel("目标语言"), targetLanguagePopup],
            [makeLabel("DeepSeek 模型"), deepSeekModelPopup],
            [makeLabel("轮询间隔（秒）"), pollingIntervalField],
            [makeLabel("DeepSeek API Key"), deepSeekContainer]
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.column(at: 1).xPlacement = .fill

        guard let contentView = window?.contentView else { return }
        contentView.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            pollingIntervalField.widthAnchor.constraint(equalToConstant: 150),
            targetLanguagePopup.widthAnchor.constraint(equalToConstant: 170),
            deepSeekModelPopup.widthAnchor.constraint(equalToConstant: 190),
            deepSeekAPIKeyField.widthAnchor.constraint(equalToConstant: 500),
            pasteDeepSeekAPIKeyButton.widthAnchor.constraint(equalToConstant: 80),
            clearDeepSeekAPIKeyButton.widthAnchor.constraint(equalToConstant: 80)
        ])

        refreshControls()
    }

    private func refreshControls() {
        autoTranslateCheckbox?.state = settings.autoTranslateEnabled ? .on : .off
        showOriginalCheckbox?.state = settings.showOriginalText ? .on : .off
        syncTargetLanguageCheckbox?.state = settings.syncTargetLanguage ? .on : .off
        offlineOnlyCheckbox?.state = settings.offlineOnly ? .on : .off

        if let index = AppSettings.supportedTargetLanguages.firstIndex(where: {
            $0.code == settings.targetLanguage
        }) {
            targetLanguagePopup?.selectItem(at: index)
        }

        if let index = deepSeekModelPopup?.itemTitles.firstIndex(of: settings.deepSeekModel) {
            deepSeekModelPopup?.selectItem(at: index)
        }

        pollingIntervalField?.stringValue = String(format: "%.2f", settings.pollingInterval)
        deepSeekAPIKeyField?.stringValue = settings.deepSeekAPIKey
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
    }

    @objc private func autoTranslateChanged(_ sender: NSButton) {
        settings.autoTranslateEnabled = sender.state == .on
        onSettingsChanged?()
    }

    @objc private func showOriginalChanged(_ sender: NSButton) {
        settings.showOriginalText = sender.state == .on
        onSettingsChanged?()
    }

    @objc private func syncTargetLanguageChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        settings.syncTargetLanguage = enabled
        if enabled {
            settings.autoTranslateLanguage = settings.targetLanguage
        }
        onSettingsChanged?()
    }

    @objc private func offlineOnlyChanged(_ sender: NSButton) {
        settings.offlineOnly = sender.state == .on
        onSettingsChanged?()
    }

    @objc private func targetLanguageChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard AppSettings.supportedTargetLanguages.indices.contains(index) else { return }
        settings.targetLanguage = AppSettings.supportedTargetLanguages[index].code
        if settings.syncTargetLanguage {
            settings.autoTranslateLanguage = settings.targetLanguage
        }
        onSettingsChanged?()
    }

    @objc private func deepSeekModelChanged(_ sender: NSPopUpButton) {
        settings.deepSeekModel = sender.titleOfSelectedItem ?? "deepseek-chat"
        onSettingsChanged?()
    }

    @objc private func pollingIntervalChanged(_ sender: NSTextField) {
        applyPollingInterval(sender)
    }

    @objc private func deepSeekAPIKeyChanged(_ sender: NSTextField) {
        settings.deepSeekAPIKey = sender.stringValue
        onSettingsChanged?()
    }

    @objc private func pasteDeepSeekAPIKey() {
        guard let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty else {
            return
        }

        deepSeekAPIKeyField.stringValue = text
        settings.deepSeekAPIKey = text
        onSettingsChanged?()

        pasteDeepSeekAPIKeyButton.title = "已粘贴"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.pasteDeepSeekAPIKeyButton.title = "粘贴"
        }
    }

    @objc private func clearDeepSeekAPIKey() {
        deepSeekAPIKeyField.stringValue = ""
        settings.deepSeekAPIKey = ""
        onSettingsChanged?()
    }

}

extension SettingsWindowController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }

        if field === deepSeekAPIKeyField {
            settings.deepSeekAPIKey = field.stringValue
            onSettingsChanged?()
        } else if field === pollingIntervalField {
            applyPollingInterval(field)
        }
    }

    private func applyPollingInterval(_ field: NSTextField) {
        guard let value = Double(field.stringValue.replacingOccurrences(of: ",", with: ".")),
              value >= 0.25 else {
            field.stringValue = String(format: "%.2f", settings.pollingInterval)
            return
        }

        settings.pollingInterval = value
        onSettingsChanged?()
    }
}
