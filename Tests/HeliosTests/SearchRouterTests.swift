@testable import Helios
import Testing

@MainActor
private final class MockProvider: SearchProvider {
    let prefix: String
    let score: Double

    init(prefix: String, score: Double = 100) {
        self.prefix = prefix
        self.score = score
    }

    func canHandle(query: String) -> Bool {
        query.lowercased().hasPrefix(prefix)
    }

    func search(query: String) async -> [SearchResult] {
        [SearchResult(
            title: "\(prefix) result",
            subtitle: query,
            icon: nil,
            action: .none,
            relevance: score,
        )]
    }
}

/// Helper that replicates the provider iteration logic used by AppDelegate.
@MainActor
private func collectResults(from router: SearchRouter, query: String) async -> [SearchResult] {
    var results: [SearchResult] = []
    for provider in router.providers where provider.canHandle(query: query) {
        await results.append(contentsOf: provider.search(query: query))
    }
    results.sort { $0.relevance > $1.relevance }
    return results
}

@MainActor
struct SearchRouterTests {
    @Test
    func `empty query returns no results`() async {
        let router = SearchRouter(providers: [MockProvider(prefix: "a")])
        let results = await collectResults(from: router, query: "")
        #expect(results.isEmpty)
    }

    @Test
    func `dispatches to matching provider`() async {
        let router = SearchRouter(providers: [
            MockProvider(prefix: "foo"),
            MockProvider(prefix: "bar"),
        ])
        let results = await collectResults(from: router, query: "foo test")
        #expect(results.count == 1)
        #expect(results[0].title == "foo result")
    }

    @Test
    func `returns results from multiple matching providers`() async {
        let router = SearchRouter(providers: [
            MockProvider(prefix: "a", score: 50),
            MockProvider(prefix: "a", score: 100),
        ])
        let results = await collectResults(from: router, query: "abc")
        #expect(results.count == 2)
    }

    @Test
    func `sorts results by relevance descending`() async {
        let router = SearchRouter(providers: [
            MockProvider(prefix: "a", score: 50),
            MockProvider(prefix: "a", score: 200),
        ])
        let results = await collectResults(from: router, query: "abc")
        #expect(results.count == 2)
        #expect(results[0].relevance > results[1].relevance)
    }

    @Test
    func `no providers match returns empty`() async {
        let router = SearchRouter(providers: [
            MockProvider(prefix: "foo"),
        ])
        let results = await collectResults(from: router, query: "bar test")
        #expect(results.isEmpty)
    }
}
