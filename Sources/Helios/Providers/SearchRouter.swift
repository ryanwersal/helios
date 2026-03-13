@MainActor
final class SearchRouter {
    private(set) var providers: [SearchProvider]

    init(providers: [SearchProvider]) {
        self.providers = providers
    }

    func addProviders(_ newProviders: [SearchProvider]) {
        providers.append(contentsOf: newProviders)
    }

    func search(query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        var results: [SearchResult] = []
        for provider in providers where provider.canHandle(query: query) {
            results.append(contentsOf: provider.search(query: query))
        }

        results.sort { $0.relevance > $1.relevance }
        return results
    }
}
