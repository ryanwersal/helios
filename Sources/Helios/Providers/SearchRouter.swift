@MainActor
final class SearchRouter {
    private let providers: [SearchProvider]

    init(providers: [SearchProvider]) {
        self.providers = providers
    }

    func search(query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        var results: [SearchResult] = []
        for provider in providers {
            if provider.canHandle(query: query) {
                results.append(contentsOf: provider.search(query: query))
            }
        }

        results.sort { $0.relevance > $1.relevance }
        return results
    }
}
