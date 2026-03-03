@MainActor
protocol SearchProvider {
    /// Whether this provider can handle the given query.
    func canHandle(query: String) -> Bool

    /// Return results for the given query. Called only if canHandle returns true.
    /// Must be fast — operates on in-memory data.
    func search(query: String) -> [SearchResult]
}
