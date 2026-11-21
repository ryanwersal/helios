import AppKit

@MainActor
final class SearchController: SearchFieldDelegate {
    private let panel: SearchPanel
    private let router: SearchRouter
    private let executeAction: (SearchResultAction) -> Bool
    private(set) var searchTask: Task<Void, Never>?

    init(
        panel: SearchPanel,
        router: SearchRouter,
        executeAction: @escaping (SearchResultAction) -> Bool = { SearchResultActionHandler.execute($0) },
    ) {
        self.panel = panel
        self.router = router
        self.executeAction = executeAction
        panel.searchField.searchDelegate = self
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        if !panel.resultsTableView.results.isEmpty {
            panel.resultsTableView.results = []
        }
    }

    func searchFieldDidChange(text: String) {
        cancelSearch()

        if text.isEmpty {
            panel.showEmptyState()
            return
        }
        panel.updateResultsHeight(count: 0)

        searchTask = Task { [weak self, router] in
            guard !Task.isCancelled else { return }
            var results: [SearchResult] = []
            for provider in router.providers where provider.canHandle(query: text) {
                let batch = await provider.search(query: text)
                guard let self, !Task.isCancelled else { return }
                guard !batch.isEmpty else { continue }
                results.append(contentsOf: batch)
                results.sort { $0.relevance > $1.relevance }
                panel.resultsTableView.results = results
                panel.updateResultsHeight(count: results.count)
            }
            guard !Task.isCancelled else { return }
            self?.searchTask = nil
        }
    }

    func searchFieldDidPressArrowDown() {
        panel.resultsTableView.moveSelectionDown()
    }

    func searchFieldDidPressArrowUp() {
        panel.resultsTableView.moveSelectionUp()
    }

    func searchFieldDidPressEnter() {
        // Current batches can be displayed as they arrive, but selection is provisional until search finishes.
        guard searchTask == nil else { return }
        if panel.resultsTableView.executeSelectedResult(using: executeAction) {
            panel.hidePanel()
        }
    }

    func searchFieldDidPressEscape() {
        cancelSearch()
        panel.hidePanel()
    }
}
