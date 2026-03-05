import AppKit
import Carbon

/// Lightweight global hotkey registration using Carbon APIs.
/// Uses a static callback table to avoid retain cycles with the Carbon event system.
@MainActor
final class GlobalHotkey {
    private static var nextID: UInt32 = 1
    private static var callbacks: [UInt32: () -> Void] = [:]

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotkeyID: UInt32

    /// Register a global hotkey.
    /// - Parameters:
    ///   - keyCode: Carbon virtual key code (e.g., kVK_Space = 49)
    ///   - modifiers: Carbon modifier flags (e.g., optionKey)
    ///   - callback: Called when the hotkey is pressed
    init(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        hotkeyID = Self.nextID
        Self.nextID += 1
        Self.callbacks[hotkeyID] = callback
        register(keyCode: keyCode, modifiers: modifiers)
    }

    deinit {
        MainActor.assumeIsolated {
            unregister()
        }
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        let hotkeyIDSpec = EventHotKeyID(signature: fourCharCode("HELI"), id: hotkeyID)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotkeyIDOut = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyIDOut,
                )
                guard status == noErr else { return OSStatus(eventNotHandledErr) }
                // Carbon hotkey events always fire on the main thread
                MainActor.assumeIsolated {
                    GlobalHotkey.callbacks[hotkeyIDOut.id]?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler,
        )

        RegisterEventHotKey(keyCode, modifiers, hotkeyIDSpec,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        Self.callbacks.removeValue(forKey: hotkeyID)
    }
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) | OSType(char)
    }
    return result
}
