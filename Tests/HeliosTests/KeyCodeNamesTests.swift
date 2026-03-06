import AppKit
import Carbon
@testable import Helios
import Testing

struct KeyCodeNamesTests {
    @Test
    func `space display name`() {
        #expect(KeyCodeNames.displayName(for: UInt32(kVK_Space)) == "Space")
    }

    @Test
    func `letter display names`() {
        #expect(KeyCodeNames.displayName(for: UInt32(kVK_ANSI_A)) == "A")
        #expect(KeyCodeNames.displayName(for: UInt32(kVK_ANSI_Z)) == "Z")
    }

    @Test
    func `function key display names`() {
        #expect(KeyCodeNames.displayName(for: UInt32(kVK_F1)) == "F1")
        #expect(KeyCodeNames.displayName(for: UInt32(kVK_F12)) == "F12")
    }

    @Test
    func `unknown key code fallback`() {
        #expect(KeyCodeNames.displayName(for: 999) == "Key 999")
    }
}

struct ModifierSymbolsTests {
    @Test
    func `option modifier display string`() {
        #expect(ModifierSymbols.displayString(for: UInt32(optionKey)) == "\u{2325}")
    }

    @Test
    func `command shift modifier display string`() {
        let mods = UInt32(cmdKey | shiftKey)
        // Order: ⌃⌥⇧⌘ — so shift before command
        #expect(ModifierSymbols.displayString(for: mods) == "\u{21E7}\u{2318}")
    }

    @Test
    func `all modifiers display string`() {
        let mods = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        #expect(ModifierSymbols.displayString(for: mods) == "\u{2303}\u{2325}\u{21E7}\u{2318}")
    }

    @Test
    func `full display string for default`() {
        let display = ModifierSymbols.fullDisplayString(for: .default)
        #expect(display == "\u{2325} Space")
    }

    @Test
    func `carbon modifiers from cocoa`() {
        let flags: NSEvent.ModifierFlags = [.command, .shift]
        let carbon = ModifierSymbols.carbonModifiers(from: flags)
        #expect(carbon & UInt32(cmdKey) != 0)
        #expect(carbon & UInt32(shiftKey) != 0)
        #expect(carbon & UInt32(optionKey) == 0)
        #expect(carbon & UInt32(controlKey) == 0)
    }

    @Test
    func `cocoa modifiers from carbon`() {
        let carbon = UInt32(optionKey | controlKey)
        let flags = ModifierSymbols.cocoaModifiers(from: carbon)
        #expect(flags.contains(.option))
        #expect(flags.contains(.control))
        #expect(!flags.contains(.command))
        #expect(!flags.contains(.shift))
    }

    @Test
    func `key equivalent for space`() {
        #expect(ModifierSymbols.keyEquivalentCharacter(for: UInt32(kVK_Space)) == " ")
    }

    @Test
    func `key equivalent for letter`() {
        #expect(ModifierSymbols.keyEquivalentCharacter(for: UInt32(kVK_ANSI_H)) == "h")
    }

    @Test
    func `key equivalent for unknown returns nil`() {
        #expect(ModifierSymbols.keyEquivalentCharacter(for: 999) == nil)
    }
}
