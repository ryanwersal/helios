import Testing
@testable import Helios

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

    func search(query: String) -> [SearchResult] {
        [SearchResult(
            title: "\(prefix) result",
            subtitle: query,
            icon: nil,
            action: .none,
            relevance: score
        )]
    }
}

@MainActor
@Suite("SearchRouter")
struct SearchRouterTests {
    @Test("empty query returns no results")
    func emptyQuery() {
        let router = SearchRouter(providers: [MockProvider(prefix: "a")])
        let results = router.search(query: "")
        #expect(results.isEmpty)
    }

    @Test("dispatches to matching provider")
    func matchingProvider() {
        let router = SearchRouter(providers: [
            MockProvider(prefix: "foo"),
            MockProvider(prefix: "bar"),
        ])
        let results = router.search(query: "foo test")
        #expect(results.count == 1)
        #expect(results[0].title == "foo result")
    }

    @Test("returns results from multiple matching providers")
    func multipleProviders() {
        let router = SearchRouter(providers: [
            MockProvider(prefix: "a", score: 50),
            MockProvider(prefix: "a", score: 100),
        ])
        let results = router.search(query: "abc")
        #expect(results.count == 2)
    }

    @Test("sorts results by relevance descending")
    func sortsByRelevance() {
        let router = SearchRouter(providers: [
            MockProvider(prefix: "a", score: 50),
            MockProvider(prefix: "a", score: 200),
        ])
        let results = router.search(query: "abc")
        #expect(results.count == 2)
        #expect(results[0].relevance > results[1].relevance)
    }

    @Test("no providers match returns empty")
    func noMatch() {
        let router = SearchRouter(providers: [
            MockProvider(prefix: "foo"),
        ])
        let results = router.search(query: "bar test")
        #expect(results.isEmpty)
    }
}
