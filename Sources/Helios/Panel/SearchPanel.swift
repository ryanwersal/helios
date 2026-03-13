import AppKit

enum PanelMode {
    case search
    case settings
}

@MainActor
final class SearchPanel: NSPanel {
    static let panelWidth: CGFloat = 680
    static let searchFieldHeight: CGFloat = 52
    static let resultRowHeight: CGFloat = 48
    static let maxVisibleResults = 8
    static let emptyStateHeight: CGFloat = 160
    static let settingsHeight: CGFloat = 360
    static let contextBarHeight: CGFloat = ContextBarView.height

    let searchField: SearchField
    let resultsTableView: ResultsTableView

    private let containerView: AppearanceAwareView
    private let searchIcon: NSImageView
    private let scrollView: NSScrollView
    private let separatorView: NSBox
    private let emptyStateView: EmptyStateView
    private let settingsView: SettingsView
    private let settingsScrollView: NSScrollView
    private let contextBarView: ContextBarView
    private let resultsHeightConstraint: NSLayoutConstraint
    private var mode: PanelMode = .search

    init(
        settingsManager: SettingsManager,
        quickLinkStore: QuickLinkStore? = nil,
        pluginManager: PluginManager? = nil,
    ) {
        searchField = SearchField()
        resultsTableView = ResultsTableView()
        containerView = AppearanceAwareView()
        searchIcon = NSImageView()
        scrollView = NSScrollView()
        separatorView = NSBox()
        emptyStateView = EmptyStateView()
        settingsView = SettingsView(
            settingsManager: settingsManager,
            quickLinkStore: quickLinkStore,
            pluginManager: pluginManager,
        )
        settingsScrollView = NSScrollView()
        contextBarView = ContextBarView()

        let initialFrame = NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.searchFieldHeight)
        resultsHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 0)

        super.init(
            contentRect: initialFrame,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false,
        )

        configurePanel()
        setupViews()
        positionOnScreen()
    }

    // MARK: - Configuration

    private func configurePanel() {
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        hasShadow = true
        animationBehavior = .none

        contentView?.wantsLayer = true
    }

    private func setupViews() {
        guard let contentView else { return }

        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        searchIcon.contentTintColor = .tertiaryLabelColor
        searchIcon.imageScaling = .scaleProportionallyDown
        containerView.addSubview(searchIcon)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(searchField)

        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.boxType = .separator
        separatorView.isHidden = true
        containerView.addSubview(separatorView)

        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        containerView.addSubview(emptyStateView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = resultsTableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        containerView.addSubview(scrollView)

        settingsScrollView.translatesAutoresizingMaskIntoConstraints = false
        settingsScrollView.documentView = settingsView
        settingsScrollView.hasVerticalScroller = true
        settingsScrollView.autohidesScrollers = true
        settingsScrollView.drawsBackground = false
        settingsScrollView.borderType = .noBorder
        settingsScrollView.automaticallyAdjustsContentInsets = false
        settingsScrollView.isHidden = true
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(settingsScrollView)

        contextBarView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contextBarView)

        activateLayoutConstraints(contentView: contentView)
    }

    private func activateLayoutConstraints(contentView: NSView) {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            searchIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            searchIcon.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 20),
            searchIcon.heightAnchor.constraint(equalToConstant: 20),

            searchField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            searchField.heightAnchor.constraint(equalToConstant: Self.searchFieldHeight),

            separatorView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            separatorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            emptyStateView.topAnchor.constraint(equalTo: separatorView.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            emptyStateView.heightAnchor.constraint(equalToConstant: Self.emptyStateHeight),

            scrollView.topAnchor.constraint(equalTo: separatorView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            resultsHeightConstraint,

            settingsScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            settingsScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            settingsScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            settingsScrollView.bottomAnchor.constraint(equalTo: contextBarView.topAnchor),

            settingsView.topAnchor.constraint(equalTo: settingsScrollView.contentView.topAnchor),
            settingsView.leadingAnchor.constraint(equalTo: settingsScrollView.contentView.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: settingsScrollView.contentView.trailingAnchor),

            contextBarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contextBarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contextBarView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            contextBarView.heightAnchor.constraint(equalToConstant: Self.contextBarHeight),
        ])
    }

    // MARK: - Positioning

    func positionOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let originX = screenFrame.midX - Self.panelWidth / 2
        let originY = screenFrame.maxY - frame.height - screenFrame.height * 0.2
        setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    // MARK: - Empty State

    func showEmptyState() {
        emptyStateView.isHidden = false
        scrollView.isHidden = true
        separatorView.isHidden = false
        resultsTableView.results = []
        resultsHeightConstraint.constant = 0
        setPanelHeight(Self.searchFieldHeight + 16 + 1 + Self.emptyStateHeight + Self.contextBarHeight)
    }

    private func hideEmptyState() {
        emptyStateView.isHidden = true
        scrollView.isHidden = false
    }

    // MARK: - Results Management

    func updateResultsHeight(count: Int) {
        hideEmptyState()

        let showResults = count > 0
        separatorView.isHidden = !showResults

        let visibleCount = min(count, Self.maxVisibleResults)
        let height = CGFloat(visibleCount) * Self.resultRowHeight
        resultsHeightConstraint.constant = height

        let totalHeight = Self.searchFieldHeight + 16 + (showResults ? height + 1 : 0) + Self.contextBarHeight
        setPanelHeight(totalHeight)
    }

    private func setPanelHeight(_ totalHeight: CGFloat) {
        var frame = frame
        let oldHeight = frame.height
        frame.size.height = totalHeight
        frame.origin.y += oldHeight - totalHeight
        setFrame(frame, display: true, animate: false)
    }

    // MARK: - Panel Mode

    func showSettings() {
        mode = .settings

        // Hide search UI
        searchIcon.isHidden = true
        searchField.isHidden = true
        separatorView.isHidden = true
        emptyStateView.isHidden = true
        scrollView.isHidden = true

        // Show settings
        settingsScrollView.isHidden = false
        settingsView.refresh()
        settingsScrollView.contentView.scroll(to: .zero)
        contextBarView.updateForMode(.settings)

        setPanelHeight(Self.settingsHeight + Self.contextBarHeight)
        positionOnScreen()

        // Make the panel first responder so Escape triggers cancelOperation
        makeFirstResponder(nil)
    }

    func showSearch() {
        mode = .search

        // Hide settings
        settingsScrollView.isHidden = true

        // Restore search UI
        searchIcon.isHidden = false
        searchField.isHidden = false
        contextBarView.updateForMode(.search)

        showEmptyState()
        searchField.stringValue = ""
        resultsTableView.results = []
        searchField.focusAndSelectAll()
        positionOnScreen()
    }

    func setSettingsHandler(_ handler: @escaping () -> Void) {
        contextBarView.onSettingsButtonPressed = handler
    }

    // MARK: - Show / Hide

    func showPanel() {
        showEmptyState()
        positionOnScreen()
        makeKeyAndOrderFront(nil)
        searchField.focusAndSelectAll()
    }

    func hidePanel() {
        if mode == .settings {
            resetToSearchMode()
        }
        orderOut(nil)
        searchField.stringValue = ""
        resultsTableView.results = []
        updateResultsHeight(count: 0)
    }

    /// Resets internal mode state without repositioning or showing the panel.
    private func resetToSearchMode() {
        mode = .search
        settingsScrollView.isHidden = true
        searchIcon.isHidden = false
        searchField.isHidden = false
        contextBarView.updateForMode(.search)
    }

    func toggle() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    override var canBecomeKey: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, mode == .settings {
            // Forward to shortcut recorder when recording
            if settingsView.handleKeyEventIfRecording(event) {
                return
            }

            // Handle Tab / Shift-Tab for field navigation.
            // NSWindow.sendEvent swallows Tab for keyboard interface control
            // before it reaches the field editor, so the NSTextFieldDelegate
            // approach doesn't work. We intercept here instead, finding the
            // actual NSTextField from the field editor and navigating from it.
            if event.keyCode == 48 { // Tab
                if let fieldEditor = firstResponder as? NSTextView,
                   fieldEditor.isFieldEditor,
                   let editedField = fieldEditor.delegate as? NSTextField
                {
                    let target = if event.modifierFlags.contains(.shift) {
                        editedField.previousKeyView
                    } else {
                        editedField.nextKeyView
                    }
                    if let target {
                        makeFirstResponder(target)
                    }
                    return
                }
            }
        }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // In a .nonactivatingPanel, standard editing key equivalents (Cmd+C/V/X/A)
        // don't reach the field editor because the app's Edit menu isn't active.
        if mode == .settings,
           forwardEditingKeyEquivalent(event)
        {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Forwards Cmd+C/V/X/A to the current field editor. Returns true if handled.
    private func forwardEditingKeyEquivalent(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              let fieldEditor = firstResponder as? NSTextView
        else { return false }

        switch event.charactersIgnoringModifiers {
        case "v": fieldEditor.paste(nil)
        case "c": fieldEditor.copy(nil)
        case "x": fieldEditor.cut(nil)
        case "a": fieldEditor.selectAll(nil)
        default: return false
        }
        return true
    }

    override func cancelOperation(_: Any?) {
        if mode == .settings {
            showSearch()
        }
    }
}
