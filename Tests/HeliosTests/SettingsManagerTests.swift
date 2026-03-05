import Testing
@testable import Helios

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
@Suite("SettingsManager")
struct SettingsManagerTests {
    @Test("launchAtLogin reads from service")
    func readsFromService() {
        let mock = MockLoginItemService()
        let manager = SettingsManager(loginItemService: mock)

        #expect(!manager.launchAtLogin)

        mock.isEnabled = true
        #expect(manager.launchAtLogin)
    }

    @Test("setting launchAtLogin to true calls register")
    func enableCallsRegister() {
        let mock = MockLoginItemService()
        let manager = SettingsManager(loginItemService: mock)

        manager.launchAtLogin = true

        #expect(mock.registerCallCount == 1)
        #expect(mock.isEnabled)
    }

    @Test("setting launchAtLogin to false calls unregister")
    func disableCallsUnregister() {
        let mock = MockLoginItemService()
        mock.isEnabled = true
        let manager = SettingsManager(loginItemService: mock)

        manager.launchAtLogin = false

        #expect(mock.unregisterCallCount == 1)
        #expect(!mock.isEnabled)
    }

    @Test("launchAtLogin handles register failure gracefully")
    func registerFailureDoesNotCrash() {
        let mock = MockLoginItemService()
        mock.shouldThrow = true
        let manager = SettingsManager(loginItemService: mock)

        manager.launchAtLogin = true

        #expect(mock.registerCallCount == 1)
        #expect(!mock.isEnabled)
    }

    @Test("launchAtLogin handles unregister failure gracefully")
    func unregisterFailureDoesNotCrash() {
        let mock = MockLoginItemService()
        mock.isEnabled = true
        mock.shouldThrow = true
        let manager = SettingsManager(loginItemService: mock)

        manager.launchAtLogin = false

        #expect(mock.unregisterCallCount == 1)
        #expect(mock.isEnabled)
    }
}
