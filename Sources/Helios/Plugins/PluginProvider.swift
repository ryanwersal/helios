import AppKit

@MainActor
final class PluginProvider: SearchProvider {
    let manifest: PluginManifest
    private let process: PluginProcess
    private var cachedQuery: String = ""
    private var cachedResults: [SearchResult] = []
    var onResultsUpdated: (() -> Void)?

    init(manifest: PluginManifest, process: PluginProcess) {
        self.manifest = manifest
        self.process = process
    }

    func canHandle(query: String) -> Bool {
        if let keyword = manifest.keyword {
            return query.lowercased().hasPrefix(keyword + " ") || query.lowercased() == keyword
        }
        return true
    }

    func search(query: String) -> [SearchResult] {
        cachedQuery = query

        let id = UUID().uuidString
        Task {
            await sendSearch(query: query, id: id)
        }

        return cachedQuery == query ? cachedResults : []
    }

    private func sendSearch(query: String, id: String) async {
        do {
            try await process.search(query: query, id: id) { [weak self] response in
                Task { @MainActor in
                    self?.handleResponse(response, for: query)
                }
            }
        } catch {
            NSLog(
                "[Helios] Plugin '%@' search failed: %@",
                manifest.name,
                error.localizedDescription,
            )
        }
    }

    private func handleResponse(_ response: PluginResponse, for query: String) {
        guard let items = response.results else { return }

        let results = items.map { item -> SearchResult in
            let icon = resolveIcon(item)
            let tintable = item.iconTintable ?? (item.iconSystemName != nil)

            let action: SearchResultAction = switch item.action.type {
            case .openURL:
                if let urlString = item.action.url, let url = URL(string: urlString) {
                    .openURL(url)
                } else {
                    .none
                }
            case .copyToClipboard:
                .copyToClipboard(item.action.text ?? "")
            }

            return SearchResult(
                title: item.title,
                subtitle: item.subtitle,
                icon: icon,
                iconIsTintable: tintable,
                action: action,
                relevance: item.relevance,
            )
        }

        guard query == cachedQuery else { return }
        cachedResults = results
        onResultsUpdated?()
    }

    private func resolveIcon(_ item: PluginResultItem) -> NSImage? {
        if let systemName = item.iconSystemName {
            return NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
        }

        if let base64 = item.iconBase64,
           let data = Data(base64Encoded: base64),
           let image = NSImage(data: data)
        {
            return image
        }

        if let path = item.iconPath {
            return NSImage(contentsOfFile: path)
        }

        return NSImage(systemSymbolName: "puzzlepiece.extension", accessibilityDescription: nil)
    }

    func shutdown() {
        Task {
            await process.shutdown()
        }
    }
}
