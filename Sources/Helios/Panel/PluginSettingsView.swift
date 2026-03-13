import AppKit

@MainActor
final class PluginSettingsView: NSView {
    private let settingsManager: SettingsManager
    private let pluginManager: PluginManager
    private let listStack = NSStackView()
    private var toggleToPluginName: [ObjectIdentifier: String] = [:]

    init(settingsManager: SettingsManager, pluginManager: PluginManager) {
        self.settingsManager = settingsManager
        self.pluginManager = pluginManager
        super.init(frame: .zero)
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
        stack.spacing = 8
        addSubview(stack)

        let sectionLabel = NSTextField(labelWithString: "Plugins")
        sectionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        sectionLabel.textColor = .labelColor
        stack.addArrangedSubview(sectionLabel)

        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 6
        listStack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(listStack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),

            listStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    func refresh() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        toggleToPluginName.removeAll()

        let manifests = pluginManager.discoverAllManifests()

        if manifests.isEmpty {
            let label = NSTextField(labelWithString: "No plugins found")
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            listStack.addArrangedSubview(label)
            return
        }

        for manifest in manifests {
            let row = makePluginRow(manifest: manifest)
            listStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true
        }
    }

    private func makePluginRow(manifest: PluginManifest) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        let iconName = manifest.icon ?? "puzzlepiece.extension"
        icon.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: manifest.name,
        )
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1

        let nameLabel = NSTextField(labelWithString: manifest.name)
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail

        let descLabel = NSTextField(labelWithString: manifest.description)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.lineBreakMode = .byTruncatingTail

        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(descLabel)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let toggle = NSSwitch()
        toggle.state = settingsManager.isPluginDisabled(manifest.name) ? .off : .on
        toggle.target = self
        toggle.action = #selector(pluginToggled(_:))
        toggle.setAccessibilityLabel("Enable \(manifest.name)")
        toggleToPluginName[ObjectIdentifier(toggle)] = manifest.name

        row.addArrangedSubview(icon)
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(toggle)

        return row
    }

    @objc private func pluginToggled(_ sender: NSSwitch) {
        guard let name = toggleToPluginName[ObjectIdentifier(sender)] else { return }
        let disabled = sender.state == .off
        settingsManager.setPluginDisabled(name, disabled: disabled)
    }
}
