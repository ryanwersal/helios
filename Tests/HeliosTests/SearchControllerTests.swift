import AppKit
@testable import Helios
import Testing

@MainActor
struct SearchControllerTests {
    @Test
    func `unit conversion has no time diagnostic in combined search results`() async {
        let search = SearchFixture(providers: [CalculatorProvider(), UnitConversionProvider(), DateTimeProvider()])
        await search.type("5 cups in liters")?.value

        #expect(search.table.results.map(\.title) == ["= 1.2 liters"])
        #expect(search.table.results.map(\.subtitle) == ["5 cups → liters"])
        #expect(search.table.results.map(\.action) == [.copyToClipboard("1.2")])
    }

    @Test(arguments: [
        ("time in Tokyo", "9:00 PM (+09:00) — Thursday, Jan 15", "Tokyo (Asia/Tokyo)", true),
        ("3pm in New York to London", "8:00 PM in London", "Europe/London", true),
        ("3pm from Atlantis to London", "Unknown time zone “Atlantis”", "Use a city such as London", false),
        ("3pm from CST to London", "“CST” is ambiguous", "Choose a city or IANA zone", false),
        ("3pm New York to London", "Try “3pm in New York to London”", "Or use a date", false),
    ])
    func `combined search preserves time results and guidance`(
        query: String, title: String, guidance: String, isCopyable: Bool,
    ) async throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z"))
        let search = SearchFixture(providers: [UnitConversionProvider(), DateTimeProvider(now: { date })])
        await search.type(query)?.value

        #expect(search.table.results.map(\.title) == [title])
        let result = try #require(search.table.results.first)
        #expect(result.subtitle.contains(guidance))
        if isCopyable {
            guard case .copyToClipboard = result.action else {
                Issue.record("Expected a copyable time result")
                return
            }
        } else {
            #expect(result.action == .none)
        }
    }

    @Test
    func `enter and visible rows follow the current completed query through rapid changes`() async {
        let noMatch = "qzvkmwznoresult731c9d"
        let quickTimeURL = URL(fileURLWithPath: "/System/Applications/QuickTime Player.app")
        let timeMachineURL = URL(fileURLWithPath: "/System/Applications/Time Machine.app")
        let apps = AppLauncherProvider(apps: [
            AppInfo(name: "QuickTime Player", url: quickTimeURL, icon: NSImage()),
            AppInfo(name: "Time Machine", url: timeMachineURL, icon: NSImage()),
        ])
        let delayed = DelayedProvider(queries: ["qu", noMatch])
        var starts = delayed.starts.makeAsyncIterator()
        var actions: [SearchResultAction] = []
        var allowActivation = false
        let search = SearchFixture(providers: [apps, delayed], execute: {
            actions.append($0)
            return allowActivation
        })

        await search.type("q")?.value
        #expect(search.table.results.map(\.title) == ["QuickTime Player"])
        #expect(search.table.selectedRow == 0)

        let previous = search.type("qu")
        #expect(await starts.next() == "qu")
        search.controller.searchFieldDidPressEnter()
        #expect(actions.isEmpty, "A partially completed query cannot activate its app row")
        actions.removeAll()

        search.type("q")
        search.type("qz")
        search.type("qzv")
        let current = search.type(noMatch)
        #expect(await starts.next() == noMatch)
        search.controller.searchFieldDidPressEnter()
        #expect(actions.isEmpty, "Enter during replacement cannot activate the previous selection")
        actions.removeAll()

        delayed.finish(noMatch, with: [])
        await current?.value
        #expect(search.table.numberOfRows == 0)
        #expect(search.table.selectedRow == -1)
        search.controller.searchFieldDidPressEnter()
        #expect(actions.isEmpty, "A completed zero-result query cannot activate the previous selection")

        delayed.finish("qu", with: [SearchResult(
            title: "Delayed QuickTime result", subtitle: quickTimeURL.path, icon: nil,
            action: .openURL(quickTimeURL), relevance: 1000,
        )])
        await previous?.value
        #expect(search.table.results.isEmpty)

        actions.removeAll()
        allowActivation = true
        await navigateAndActivate(in: search)
        #expect(actions == [.openURL(quickTimeURL)])
    }

    private func navigateAndActivate(in search: SearchFixture) async {
        await search.type("time")?.value
        #expect(search.table.results.map(\.title) == ["Time Machine", "QuickTime Player"])
        #expect(search.table.selectedRow == 0)
        search.controller.searchFieldDidPressArrowDown()
        #expect(search.table.selectedRow == 1)
        search.controller.searchFieldDidPressArrowUp()
        #expect(search.table.selectedRow == 0)
        search.controller.searchFieldDidPressArrowDown()
        search.controller.searchFieldDidPressEnter()
        #expect(search.field.stringValue.isEmpty)
    }
}

@MainActor
private struct SearchFixture {
    let panel = SearchPanel(settingsManager: SettingsManager())
    let controller: SearchController

    var table: ResultsTableView {
        panel.resultsTableView
    }

    var field: SearchField {
        panel.searchField
    }

    init(providers: [SearchProvider], execute: @escaping (SearchResultAction) -> Bool = { _ in false }) {
        controller = SearchController(panel: panel, router: SearchRouter(providers: providers), executeAction: execute)
    }

    @discardableResult
    func type(_ query: String) -> Task<Void, Never>? {
        field.stringValue = query
        field.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        return controller.searchTask
    }
}

@MainActor
private final class DelayedProvider: SearchProvider {
    let starts: AsyncStream<String>
    private let announceStart: AsyncStream<String>.Continuation
    private let queries: Set<String>
    private var pending: [String: CheckedContinuation<[SearchResult], Never>] = [:]

    init(queries: Set<String>) {
        self.queries = queries
        (starts, announceStart) = AsyncStream.makeStream()
    }

    func canHandle(query: String) -> Bool {
        queries.contains(query)
    }

    func search(query: String) async -> [SearchResult] {
        await withCheckedContinuation { continuation in
            pending[query] = continuation
            announceStart.yield(query)
        }
    }

    func finish(_ query: String, with results: [SearchResult]) {
        pending.removeValue(forKey: query)?.resume(returning: results)
    }
}
