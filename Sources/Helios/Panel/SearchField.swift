import AppKit

@MainActor
protocol SearchFieldDelegate: AnyObject {
    func searchFieldDidChange(text: String)
    func searchFieldDidPressArrowDown()
    func searchFieldDidPressArrowUp()
    func searchFieldDidPressEnter()
    func searchFieldDidPressEscape()
}

@MainActor
final class SearchField: NSTextField {
    weak var searchDelegate: SearchFieldDelegate?

    init() {
        super.init(frame: .zero)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        placeholderString = "Search apps, bookmarks, calculate, check time..."
        font = .systemFont(ofSize: 24, weight: .light)
        isBordered = false
        isBezeled = false
        drawsBackground = false
        focusRingType = .none
        textColor = .labelColor
        cell?.usesSingleLineMode = true
        cell?.isScrollable = true
        delegate = self
    }

    func focusAndSelectAll() {
        window?.makeFirstResponder(self)
        currentEditor()?.selectAll(nil)
    }
}

extension SearchField: NSTextFieldDelegate {
    func controlTextDidChange(_: Notification) {
        searchDelegate?.searchFieldDidChange(text: stringValue)
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(moveDown(_:)):
            searchDelegate?.searchFieldDidPressArrowDown()
            return true
        case #selector(moveUp(_:)):
            searchDelegate?.searchFieldDidPressArrowUp()
            return true
        case #selector(insertNewline(_:)):
            searchDelegate?.searchFieldDidPressEnter()
            return true
        case #selector(cancelOperation(_:)):
            searchDelegate?.searchFieldDidPressEscape()
            return true
        default:
            return false
        }
    }
}
