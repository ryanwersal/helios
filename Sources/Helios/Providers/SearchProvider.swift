@MainActor
protocol SearchProvider {
    /// Whether this provider can handle the given query.
    func canHandle(query: String) -> Bool

    /// Return results for the given query. Called only if canHandle returns true.
    func search(query: String) async -> [SearchResult]
}
