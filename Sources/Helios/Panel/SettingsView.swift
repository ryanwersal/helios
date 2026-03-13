import AppKit

@MainActor
final class SettingsView: NSView {
    private let settingsManager: SettingsManager
    private let loginToggle = NSSwitch()
    private let shortcutRecorder = ShortcutRecorderView()
    private var quicklinksView: QuickLinksSettingsView?

    init(settingsManager: SettingsManager, quickLinkStore: QuickLinkStore? = nil) {
        self.settingsManager = settingsManager
        super.init(frame: .zero)
        if let quickLinkStore {
            quicklinksView = QuickLinksSettingsView(store: quickLinkStore)
        }
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
        stack.spacing = 16
        addSubview(stack)

        // Title
        let titleLabel = NSTextField(labelWithString: "Settings")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .labelColor
        stack.addArrangedSubview(titleLabel)

        // Launch at Login row
        let loginRow = makeSettingsRow(
            iconName: "person.crop.circle",
            iconDescription: "Launch at Login",
            labelText: "Launch at Login",
            control: loginToggle,
        )
        loginToggle.target = self
        loginToggle.action = #selector(loginToggleChanged)
        loginToggle.setAccessibilityLabel("Launch at Login")
        stack.addArrangedSubview(loginRow)

        // Keyboard Shortcut row
        let shortcutRow = makeSettingsRow(
            iconName: "keyboard",
            iconDescription: "Keyboard Shortcut",
            labelText: "Keyboard Shortcut",
            control: shortcutRecorder,
        )
        shortcutRecorder.onChange = { [weak self] config in
            self?.settingsManager.hotkey = config
        }
        stack.addArrangedSubview(shortcutRow)

        // Quicklinks section
        if let quicklinksView {
            let separator = NSBox()
            separator.boxType = .separator
            separator.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(separator)

            quicklinksView.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(quicklinksView)

            separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            quicklinksView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            loginRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            shortcutRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func makeSettingsRow(
        iconName: String,
        iconDescription: String,
        labelText: String,
        control: NSView,
    ) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: iconDescription,
        )
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let label = NSTextField(labelWithString: labelText)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(icon)
        row.addArrangedSubview(label)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(control)

        return row
    }

    func handleKeyEventIfRecording(_ event: NSEvent) -> Bool {
        shortcutRecorder.handleKeyEventIfRecording(event)
    }

    func refresh() {
        loginToggle.state = settingsManager.launchAtLogin ? .on : .off
        shortcutRecorder.configure(with: settingsManager.hotkey)
        quicklinksView?.refresh()
    }

    @objc private func loginToggleChanged() {
        settingsManager.launchAtLogin = (loginToggle.state == .on)
    }
}
