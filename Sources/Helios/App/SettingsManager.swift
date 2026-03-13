import Foundation
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
    private static let hotkeyKey = "hotkeyConfiguration"
    private static let disabledPluginsKey = "disabledPlugins"

    private let loginItemService: LoginItemService
    private let defaults: UserDefaults

    var onHotkeyChanged: ((HotkeyConfiguration) -> Void)?
    var onPluginSettingsChanged: (() -> Void)?

    init(
        loginItemService: LoginItemService = SystemLoginItemService(),
        defaults: UserDefaults = .standard,
    ) {
        self.loginItemService = loginItemService
        self.defaults = defaults
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

    var disabledPlugins: Set<String> {
        get {
            Set(defaults.stringArray(forKey: Self.disabledPluginsKey) ?? [])
        }
        set {
            defaults.set(Array(newValue), forKey: Self.disabledPluginsKey)
        }
    }

    func isPluginDisabled(_ name: String) -> Bool {
        disabledPlugins.contains(name)
    }

    func setPluginDisabled(_ name: String, disabled: Bool) {
        var current = disabledPlugins
        if disabled {
            current.insert(name)
        } else {
            current.remove(name)
        }
        disabledPlugins = current
        onPluginSettingsChanged?()
    }

    var hotkey: HotkeyConfiguration {
        get {
            guard let data = defaults.data(forKey: Self.hotkeyKey),
                  let config = try? JSONDecoder().decode(HotkeyConfiguration.self, from: data)
            else {
                return .default
            }
            return config
        }
        set {
            guard newValue != hotkey else { return }
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: Self.hotkeyKey)
                onHotkeyChanged?(newValue)
            } catch {
                NSLog("Helios: failed to encode hotkey configuration: \(error)")
            }
        }
    }
}
