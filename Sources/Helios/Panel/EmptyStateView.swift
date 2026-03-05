import AppKit

@MainActor
final class EmptyStateView: NSView {
    private static let hints: [(icon: String, text: String)] = [
        ("app.badge", "Type to search and launch apps"),
        ("book", "Search Firefox bookmarks by title or URL"),
        ("equal.circle", "Calculate math: 2+2, 15% of 200, sqrt(144)"),
        ("clock", "Check time: \"time in tokyo\", \"3 hours from now\""),
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        addSubview(stack)

        for hint in Self.hints {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 10
            row.alignment = .centerY

            let icon = NSImageView()
            icon.image = NSImage(systemSymbolName: hint.icon, accessibilityDescription: hint.text)
            icon.contentTintColor = .tertiaryLabelColor
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 16).isActive = true

            let label = NSTextField(labelWithString: hint.text)
            label.font = .systemFont(ofSize: 13)
            label.textColor = .secondaryLabelColor

            row.addArrangedSubview(icon)
            row.addArrangedSubview(label)
            stack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])
    }
}
