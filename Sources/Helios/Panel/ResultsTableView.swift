import AppKit

@MainActor
final class ResultsTableView: NSTableView, NSTableViewDataSource, NSTableViewDelegate {
    var results: [SearchResult] = [] {
        didSet {
            reloadData()
            if !results.isEmpty {
                selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            }
        }
    }

    private let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("results"))

    init() {
        super.init(frame: .zero)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        titleColumn.title = ""
        addTableColumn(titleColumn)
        headerView = nil
        dataSource = self
        delegate = self
        rowHeight = SearchPanel.resultRowHeight
        backgroundColor = .clear
        selectionHighlightStyle = .regular
        intercellSpacing = NSSize(width: 0, height: 0)
        style = .plain
    }

    // MARK: - Navigation

    func moveSelectionDown() {
        let next = selectedRow + 1
        if next < numberOfRows {
            selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
            scrollRowToVisible(next)
        }
    }

    func moveSelectionUp() {
        let prev = selectedRow - 1
        if prev >= 0 {
            selectRowIndexes(IndexSet(integer: prev), byExtendingSelection: false)
            scrollRowToVisible(prev)
        }
    }

    @discardableResult
    func executeSelectedResult() -> Bool {
        guard selectedRow >= 0, selectedRow < results.count else { return false }
        SearchResultActionHandler.execute(results[selectedRow].action)
        return true
    }

    // MARK: - Data Source

    func numberOfRows(in _: NSTableView) -> Int {
        results.count
    }

    // MARK: - Delegate

    func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard row < results.count else { return nil }
        let result = results[row]

        let cellID = NSUserInterfaceItemIdentifier("ResultCell")
        let cell: ResultCellView
        if let reused = makeView(withIdentifier: cellID, owner: nil) as? ResultCellView {
            cell = reused
        } else {
            cell = ResultCellView()
            cell.identifier = cellID
        }

        cell.configure(with: result)
        return cell
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        SearchPanel.resultRowHeight
    }

    func tableView(_: NSTableView, rowViewForRow _: Int) -> NSTableRowView? {
        let id = NSUserInterfaceItemIdentifier("SelectionRow")
        if let reused = makeView(withIdentifier: id, owner: nil) as? SelectionRowView {
            return reused
        }
        let rowView = SelectionRowView()
        rowView.identifier = id
        return rowView
    }
}

// MARK: - Result Cell View

@MainActor
final class ResultCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let badgeBackground = BadgeBackgroundView()
    private let badgeView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)

        badgeBackground.translatesAutoresizingMaskIntoConstraints = false
        badgeBackground.isHidden = true
        addSubview(badgeBackground)

        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.imageScaling = .scaleProportionallyDown
        badgeBackground.addSubview(badgeView)

        let textStack = NSStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        addSubview(textStack)

        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        textStack.addArrangedSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        textStack.addArrangedSubview(subtitleLabel)

        let badgeBackgroundSize: CGFloat = 16
        let badgeIconSize: CGFloat = 12

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            badgeBackground.widthAnchor.constraint(equalToConstant: badgeBackgroundSize),
            badgeBackground.heightAnchor.constraint(equalToConstant: badgeBackgroundSize),
            badgeBackground.trailingAnchor.constraint(
                equalTo: iconView.trailingAnchor, constant: 4,
            ),
            badgeBackground.bottomAnchor.constraint(
                equalTo: iconView.bottomAnchor, constant: 4,
            ),

            badgeView.widthAnchor.constraint(equalToConstant: badgeIconSize),
            badgeView.heightAnchor.constraint(equalToConstant: badgeIconSize),
            badgeView.centerXAnchor.constraint(equalTo: badgeBackground.centerXAnchor),
            badgeView.centerYAnchor.constraint(equalTo: badgeBackground.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(with result: SearchResult) {
        iconView.image = result.icon
        iconView.contentTintColor = result.iconIsTintable ? .secondaryLabelColor : nil
        titleLabel.stringValue = result.title
        subtitleLabel.stringValue = result.subtitle

        if let badge = result.badgeIcon {
            badgeView.image = badge
            badgeView.contentTintColor = nil
            badgeBackground.isHidden = false
        } else {
            badgeView.image = nil
            badgeBackground.isHidden = true
        }

        setAccessibilityLabel("\(result.title), \(result.subtitle)")
    }
}

// MARK: - Badge Background View

@MainActor
private final class BadgeBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let circle = NSBezierPath(ovalIn: bounds)
        NSColor.windowBackgroundColor.setFill()
        circle.fill()
        NSColor.separatorColor.setStroke()
        circle.lineWidth = 0.5
        circle.stroke()
    }
}

// MARK: - Custom Selection Row View

@MainActor
private final class SelectionRowView: NSTableRowView {
    override func drawSelection(in _: NSRect) {
        guard isSelected else { return }
        let rect = bounds.insetBy(dx: 6, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor.quaternaryLabelColor.setFill()
        path.fill()
    }
}
