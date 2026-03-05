import AppKit

@MainActor
final class SettingsView: NSView {
    private let settingsManager: SettingsManager
    private let loginToggle = NSSwitch()

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        addSubview(stack)

        // Title
        let titleLabel = NSTextField(labelWithString: "Settings")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .labelColor
        stack.addArrangedSubview(titleLabel)

        // Launch at Login row
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY

        let icon = NSImageView()
        icon.image = NSImage(
            systemSymbolName: "person.crop.circle",
            accessibilityDescription: "Launch at Login"
        )
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let label = NSTextField(labelWithString: "Launch at Login")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor

        loginToggle.target = self
        loginToggle.action = #selector(loginToggleChanged)
        loginToggle.setAccessibilityLabel("Launch at Login")

        // Spacer to push switch to trailing edge
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(icon)
        row.addArrangedSubview(label)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(loginToggle)

        row.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(row)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            row.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    func refresh() {
        loginToggle.state = settingsManager.launchAtLogin ? .on : .off
    }

    @objc private func loginToggleChanged() {
        settingsManager.launchAtLogin = (loginToggle.state == .on)
    }
}
