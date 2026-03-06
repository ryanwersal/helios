import AppKit
import Carbon

@MainActor
final class ShortcutRecorderView: NSView {
    var onChange: ((HotkeyConfiguration) -> Void)?

    private var currentConfig: HotkeyConfiguration = .default
    private var isRecording = false

    private let displayLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        updateAppearance()

        addSubview(displayLabel)

        setAccessibilityLabel("Keyboard Shortcut")
        setAccessibilityRole(.button)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 150),
            heightAnchor.constraint(equalToConstant: 28),

            displayLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            displayLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            displayLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
        ])

        updateDisplayLabel()
    }

    func configure(with config: HotkeyConfiguration) {
        currentConfig = config
        updateDisplayLabel()
    }

    // MARK: - Display

    private func updateDisplayLabel() {
        if isRecording {
            displayLabel.stringValue = "Type shortcut\u{2026}"
            displayLabel.textColor = .placeholderTextColor
        } else {
            displayLabel.stringValue = ModifierSymbols.fullDisplayString(for: currentConfig)
            displayLabel.textColor = .labelColor
        }
        setAccessibilityValue(displayLabel.stringValue)
    }

    private func updateAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if isRecording {
                layer?.borderColor = NSColor.controlAccentColor.cgColor
            } else {
                layer?.borderColor = NSColor.separatorColor.cgColor
            }
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    // MARK: - Mouse Handling

    override func mouseDown(with _: NSEvent) {
        if isRecording {
            cancelRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Recording

    private func startRecording() {
        isRecording = true
        updateDisplayLabel()
        updateAppearance()
    }

    private func cancelRecording() {
        stopRecording()
        updateDisplayLabel()
        updateAppearance()
    }

    private func stopRecording() {
        isRecording = false
    }

    // MARK: - Key Handling

    /// Called by the owning panel's `sendEvent:` override — the only reliable
    /// way to intercept key events in a `.nonactivatingPanel`.
    /// Returns `true` if the event was consumed.
    func handleKeyEventIfRecording(_ event: NSEvent) -> Bool {
        guard isRecording else { return false }
        handleKeyEvent(event)
        return true
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Escape cancels recording (allow .function flag which macOS sometimes adds)
        if keyCode == UInt16(kVK_Escape) && flags.subtracting(.function).isEmpty {
            cancelRecording()
            return
        }

        // Delete resets to default
        if keyCode == UInt16(kVK_Delete) && flags.isEmpty {
            let defaultConfig = HotkeyConfiguration.default
            currentConfig = defaultConfig
            stopRecording()
            updateDisplayLabel()
            updateAppearance()
            onChange?(defaultConfig)
            return
        }

        // Require at least one modifier
        let modifierFlags: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        guard !flags.isDisjoint(with: modifierFlags) else { return }

        let carbonMods = ModifierSymbols.carbonModifiers(from: flags)
        let config = HotkeyConfiguration(keyCode: UInt32(keyCode), modifiers: carbonMods)
        currentConfig = config
        stopRecording()
        updateDisplayLabel()
        updateAppearance()
        onChange?(config)
    }

    // MARK: - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil && isRecording {
            cancelRecording()
        }
    }

}
