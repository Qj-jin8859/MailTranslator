import Foundation
import ServiceManagement

enum LaunchAtLoginStatus {
    case enabled
    case requiresApproval
    case disabled
    case unavailable
}

struct LaunchAtLoginManager {
    func status() -> LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered:
            return .disabled
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func isEnabled() -> Bool {
        status() == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
