import AppKit

final class TranslationPanelController: NSWindowController {
    private let subjectLabel = NSTextField(labelWithString: "")
    private let sourceLabel = NSTextField(labelWithString: "翻译来源：—")
    private let originalTitle = NSTextField(labelWithString: "原文")
    private let translatedTitle = NSTextField(labelWithString: "译文")
    private let originalTextView = TranslationPanelController.makeTextView()
    private let translatedTextView = TranslationPanelController.makeTextView()
    private var originalScrollView: NSScrollView?
    private var translatedScrollView: NSScrollView?
    private var copyButton: NSButton!

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 640),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "邮件翻译"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        super.init(window: panel)
        buildContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(
        subject: String,
        original: String,
        translated: String,
        source: String,
        showOriginal: Bool
    ) {
        subjectLabel.stringValue = subject
        sourceLabel.stringValue = "翻译来源：\(source)"
        originalTextView.string = original
        translatedTextView.string = translated

        originalTitle.isHidden = !showOriginal
        originalScrollView?.isHidden = !showOriginal

        showWindow(nil)
        window?.orderFrontRegardless()
        positionNearCursor()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        subjectLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        subjectLabel.lineBreakMode = .byTruncatingTail
        subjectLabel.maximumNumberOfLines = 2

        sourceLabel.font = .systemFont(ofSize: 11)
        sourceLabel.textColor = .secondaryLabelColor

        originalTitle.font = .systemFont(ofSize: 12, weight: .medium)
        translatedTitle.font = .systemFont(ofSize: 12, weight: .medium)

        let originalScroll = TranslationPanelController.makeScrollView(for: originalTextView)
        let translatedScroll = TranslationPanelController.makeScrollView(for: translatedTextView)
        originalScrollView = originalScroll
        translatedScrollView = translatedScroll

        originalScroll.heightAnchor.constraint(equalToConstant: 180).isActive = true
        translatedScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        let copyButton = NSButton(
            title: "复制译文",
            target: self,
            action: #selector(copyTranslation)
        )
        self.copyButton = copyButton

        let copyContainer = NSView()
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyContainer.addSubview(copyButton)
        NSLayoutConstraint.activate([
            copyButton.trailingAnchor.constraint(equalTo: copyContainer.trailingAnchor),
            copyButton.centerYAnchor.constraint(equalTo: copyContainer.centerYAnchor)
        ])
        copyContainer.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let stack = NSStackView(views: [
            subjectLabel,
            sourceLabel,
            originalTitle,
            originalScroll,
            translatedTitle,
            translatedScroll,
            copyContainer
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            subjectLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            sourceLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            originalTitle.widthAnchor.constraint(equalTo: stack.widthAnchor),
            translatedTitle.widthAnchor.constraint(equalTo: stack.widthAnchor),
            originalScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            translatedScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            copyContainer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @objc private func copyTranslation() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(translatedTextView.string, forType: .string)
        copyButton.title = "已复制"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.copyButton.title = "复制译文"
        }
    }

    private func positionNearCursor() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }

        let cursor = NSEvent.mouseLocation
        let visible = screen.visibleFrame
        var origin = NSPoint(
            x: cursor.x + 12,
            y: cursor.y - window.frame.height - 12
        )

        origin.x = min(max(origin.x, visible.minX + 12), visible.maxX - window.frame.width - 12)
        origin.y = min(max(origin.y, visible.minY + 12), visible.maxY - window.frame.height - 12)
        window.setFrameOrigin(origin)
    }

    private static func makeTextView() -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        return textView
    }

    private static func makeScrollView(for textView: NSTextView) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView

        textView.frame = scrollView.contentView.bounds
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        return scrollView
    }
}
