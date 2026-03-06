import Carbon
@testable import Helios
import Testing

struct HotkeyConfigurationTests {
    @Test
    func `default is Option Space`() {
        let config = HotkeyConfiguration.default
        #expect(config.keyCode == UInt32(kVK_Space))
        #expect(config.modifiers == UInt32(optionKey))
    }

    @Test
    func `codable round trip`() throws {
        let config = HotkeyConfiguration(keyCode: 4, modifiers: UInt32(cmdKey | shiftKey))
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(HotkeyConfiguration.self, from: data)
        #expect(decoded == config)
    }

    @Test
    func `equatable same values`() {
        let a = HotkeyConfiguration(keyCode: 10, modifiers: 100)
        let b = HotkeyConfiguration(keyCode: 10, modifiers: 100)
        #expect(a == b)
    }

    @Test
    func `equatable different values`() {
        let a = HotkeyConfiguration(keyCode: 10, modifiers: 100)
        let b = HotkeyConfiguration(keyCode: 11, modifiers: 100)
        #expect(a != b)
    }
}
