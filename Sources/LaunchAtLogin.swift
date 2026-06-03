import Foundation
import ServiceManagement

/// Thin wrapper over SMAppService for registering the app as a login item.
/// Available on macOS 13+, which is this app's minimum.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                switch (newValue, SMAppService.mainApp.status) {
                case (true, let s) where s != .enabled:
                    try SMAppService.mainApp.register()
                case (false, .enabled):
                    try SMAppService.mainApp.unregister()
                default:
                    break
                }
            } catch {
                NSLog("LaunchAtLogin: failed to set \(newValue): \(error.localizedDescription)")
            }
        }
    }
}
