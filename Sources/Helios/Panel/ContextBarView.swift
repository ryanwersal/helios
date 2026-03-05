import AppKit

@MainActor
final class ContextBarView: NSView {
    static let height: CGFloat = 32

    var onSettingsButtonPressed: (() -> Void)?

    private let settingsButton: NSButton
    private let hintsLabel = NSTextField(labelWithString: "")

    private static let searchHints = "↑↓ Navigate    ⏎ Open    ⎋ Dismiss"
    private static let settingsHints = "⎋ Back"

    override init(frame frameRect: NSRect) {
        settingsButton = NSButton(
            image: NSImage(
                systemSymbolName: "gearshape",
                accessibilityDescription: "Settings",
            )!,
            target: nil,
            action: nil,
        )
        super.init(frame: frameRect)
        settingsButton.target = self
        settingsButton.action = #selector(settingsButtonClicked)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.isBordered = false
        settingsButton.contentTintColor = .tertiaryLabelColor
        settingsButton.imageScaling = .scaleProportionallyDown
        settingsButton.setAccessibilityLabel("Open Settings")
        addSubview(settingsButton)

        hintsLabel.translatesAutoresizingMaskIntoConstraints = false
        hintsLabel.font = .systemFont(ofSize: 11)
        hintsLabel.textColor = .tertiaryLabelColor
        hintsLabel.stringValue = Self.searchHints
        addSubview(hintsLabel)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),

            settingsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            settingsButton.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1),
            settingsButton.widthAnchor.constraint(equalToConstant: 20),
            settingsButton.heightAnchor.constraint(equalToConstant: 20),

            hintsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            hintsLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1),
        ])
    }

    func updateForMode(_ mode: PanelMode) {
        switch mode {
        case .search:
            settingsButton.isHidden = false
            hintsLabel.stringValue = Self.searchHints
        case .settings:
            settingsButton.isHidden = true
            hintsLabel.stringValue = Self.settingsHints
        }
    }

    @objc private func settingsButtonClicked() {
        onSettingsButtonPressed?()
    }
}
