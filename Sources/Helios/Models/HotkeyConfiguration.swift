import Carbon

struct HotkeyConfiguration: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let `default` = HotkeyConfiguration(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey),
    )
}
