import Foundation
@testable import Helios
import Testing

@MainActor
struct SearchResultActionTests {
    @Test
    func `selected diagnostic does not execute or lose selection`() {
        let table = ResultsTableView()
        table.results = DateTimeProvider().results(for: "3pm from CST to London")
        #expect(table.results.map(\.action) == [.none])
        #expect(table.selectedRow == 0)
        let executed = table.executeSelectedResult()
        #expect(!executed)
        #expect(table.selectedRow == 0)
    }

    @Test
    func `copy and open dispatch their payload and report the action outcome`() throws {
        let url = try #require(URL(string: "https://example.com"))
        for succeeded in [true, false] {
            var opened: URL?
            var copied: String?
            let didOpen = SearchResultActionHandler.execute(.openURL(url), openURL: {
                opened = $0
                return succeeded
            }, copyToClipboard: { _ in
                Issue.record("Unexpected copy while opening a URL")
                return false
            })
            let didCopy = SearchResultActionHandler.execute(.copyToClipboard("Berlin"), openURL: { _ in
                Issue.record("Unexpected open while copying")
                return false
            }, copyToClipboard: {
                copied = $0
                return succeeded
            })
            #expect(opened == url)
            #expect(copied == "Berlin")
            #expect(didOpen == succeeded)
            #expect(didCopy == succeeded)
        }
    }
}
