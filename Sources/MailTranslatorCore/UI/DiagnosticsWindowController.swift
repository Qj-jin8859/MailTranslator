import AppKit
import ApplicationServices
import Foundation

final class DiagnosticsWindowController: NSWindowController {
    private let textView = NSTextView()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MailTranslator 诊断信息"
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showDiagnostics() {
        textView.string = buildDiagnosticsText()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.frame = scrollView.contentView.bounds
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        guard let contentView = window?.contentView else { return }
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    private func buildDiagnosticsText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "dev"

        let loginStatus = LaunchAtLoginManager().status()
        let accessibility = AXIsProcessTrusted() ? "已授权" : "未授权"

        var lines: [String] = []
        lines.append("MailTranslator \(version)")
        lines.append("辅助功能权限：\(accessibility)")
        lines.append("开机自启状态：\(loginStatusText(loginStatus))")
        lines.append("缓存位置：~/Library/Application Support/MailTranslator/translation-cache.json")
        lines.append("")
        lines.append("最近错误：")

        let records = DiagnosticsStore.shared.snapshot()
        if records.isEmpty {
            lines.append("  （暂无）")
        } else {
            for record in records {
                lines.append("[\(formatter.string(from: record.date))] \(record.message)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func loginStatusText(_ status: LaunchAtLoginStatus) -> String {
        switch status {
        case .enabled:
            return "已开启"
        case .requiresApproval:
            return "需要授权"
        case .disabled:
            return "已关闭"
        case .unavailable:
            return "当前不可用"
        }
    }
}
