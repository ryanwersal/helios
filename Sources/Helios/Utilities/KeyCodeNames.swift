import AppKit
import Carbon

enum KeyCodeNames {
    static let names: [UInt32: String] = [
        // Letters
        UInt32(kVK_ANSI_A): "A",
        UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E",
        UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G",
        UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K",
        UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M",
        UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q",
        UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S",
        UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W",
        UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y",
        UInt32(kVK_ANSI_Z): "Z",

        // Numbers
        UInt32(kVK_ANSI_0): "0",
        UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4",
        UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6",
        UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",

        // Function keys
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12",
        UInt32(kVK_F13): "F13",
        UInt32(kVK_F14): "F14",
        UInt32(kVK_F15): "F15",
        UInt32(kVK_F16): "F16",
        UInt32(kVK_F17): "F17",
        UInt32(kVK_F18): "F18",
        UInt32(kVK_F19): "F19",
        UInt32(kVK_F20): "F20",

        // Special keys
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "Return",
        UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Delete): "Delete",
        UInt32(kVK_ForwardDelete): "Forward Delete",
        UInt32(kVK_Escape): "Escape",
        UInt32(kVK_Home): "Home",
        UInt32(kVK_End): "End",
        UInt32(kVK_PageUp): "Page Up",
        UInt32(kVK_PageDown): "Page Down",

        // Arrow keys
        UInt32(kVK_UpArrow): "Up",
        UInt32(kVK_DownArrow): "Down",
        UInt32(kVK_LeftArrow): "Left",
        UInt32(kVK_RightArrow): "Right",

        // Punctuation / symbols
        UInt32(kVK_ANSI_Minus): "-",
        UInt32(kVK_ANSI_Equal): "=",
        UInt32(kVK_ANSI_LeftBracket): "[",
        UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Backslash): "\\",
        UInt32(kVK_ANSI_Semicolon): ";",
        UInt32(kVK_ANSI_Quote): "'",
        UInt32(kVK_ANSI_Comma): ",",
        UInt32(kVK_ANSI_Period): ".",
        UInt32(kVK_ANSI_Slash): "/",
        UInt32(kVK_ANSI_Grave): "`",

        // Keypad
        UInt32(kVK_ANSI_Keypad0): "Keypad 0",
        UInt32(kVK_ANSI_Keypad1): "Keypad 1",
        UInt32(kVK_ANSI_Keypad2): "Keypad 2",
        UInt32(kVK_ANSI_Keypad3): "Keypad 3",
        UInt32(kVK_ANSI_Keypad4): "Keypad 4",
        UInt32(kVK_ANSI_Keypad5): "Keypad 5",
        UInt32(kVK_ANSI_Keypad6): "Keypad 6",
        UInt32(kVK_ANSI_Keypad7): "Keypad 7",
        UInt32(kVK_ANSI_Keypad8): "Keypad 8",
        UInt32(kVK_ANSI_Keypad9): "Keypad 9",
        UInt32(kVK_ANSI_KeypadDecimal): "Keypad .",
        UInt32(kVK_ANSI_KeypadMultiply): "Keypad *",
        UInt32(kVK_ANSI_KeypadPlus): "Keypad +",
        UInt32(kVK_ANSI_KeypadMinus): "Keypad -",
        UInt32(kVK_ANSI_KeypadDivide): "Keypad /",
        UInt32(kVK_ANSI_KeypadEquals): "Keypad =",
        UInt32(kVK_ANSI_KeypadEnter): "Keypad Enter",
        UInt32(kVK_ANSI_KeypadClear): "Keypad Clear",
    ]

    static func displayName(for keyCode: UInt32) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}

enum ModifierSymbols {
    static func displayString(for modifiers: UInt32) -> String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "\u{2303}" } // ⌃
        if modifiers & UInt32(optionKey) != 0 { symbols += "\u{2325}" } // ⌥
        if modifiers & UInt32(shiftKey) != 0 { symbols += "\u{21E7}" } // ⇧
        if modifiers & UInt32(cmdKey) != 0 { symbols += "\u{2318}" } // ⌘
        return symbols
    }

    static func fullDisplayString(for config: HotkeyConfiguration) -> String {
        let mods = displayString(for: config.modifiers)
        let key = KeyCodeNames.displayName(for: config.keyCode)
        if mods.isEmpty {
            return key
        }
        return "\(mods) \(key)"
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    static func cocoaModifiers(from carbonMods: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonMods & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbonMods & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonMods & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbonMods & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    /// Returns a key equivalent character for use with NSMenuItem, or nil if unknown.
    static func keyEquivalentCharacter(for keyCode: UInt32) -> String? {
        switch Int(keyCode) {
        case kVK_Space: return " "
        case kVK_Return: return "\r"
        case kVK_Tab: return "\t"
        case kVK_Delete: return "\u{08}"
        case kVK_Escape: return "\u{1B}"
        case kVK_UpArrow: return String(Character(UnicodeScalar(NSUpArrowFunctionKey)!))
        case kVK_DownArrow: return String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))
        case kVK_LeftArrow: return String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!))
        case kVK_RightArrow: return String(Character(UnicodeScalar(NSRightArrowFunctionKey)!))
        case kVK_F1: return String(Character(UnicodeScalar(NSF1FunctionKey)!))
        case kVK_F2: return String(Character(UnicodeScalar(NSF2FunctionKey)!))
        case kVK_F3: return String(Character(UnicodeScalar(NSF3FunctionKey)!))
        case kVK_F4: return String(Character(UnicodeScalar(NSF4FunctionKey)!))
        case kVK_F5: return String(Character(UnicodeScalar(NSF5FunctionKey)!))
        case kVK_F6: return String(Character(UnicodeScalar(NSF6FunctionKey)!))
        case kVK_F7: return String(Character(UnicodeScalar(NSF7FunctionKey)!))
        case kVK_F8: return String(Character(UnicodeScalar(NSF8FunctionKey)!))
        case kVK_F9: return String(Character(UnicodeScalar(NSF9FunctionKey)!))
        case kVK_F10: return String(Character(UnicodeScalar(NSF10FunctionKey)!))
        case kVK_F11: return String(Character(UnicodeScalar(NSF11FunctionKey)!))
        case kVK_F12: return String(Character(UnicodeScalar(NSF12FunctionKey)!))
        default:
            // For letter/number/symbol keys, use the display name lowercased
            if let name = KeyCodeNames.names[keyCode], name.count == 1 {
                return name.lowercased()
            }
            return nil
        }
    }
}
