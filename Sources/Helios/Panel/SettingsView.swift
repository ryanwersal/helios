import AppKit

@MainActor
final class SettingsView: NSView {
    private let settingsManager: SettingsManager
    private let quickLinkStore: QuickLinkStore?
    private let loginToggle = NSSwitch()
    private let shortcutRecorder = ShortcutRecorderView()
    private let quicklinksStack = NSStackView()

    /// Index of the quicklink currently being edited, or nil if adding new.
    private var editingIndex: Int?
    private var formRow: NSStackView?
    private var formKeywordField: NSTextField?
    private var formNameField: NSTextField?
    private var formURLField: NSTextField?

    init(settingsManager: SettingsManager, quickLinkStore: QuickLinkStore? = nil) {
        self.settingsManager = settingsManager
        self.quickLinkStore = quickLinkStore
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
            control: loginToggle
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
            control: shortcutRecorder
        )
        shortcutRecorder.onChange = { [weak self] config in
            self?.settingsManager.hotkey = config
        }
        stack.addArrangedSubview(shortcutRow)

        // Quicklinks section
        if quickLinkStore != nil {
            let separator = NSBox()
            separator.boxType = .separator
            separator.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(separator)

            let sectionLabel = NSTextField(labelWithString: "Quicklinks")
            sectionLabel.font = .systemFont(ofSize: 14, weight: .medium)
            sectionLabel.textColor = .labelColor
            stack.addArrangedSubview(sectionLabel)

            quicklinksStack.orientation = .vertical
            quicklinksStack.alignment = .leading
            quicklinksStack.spacing = 6
            quicklinksStack.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(quicklinksStack)

            let buttonsRow = NSStackView()
            buttonsRow.orientation = .horizontal
            buttonsRow.spacing = 8
            buttonsRow.translatesAutoresizingMaskIntoConstraints = false

            let addButton = NSButton(title: "Add", target: self, action: #selector(addQuicklink))
            addButton.bezelStyle = .push
            addButton.controlSize = .small
            addButton.setAccessibilityLabel("Add Quicklink")

            let openConfigButton = NSButton(
                title: "Open Config File",
                target: self,
                action: #selector(openConfigFile)
            )
            openConfigButton.bezelStyle = .push
            openConfigButton.controlSize = .small
            openConfigButton.setAccessibilityLabel("Open Quicklinks Config File")

            buttonsRow.addArrangedSubview(addButton)
            buttonsRow.addArrangedSubview(openConfigButton)
            stack.addArrangedSubview(buttonsRow)

            separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            quicklinksStack.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            buttonsRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
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
        control: NSView
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
        refreshQuicklinks()
    }

    // MARK: - Quicklinks

    private func refreshQuicklinks() {
        guard let store = quickLinkStore else { return }
        store.reload()

        quicklinksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        clearForm()

        for (index, quicklink) in store.quicklinks.enumerated() {
            let row = makeQuicklinkDisplayRow(quicklink: quicklink, index: index)
            quicklinksStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: quicklinksStack.widthAnchor).isActive = true
        }

        if store.quicklinks.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No quicklinks configured")
            emptyLabel.font = .systemFont(ofSize: 12)
            emptyLabel.textColor = .secondaryLabelColor
            quicklinksStack.addArrangedSubview(emptyLabel)
        }
    }

    private func makeQuicklinkDisplayRow(quicklink: QuickLink, index: Int) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 2
        container.translatesAutoresizingMaskIntoConstraints = false

        // Top line: keyword + name + buttons
        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.spacing = 8
        topRow.alignment = .centerY
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let keywordLabel = NSTextField(labelWithString: quicklink.keyword)
        keywordLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        keywordLabel.textColor = .labelColor
        keywordLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true

        let nameLabel = NSTextField(labelWithString: quicklink.name)
        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let editButton = NSButton(title: "Edit", target: self, action: #selector(editQuicklink(_:)))
        editButton.bezelStyle = .inline
        editButton.controlSize = .small
        editButton.font = .systemFont(ofSize: 11)
        editButton.tag = index
        editButton.setAccessibilityLabel("Edit \(quicklink.name)")

        let removeButton = NSButton(title: "\u{00D7}", target: self, action: #selector(removeQuicklink(_:)))
        removeButton.bezelStyle = .inline
        removeButton.isBordered = false
        removeButton.font = .systemFont(ofSize: 16)
        removeButton.tag = index
        removeButton.setAccessibilityLabel("Remove \(quicklink.name)")

        topRow.addArrangedSubview(keywordLabel)
        topRow.addArrangedSubview(nameLabel)
        topRow.addArrangedSubview(spacer)
        topRow.addArrangedSubview(editButton)
        topRow.addArrangedSubview(removeButton)

        // Bottom line: URL
        let urlLabel = NSTextField(labelWithString: quicklink.url)
        urlLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        urlLabel.textColor = .tertiaryLabelColor
        urlLabel.lineBreakMode = .byTruncatingTail
        urlLabel.maximumNumberOfLines = 1

        container.addArrangedSubview(topRow)
        container.addArrangedSubview(urlLabel)

        topRow.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        urlLabel.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor).isActive = true

        return container
    }

    private func makeFormRow(keyword: String = "", name: String = "", url: String = "") -> NSStackView {
        let outer = NSStackView()
        outer.orientation = .vertical
        outer.alignment = .leading
        outer.spacing = 4
        outer.translatesAutoresizingMaskIntoConstraints = false

        // Fields row: keyword + name
        let fieldsRow = NSStackView()
        fieldsRow.orientation = .horizontal
        fieldsRow.spacing = 6
        fieldsRow.alignment = .centerY
        fieldsRow.translatesAutoresizingMaskIntoConstraints = false

        let keywordField = NSTextField()
        keywordField.placeholderString = "keyword"
        keywordField.stringValue = keyword
        keywordField.font = .systemFont(ofSize: 12)
        keywordField.widthAnchor.constraint(equalToConstant: 70).isActive = true

        let nameField = NSTextField()
        nameField.placeholderString = "name"
        nameField.stringValue = name
        nameField.font = .systemFont(ofSize: 12)

        fieldsRow.addArrangedSubview(keywordField)
        fieldsRow.addArrangedSubview(nameField)

        // URL row
        let urlRow = NSStackView()
        urlRow.orientation = .horizontal
        urlRow.spacing = 6
        urlRow.alignment = .centerY
        urlRow.translatesAutoresizingMaskIntoConstraints = false

        let urlField = NSTextField()
        urlField.placeholderString = "https://example.com/{query}"
        urlField.stringValue = url
        urlField.font = .systemFont(ofSize: 12)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(confirmForm))
        saveButton.bezelStyle = .push
        saveButton.controlSize = .small
        saveButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelForm))
        cancelButton.bezelStyle = .push
        cancelButton.controlSize = .small

        urlRow.addArrangedSubview(urlField)
        urlRow.addArrangedSubview(saveButton)
        urlRow.addArrangedSubview(cancelButton)

        outer.addArrangedSubview(fieldsRow)
        outer.addArrangedSubview(urlRow)

        fieldsRow.widthAnchor.constraint(equalTo: outer.widthAnchor).isActive = true
        urlRow.widthAnchor.constraint(equalTo: outer.widthAnchor).isActive = true

        formKeywordField = keywordField
        formNameField = nameField
        formURLField = urlField
        formRow = outer

        return outer
    }

    @objc private func editQuicklink(_ sender: NSButton) {
        guard formRow == nil, let store = quickLinkStore else { return }
        let index = sender.tag
        guard store.quicklinks.indices.contains(index) else { return }
        let quicklink = store.quicklinks[index]

        editingIndex = index

        // Replace the display row with a form
        let displayRow = quicklinksStack.arrangedSubviews[index]
        let form = makeFormRow(keyword: quicklink.keyword, name: quicklink.name, url: quicklink.url)
        quicklinksStack.insertArrangedSubview(form, at: index)
        form.widthAnchor.constraint(equalTo: quicklinksStack.widthAnchor).isActive = true
        displayRow.removeFromSuperview()

        window?.makeFirstResponder(formKeywordField)
    }

    @objc private func removeQuicklink(_ sender: NSButton) {
        quickLinkStore?.remove(at: sender.tag)
        refreshQuicklinks()
    }

    @objc private func addQuicklink() {
        guard formRow == nil else { return }
        editingIndex = nil

        let form = makeFormRow()
        quicklinksStack.addArrangedSubview(form)
        form.widthAnchor.constraint(equalTo: quicklinksStack.widthAnchor).isActive = true

        window?.makeFirstResponder(formKeywordField)
    }

    @objc private func confirmForm() {
        guard let keywordField = formKeywordField,
              let nameField = formNameField,
              let urlField = formURLField
        else { return }

        let keyword = keywordField.stringValue.trimmingCharacters(in: .whitespaces)
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        let url = urlField.stringValue.trimmingCharacters(in: .whitespaces)

        guard !keyword.isEmpty, !name.isEmpty, !url.isEmpty else { return }

        let quicklink = QuickLink(keyword: keyword, name: name, url: url)
        if let index = editingIndex {
            quickLinkStore?.replace(at: index, with: quicklink)
        } else {
            quickLinkStore?.add(quicklink)
        }
        clearForm()
        refreshQuicklinks()
    }

    @objc private func cancelForm() {
        clearForm()
        refreshQuicklinks()
    }

    private func clearForm() {
        formRow = nil
        formKeywordField = nil
        formNameField = nil
        formURLField = nil
        editingIndex = nil
    }

    @objc private func openConfigFile() {
        guard let store = quickLinkStore else { return }
        let url = store.configURL

        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        NSWorkspace.shared.open(url)
    }

    @objc private func loginToggleChanged() {
        settingsManager.launchAtLogin = (loginToggle.state == .on)
    }
}
