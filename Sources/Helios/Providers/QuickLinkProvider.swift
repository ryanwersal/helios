import AppKit

@MainActor
final class QuickLinkProvider: SearchProvider {
    private let store: QuickLinkStore

    init(store: QuickLinkStore) {
        self.store = store
    }

    func canHandle(query: String) -> Bool {
        let keyword = extractKeyword(from: query)
        return store.quicklinks.contains { $0.keyword == keyword }
    }

    func search(query: String) async -> [SearchResult] {
        let keyword = extractKeyword(from: query)
        guard let quicklink = store.quicklinks.first(where: { $0.keyword == keyword }) else {
            return []
        }

        let queryPart = extractQuery(from: query)
        let icon = NSImage(systemSymbolName: "link", accessibilityDescription: "Quicklink")

        if queryPart.isEmpty {
            return [SearchResult(
                title: quicklink.name,
                subtitle: "Type a query after '\(keyword)'",
                icon: icon,
                action: .none,
                relevance: 10000,
            )]
        }

        guard let encodedQuery = queryPart.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: quicklink.url.replacingOccurrences(of: "{query}", with: encodedQuery))
        else {
            return []
        }

        return [SearchResult(
            title: "\(quicklink.name): \(queryPart)",
            subtitle: url.absoluteString,
            icon: icon,
            action: .openURL(url),
            relevance: 10000,
        )]
    }

    private func extractKeyword(from query: String) -> String {
        let parts = query.split(separator: " ", maxSplits: 1)
        return String(parts.first ?? "")
    }

    private func extractQuery(from query: String) -> String {
        let parts = query.split(separator: " ", maxSplits: 1)
        guard parts.count > 1 else { return "" }
        return String(parts[1])
    }
}
