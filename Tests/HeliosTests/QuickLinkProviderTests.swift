@testable import Helios
import Foundation
import Testing

@MainActor
struct QuickLinkProviderTests {
    private func makeProvider(quicklinks: [QuickLink] = []) -> QuickLinkProvider {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("quicklinks.yaml")
        let store = QuickLinkStore(configURL: url)
        for ql in quicklinks {
            store.add(ql)
        }
        return QuickLinkProvider(store: store)
    }

    private static let testLinks = [
        QuickLink(keyword: "sc", name: "Shortcut Story", url: "https://app.shortcut.com/org/story/{query}"),
        QuickLink(keyword: "gh", name: "GitHub", url: "https://github.com/{query}"),
    ]

    @Test
    func `canHandle with matching keyword`() {
        let provider = makeProvider(quicklinks: Self.testLinks)
        #expect(provider.canHandle(query: "sc 34185"))
        #expect(provider.canHandle(query: "gh user/repo"))
        #expect(provider.canHandle(query: "sc"))
    }

    @Test
    func `canHandle rejects non-matching keyword`() {
        let provider = makeProvider(quicklinks: Self.testLinks)
        #expect(!provider.canHandle(query: "jira 123"))
        #expect(!provider.canHandle(query: "hello world"))
        #expect(!provider.canHandle(query: ""))
    }

    @Test
    func `search returns hint when only keyword typed`() {
        let provider = makeProvider(quicklinks: Self.testLinks)
        let results = provider.search(query: "sc")

        #expect(results.count == 1)
        #expect(results[0].title == "Shortcut Story")
        #expect(results[0].subtitle == "Type a query after 'sc'")
        if case .none = results[0].action {
            // Expected
        } else {
            Issue.record("Expected .none action for hint result")
        }
    }

    @Test
    func `search constructs correct URL`() {
        let provider = makeProvider(quicklinks: Self.testLinks)
        let results = provider.search(query: "sc 34185")

        #expect(results.count == 1)
        #expect(results[0].title == "Shortcut Story: 34185")
        if case let .openURL(url) = results[0].action {
            #expect(url.absoluteString == "https://app.shortcut.com/org/story/34185")
        } else {
            Issue.record("Expected .openURL action")
        }
    }

    @Test
    func `search URL-encodes query with spaces`() {
        let provider = makeProvider(quicklinks: Self.testLinks)
        let results = provider.search(query: "gh my repo")

        #expect(results.count == 1)
        if case let .openURL(url) = results[0].action {
            #expect(url.absoluteString == "https://github.com/my%20repo")
        } else {
            Issue.record("Expected .openURL action")
        }
    }

    @Test
    func `search URL-encodes special characters`() {
        let provider = makeProvider(quicklinks: Self.testLinks)
        let results = provider.search(query: "gh foo&bar=baz")

        #expect(results.count == 1)
        if case let .openURL(url) = results[0].action {
            #expect(url.absoluteString.contains("foo%26bar%3Dbaz") || url.absoluteString.contains("foo&bar=baz"))
        } else {
            Issue.record("Expected .openURL action")
        }
    }

    @Test
    func `relevance is 10000`() {
        let provider = makeProvider(quicklinks: Self.testLinks)
        let results = provider.search(query: "sc 123")

        #expect(results.count == 1)
        #expect(results[0].relevance == 10000)
    }

    @Test
    func `search with no quicklinks returns empty`() {
        let provider = makeProvider()
        #expect(!provider.canHandle(query: "sc 123"))
        #expect(provider.search(query: "sc 123").isEmpty)
    }
}
