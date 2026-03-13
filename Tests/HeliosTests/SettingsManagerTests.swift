import Carbon
@testable import Helios
import Testing

@MainActor
private final class MockLoginItemService: LoginItemService {
    var isEnabled: Bool = false
    var registerCallCount = 0
    var unregisterCallCount = 0
    var shouldThrow = false

    func register() throws {
        registerCallCount += 1
        if shouldThrow { throw MockError.failed }
        isEnabled = true
    }

    func unregister() throws {
        unregisterCallCount += 1
        if shouldThrow { throw MockError.failed }
        isEnabled = false
    }

    enum MockError: Error {
        case failed
    }
}

@MainActor
struct SettingsManagerTests {
    @Test
    func `launchAtLogin reads from service`() {
        let mock = MockLoginItemService()
        let manager = SettingsManager(loginItemService: mock)

        #expect(!manager.launchAtLogin)

        mock.isEnabled = true
        #expect(manager.launchAtLogin)
    }

    @Test
    func `setting launchAtLogin to true calls register`() {
        let mock = MockLoginItemService()
        let manager = SettingsManager(loginItemService: mock)

        manager.launchAtLogin = true

        #expect(mock.registerCallCount == 1)
        #expect(mock.isEnabled)
    }

    @Test
    func `setting launchAtLogin to false calls unregister`() {
        let mock = MockLoginItemService()
        mock.isEnabled = true
        let manager = SettingsManager(loginItemService: mock)

        manager.launchAtLogin = false

        #expect(mock.unregisterCallCount == 1)
        #expect(!mock.isEnabled)
    }

    @Test
    func `launchAtLogin handles register failure gracefully`() {
        let mock = MockLoginItemService()
        mock.shouldThrow = true
        let manager = SettingsManager(loginItemService: mock)

        manager.launchAtLogin = true

        #expect(mock.registerCallCount == 1)
        #expect(!mock.isEnabled)
    }

    @Test
    func `launchAtLogin handles unregister failure gracefully`() {
        let mock = MockLoginItemService()
        mock.isEnabled = true
        mock.shouldThrow = true
        let manager = SettingsManager(loginItemService: mock)

        manager.launchAtLogin = false

        #expect(mock.unregisterCallCount == 1)
        #expect(mock.isEnabled)
    }

    // MARK: - Hotkey

    @Test
    func `hotkey defaults to Option Space`() throws {
        let defaults = try #require(UserDefaults(suiteName: "test.hotkey.default"))
        defaults.removePersistentDomain(forName: "test.hotkey.default")
        let manager = SettingsManager(loginItemService: MockLoginItemService(), defaults: defaults)

        #expect(manager.hotkey == .default)
        #expect(manager.hotkey.keyCode == UInt32(kVK_Space))
        #expect(manager.hotkey.modifiers == UInt32(optionKey))
    }

    @Test
    func `hotkey persists to UserDefaults`() throws {
        let suiteName = "test.hotkey.persist"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let manager = SettingsManager(loginItemService: MockLoginItemService(), defaults: defaults)

        let custom = HotkeyConfiguration(keyCode: UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey | shiftKey))
        manager.hotkey = custom

        // Read back from a fresh manager using the same defaults
        let manager2 = SettingsManager(loginItemService: MockLoginItemService(), defaults: defaults)
        #expect(manager2.hotkey == custom)
    }

    @Test
    func `hotkey change callback fires`() throws {
        let suiteName = "test.hotkey.callback"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let manager = SettingsManager(loginItemService: MockLoginItemService(), defaults: defaults)

        var received: HotkeyConfiguration?
        manager.onHotkeyChanged = { config in
            received = config
        }

        let custom = HotkeyConfiguration(keyCode: UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey))
        manager.hotkey = custom

        #expect(received == custom)
    }

    // MARK: - Disabled Plugins

    @Test
    func `disabledPlugins defaults to empty`() throws {
        let suiteName = "test.plugins.default"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let manager = SettingsManager(loginItemService: MockLoginItemService(), defaults: defaults)

        #expect(manager.disabledPlugins.isEmpty)
        #expect(!manager.isPluginDisabled("SomePlugin"))
    }

    @Test
    func `setPluginDisabled persists to UserDefaults`() throws {
        let suiteName = "test.plugins.persist"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let manager = SettingsManager(loginItemService: MockLoginItemService(), defaults: defaults)

        manager.setPluginDisabled("TestPlugin", disabled: true)

        #expect(manager.isPluginDisabled("TestPlugin"))
        #expect(!manager.isPluginDisabled("OtherPlugin"))

        // Read back from a fresh manager
        let manager2 = SettingsManager(loginItemService: MockLoginItemService(), defaults: defaults)
        #expect(manager2.isPluginDisabled("TestPlugin"))
    }

    @Test
    func `setPluginDisabled re-enables plugin`() throws {
        let suiteName = "test.plugins.reenable"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let manager = SettingsManager(loginItemService: MockLoginItemService(), defaults: defaults)

        manager.setPluginDisabled("TestPlugin", disabled: true)
        #expect(manager.isPluginDisabled("TestPlugin"))

        manager.setPluginDisabled("TestPlugin", disabled: false)
        #expect(!manager.isPluginDisabled("TestPlugin"))
    }

    @Test
    func `setPluginDisabled fires callback`() throws {
        let suiteName = "test.plugins.callback"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let manager = SettingsManager(loginItemService: MockLoginItemService(), defaults: defaults)

        var callCount = 0
        manager.onPluginSettingsChanged = {
            callCount += 1
        }

        manager.setPluginDisabled("TestPlugin", disabled: true)
        #expect(callCount == 1)

        manager.setPluginDisabled("TestPlugin", disabled: false)
        #expect(callCount == 2)
    }

    @Test
    func `hotkey callback skipped for same value`() throws {
        let suiteName = "test.hotkey.skip"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let manager = SettingsManager(loginItemService: MockLoginItemService(), defaults: defaults)

        let custom = HotkeyConfiguration(keyCode: UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey))
        manager.hotkey = custom

        var callCount = 0
        manager.onHotkeyChanged = { _ in
            callCount += 1
        }

        // Set the same value again
        manager.hotkey = custom
        #expect(callCount == 0)
    }
}
