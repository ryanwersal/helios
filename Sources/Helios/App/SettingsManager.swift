import ServiceManagement

@MainActor
protocol LoginItemService {
    var isEnabled: Bool { get }
    func register() throws
    func unregister() throws
}

@MainActor
struct SystemLoginItemService: LoginItemService {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

@MainActor
final class SettingsManager {
    private let loginItemService: LoginItemService

    init(loginItemService: LoginItemService = SystemLoginItemService()) {
        self.loginItemService = loginItemService
    }

    var launchAtLogin: Bool {
        get {
            loginItemService.isEnabled
        }
        set {
            do {
                if newValue {
                    try loginItemService.register()
                } else {
                    try loginItemService.unregister()
                }
            } catch {
                // Registration can fail if the app isn't signed or if the user
                // denied the request in System Settings. Log and move on.
                NSLog("Helios: failed to \(newValue ? "register" : "unregister") login item: \(error)")
            }
        }
    }
}
