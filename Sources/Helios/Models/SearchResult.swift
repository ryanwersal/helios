import AppKit

enum SearchResultAction: Equatable {
    case openURL(URL)
    case copyToClipboard(String)
    case none
}

struct SearchResult {
    let title: String
    let subtitle: String
    let icon: NSImage?
    let iconIsTintable: Bool
    let badgeIcon: NSImage?
    let action: SearchResultAction
    let relevance: Double

    init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        iconIsTintable: Bool = true,
        badgeIcon: NSImage? = nil,
        action: SearchResultAction,
        relevance: Double,
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconIsTintable = iconIsTintable
        self.badgeIcon = badgeIcon
        self.action = action
        self.relevance = relevance
    }
}

@MainActor
enum SearchResultActionHandler {
    static func execute(
        _ action: SearchResultAction,
        openURL: (URL) -> Bool = { NSWorkspace.shared.open($0) },
        copyToClipboard: (String) -> Bool = { text in
            NSPasteboard.general.clearContents()
            return NSPasteboard.general.setString(text, forType: .string)
        },
    ) -> Bool {
        switch action {
        case let .openURL(url):
            openURL(url)
        case let .copyToClipboard(text):
            copyToClipboard(text)
        case .none:
            false
        }
    }
}
