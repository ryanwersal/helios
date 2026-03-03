import AppKit

@MainActor
final class SearchPanel: NSPanel {
    static let panelWidth: CGFloat = 680
    static let searchFieldHeight: CGFloat = 52
    static let resultRowHeight: CGFloat = 48
    static let maxVisibleResults = 8
    static let emptyStateHeight: CGFloat = 160
    static let contextBarHeight: CGFloat = ContextBarView.height

    let searchField: SearchField
    let resultsTableView: ResultsTableView

    private let containerView: AppearanceAwareView
    private let scrollView: NSScrollView
    private let separatorView: NSBox
    private let emptyStateView: EmptyStateView
    private let contextBarView: ContextBarView
    private let resultsHeightConstraint: NSLayoutConstraint

    init() {
        searchField = SearchField()
        resultsTableView = ResultsTableView()
        containerView = AppearanceAwareView()
        scrollView = NSScrollView()
        separatorView = NSBox()
        emptyStateView = EmptyStateView()
        contextBarView = ContextBarView()

        let initialFrame = NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.searchFieldHeight)
        resultsHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 0)

        super.init(
            contentRect: initialFrame,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
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

        let searchIcon = NSImageView()
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

        contextBarView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contextBarView)

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
        let x = screenFrame.midX - Self.panelWidth / 2
        let y = screenFrame.maxY - frame.height - screenFrame.height * 0.2
        setFrameOrigin(NSPoint(x: x, y: y))
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
        var frame = self.frame
        let oldHeight = frame.height
        frame.size.height = totalHeight
        frame.origin.y += oldHeight - totalHeight
        setFrame(frame, display: true, animate: false)
    }

    // MARK: - Show / Hide

    func showPanel() {
        showEmptyState()
        positionOnScreen()
        makeKeyAndOrderFront(nil)
        searchField.focusAndSelectAll()
    }

    func hidePanel() {
        orderOut(nil)
        searchField.stringValue = ""
        resultsTableView.results = []
        updateResultsHeight(count: 0)
    }

    func toggle() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    override var canBecomeKey: Bool { true }

}

// MARK: - Appearance-Aware Container View

@MainActor
private final class AppearanceAwareView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        updateBackground()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }

    private func updateBackground() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
    }
}
