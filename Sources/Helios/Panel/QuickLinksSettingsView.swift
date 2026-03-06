import AppKit

@MainActor
final class QuickLinksSettingsView: NSView {
    private let store: QuickLinkStore
    private let listStack = NSStackView()

    /// Index of the quicklink currently being edited, or nil if adding new.
    private var editingIndex: Int?
    private var formRow: NSStackView?
    private var formKeywordField: NSTextField?
    private var formNameField: NSTextField?
    private var formURLField: NSTextField?

    init(store: QuickLinkStore) {
        self.store = store
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

        let sectionLabel = NSTextField(labelWithString: "Quicklinks")
        sectionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        sectionLabel.textColor = .labelColor
        stack.addArrangedSubview(sectionLabel)

        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 6
        listStack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(listStack)

        let buttonsRow = makeButtonsRow()
        stack.addArrangedSubview(buttonsRow)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),

            listStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonsRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func makeButtonsRow() -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let addButton = NSButton(title: "Add", target: self, action: #selector(addQuicklink))
        addButton.bezelStyle = .push
        addButton.controlSize = .small
        addButton.setAccessibilityLabel("Add Quicklink")

        let openButton = NSButton(
            title: "Open Config File",
            target: self,
            action: #selector(openConfigFile)
        )
        openButton.bezelStyle = .push
        openButton.controlSize = .small
        openButton.setAccessibilityLabel("Open Quicklinks Config File")

        row.addArrangedSubview(addButton)
        row.addArrangedSubview(openButton)
        return row
    }

    func refresh() {
        store.reload()
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        clearForm()

        for (index, quicklink) in store.quicklinks.enumerated() {
            let row = makeDisplayRow(quicklink: quicklink, index: index)
            listStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true
        }

        if store.quicklinks.isEmpty {
            let label = NSTextField(labelWithString: "No quicklinks configured")
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            listStack.addArrangedSubview(label)
        }
    }

    // MARK: - Display Row

    private func makeDisplayRow(quicklink: QuickLink, index: Int) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 2
        container.translatesAutoresizingMaskIntoConstraints = false

        let topRow = makeDisplayTopRow(quicklink: quicklink, index: index)
        container.addArrangedSubview(topRow)
        topRow.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        let urlLabel = NSTextField(labelWithString: quicklink.url)
        urlLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        urlLabel.textColor = .tertiaryLabelColor
        urlLabel.lineBreakMode = .byTruncatingTail
        urlLabel.maximumNumberOfLines = 1
        container.addArrangedSubview(urlLabel)
        urlLabel.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor).isActive = true

        return container
    }

    private func makeDisplayTopRow(quicklink: QuickLink, index: Int) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

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

        row.addArrangedSubview(keywordLabel)
        row.addArrangedSubview(nameLabel)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(editButton)
        row.addArrangedSubview(removeButton)

        return row
    }

    // MARK: - Form

    private func makeFormRow(keyword: String = "", name: String = "", url: String = "") -> NSStackView {
        let outer = NSStackView()
        outer.orientation = .vertical
        outer.alignment = .leading
        outer.spacing = 4
        outer.translatesAutoresizingMaskIntoConstraints = false

        let fieldsRow = makeFormFieldsRow(keyword: keyword, name: name)
        let urlRow = makeFormURLRow(url: url)

        outer.addArrangedSubview(fieldsRow)
        outer.addArrangedSubview(urlRow)
        fieldsRow.widthAnchor.constraint(equalTo: outer.widthAnchor).isActive = true
        urlRow.widthAnchor.constraint(equalTo: outer.widthAnchor).isActive = true

        formRow = outer
        return outer
    }

    private func makeFormFieldsRow(keyword: String, name: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let keywordField = NSTextField()
        keywordField.placeholderString = "keyword"
        keywordField.stringValue = keyword
        keywordField.font = .systemFont(ofSize: 12)
        keywordField.delegate = self
        keywordField.widthAnchor.constraint(equalToConstant: 70).isActive = true

        let nameField = NSTextField()
        nameField.placeholderString = "name"
        nameField.stringValue = name
        nameField.font = .systemFont(ofSize: 12)
        nameField.delegate = self

        formKeywordField = keywordField
        formNameField = nameField

        row.addArrangedSubview(keywordField)
        row.addArrangedSubview(nameField)
        return row
    }

    private func makeFormURLRow(url: String) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let urlField = NSTextField()
        urlField.placeholderString = "https://example.com/{query}"
        urlField.stringValue = url
        urlField.font = .systemFont(ofSize: 12)
        urlField.delegate = self

        let saveButton = NSButton(title: "Save", target: self, action: #selector(confirmForm))
        saveButton.bezelStyle = .push
        saveButton.controlSize = .small
        saveButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelForm))
        cancelButton.bezelStyle = .push
        cancelButton.controlSize = .small

        formURLField = urlField

        // Set up key view loop after all fields are created
        formKeywordField?.nextKeyView = formNameField
        formNameField?.nextKeyView = urlField
        urlField.nextKeyView = formKeywordField

        row.addArrangedSubview(urlField)
        row.addArrangedSubview(saveButton)
        row.addArrangedSubview(cancelButton)
        return row
    }

    // MARK: - Actions

    @objc private func editQuicklink(_ sender: NSButton) {
        guard formRow == nil else { return }
        let index = sender.tag
        guard store.quicklinks.indices.contains(index) else { return }
        let quicklink = store.quicklinks[index]

        editingIndex = index
        let displayRow = listStack.arrangedSubviews[index]
        let form = makeFormRow(keyword: quicklink.keyword, name: quicklink.name, url: quicklink.url)
        listStack.insertArrangedSubview(form, at: index)
        form.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true
        displayRow.removeFromSuperview()

        window?.makeFirstResponder(formKeywordField)
    }

    @objc private func removeQuicklink(_ sender: NSButton) {
        store.remove(at: sender.tag)
        refresh()
    }

    @objc private func addQuicklink() {
        guard formRow == nil else { return }
        editingIndex = nil

        let form = makeFormRow()
        listStack.addArrangedSubview(form)
        form.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true

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
            store.replace(at: index, with: quicklink)
        } else {
            store.add(quicklink)
        }
        clearForm()
        refresh()
    }

    @objc private func cancelForm() {
        clearForm()
        refresh()
    }

    private func clearForm() {
        formRow = nil
        formKeywordField = nil
        formNameField = nil
        formURLField = nil
        editingIndex = nil
    }

    @objc private func openConfigFile() {
        let url = store.configURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Tab Navigation for Form Fields

extension QuickLinksSettingsView: NSTextFieldDelegate {
    func control(
        _ control: NSControl,
        textView _: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            window?.selectNextKeyView(control)
            return true
        }
        if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
            window?.selectPreviousKeyView(control)
            return true
        }
        return false
    }
}
