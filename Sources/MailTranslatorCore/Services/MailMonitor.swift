import AppKit
import ApplicationServices
import Foundation

protocol MailMonitorDelegate: AnyObject {
    func mailMonitor(_ monitor: MailMonitor, didDetect snapshot: MailSnapshot)
    func mailMonitor(_ monitor: MailMonitor, didFailWith error: Error)
}

private func mailTranslatorAXObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let monitor = Unmanaged<MailMonitor>.fromOpaque(refcon).takeUnretainedValue()
    DispatchQueue.main.async {
        monitor.scheduleAXPoll()
    }
}

final class MailMonitor {
    weak var delegate: MailMonitorDelegate?

    private let reader = MailReader()
    private let settings = AppSettings.shared

    private var timer: Timer?
    private var lastHandledMessageID: String?
    private var isPolling = false
    private var needsAnotherPoll = false
    private var pendingForce = false

    private var axObserver: AXObserver?
    private var axRunLoopSource: CFRunLoopSource?
    private var pendingAXPollWorkItem: DispatchWorkItem?
    private var isInstallingAXObserver = false
    private var observerGeneration = 0

    func start() {
        stop()

        let interval = settings.pollingInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }

        if isMailRunning {
            installAXObserver()
        }
    }

    func restart() {
        start()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        removeAXObserver()
    }

    func poll(force: Bool = false) {
        guard isMailRunning else {
            if axObserver != nil {
                removeAXObserver()
            }
            return
        }

        if axObserver == nil {
            installAXObserver()
        }

        guard !isPolling else {
            needsAnotherPoll = true
            pendingForce = pendingForce || force
            return
        }

        isPolling = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }

            autoreleasepool {
                let result: Result<MailSnapshot?, Error>
                do {
                    result = .success(try self.reader.currentSelection())
                } catch {
                    result = .failure(error)
                }

                DispatchQueue.main.async {
                    self.isPolling = false

                    switch result {
                    case .success(let snapshot):
                        guard let snapshot else {
                            self.runDeferredPollIfNeeded()
                            return
                        }
                        if force || snapshot.messageID != self.lastHandledMessageID {
                            self.lastHandledMessageID = snapshot.messageID
                            self.delegate?.mailMonitor(self, didDetect: snapshot)
                        }
                    case .failure(let error):
                        self.delegate?.mailMonitor(self, didFailWith: error)
                    }

                    self.runDeferredPollIfNeeded()
                }
            }
        }
    }

    func scheduleAXPoll() {
        pendingAXPollWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.poll()
        }
        pendingAXPollWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func runDeferredPollIfNeeded() {
        guard needsAnotherPoll else { return }

        let force = pendingForce
        needsAnotherPoll = false
        pendingForce = false
        poll(force: force)
    }

    private func installAXObserver() {
        guard AXIsProcessTrusted() else { return }
        guard let app = runningMailApp else { return }
        guard axObserver == nil else { return }
        guard !isInstallingAXObserver else { return }

        isInstallingAXObserver = true
        let generation = observerGeneration

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }

            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appElement, 1.0)

            var observer: AXObserver?
            let selfPointer = Unmanaged.passUnretained(self).toOpaque()
            guard AXObserverCreate(pid, mailTranslatorAXObserverCallback, &observer) == .success,
                  let observer else {
                DispatchQueue.main.async {
                    self.isInstallingAXObserver = false
                }
                return
            }

            var targetElement: AXUIElement = appElement
            if let container = self.firstSelectionContainer(from: appElement) {
                targetElement = container
            }

            let notification = kAXSelectedRowsChangedNotification as CFString
            guard AXObserverAddNotification(observer, targetElement, notification, selfPointer) == .success else {
                DispatchQueue.main.async {
                    self.isInstallingAXObserver = false
                }
                return
            }

            DispatchQueue.main.async {
                self.isInstallingAXObserver = false

                if generation == self.observerGeneration, self.axObserver == nil {
                    let source = AXObserverGetRunLoopSource(observer)
                    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                    self.axObserver = observer
                    self.axRunLoopSource = source
                }
            }
        }
    }

    private func removeAXObserver() {
        observerGeneration += 1

        if let source = axRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        axRunLoopSource = nil
        axObserver = nil
    }

    private func firstSelectionContainer(
        from element: AXUIElement,
        depth: Int = 0
    ) -> AXUIElement? {
        guard depth < 10 else { return nil }

        var roleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success,
           let role = roleValue as? String {
            if role == (kAXOutlineRole as String) || role == (kAXTableRole as String) {
                return element
            }
        }

        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else {
            return nil
        }

        for child in children {
            if let found = firstSelectionContainer(from: child, depth: depth + 1) {
                return found
            }
        }

        return nil
    }

    private var runningMailApp: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            app.bundleIdentifier == "com.apple.mail"
        }
    }

    private var isMailRunning: Bool {
        runningMailApp != nil
    }
}
