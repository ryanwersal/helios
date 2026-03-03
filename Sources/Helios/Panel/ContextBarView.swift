import AppKit

@MainActor
final class ContextBarView: NSView {
    static let height: CGFloat = 32

    private let hintsLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        hintsLabel.translatesAutoresizingMaskIntoConstraints = false
        hintsLabel.font = .systemFont(ofSize: 11)
        hintsLabel.textColor = .tertiaryLabelColor
        hintsLabel.stringValue = "↑↓ Navigate    ⏎ Open    ⎋ Dismiss"
        addSubview(hintsLabel)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),

            hintsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            hintsLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1),
        ])
    }
}
