import AppKit

enum SearchResultAction {
    case openURL(URL)
    case copyToClipboard(String)
    case none
}

struct SearchResult {
    let title: String
    let subtitle: String
    let icon: NSImage?
    let iconIsTintable: Bool
    let action: SearchResultAction
    let relevance: Double

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        iconIsTintable: Bool = true,
        action: SearchResultAction,
        relevance: Double
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconIsTintable = iconIsTintable
        self.action = action
        self.relevance = relevance
    }
}

@MainActor
enum SearchResultActionHandler {
    static func execute(_ action: SearchResultAction) {
        switch action {
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        case .copyToClipboard(let text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case .none:
            break
        }
    }
}
