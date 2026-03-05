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
}
