import AppKit

@MainActor
final class PluginProvider: SearchProvider {
    let manifest: PluginManifest
    private let process: PluginProcess

    private(set) lazy var badgeImage: NSImage? = resolveBadgeIcon()

    init(manifest: PluginManifest, process: PluginProcess) {
        self.manifest = manifest
        self.process = process
    }

    private func resolveBadgeIcon() -> NSImage? {
        guard let iconSpec = manifest.icon else { return nil }
        if iconSpec.hasPrefix("/") {
            let source = NSWorkspace.shared.icon(forFile: iconSpec)
            return Self.prerenderBadgeIcon(source)
        }
        return NSImage(systemSymbolName: iconSpec, accessibilityDescription: nil)
    }

    private static func prerenderBadgeIcon(_ source: NSImage) -> NSImage {
        let pointSize: CGFloat = 14
        let targetSize = NSSize(width: pointSize, height: pointSize)
        guard let copy = source.copy() as? NSImage else { return source }
        copy.size = targetSize
        guard let cgImage = copy.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return copy
        }
        return NSImage(cgImage: cgImage, size: targetSize)
    }

    func canHandle(query: String) -> Bool {
        if let keyword = manifest.keyword {
            return query.lowercased().hasPrefix(keyword + " ") || query.lowercased() == keyword
        }
        return true
    }

    func search(query: String) async -> [SearchResult] {
        let id = UUID().uuidString
        do {
            let response = try await process.search(query: query, id: id)
            return mapResponse(response)
        } catch {
            if !(error is CancellationError), (error as? PluginError) != .searchTimeout {
                NSLog(
                    "[Helios] Plugin '%@' search failed: %@",
                    manifest.name,
                    error.localizedDescription,
                )
            }
            return []
        }
    }

    private func mapResponse(_ response: PluginResponse) -> [SearchResult] {
        guard let items = response.results else { return [] }

        return items.map { item -> SearchResult in
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
                badgeIcon: badgeImage,
                action: action,
                relevance: item.relevance,
            )
        }
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
