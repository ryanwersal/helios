import AppKit

struct AppInfo {
    let name: String
    let nameLowercased: String
    let url: URL
    let icon: NSImage

    init(name: String, url: URL, icon: NSImage) {
        self.name = name
        nameLowercased = name.lowercased()
        self.url = url
        self.icon = icon
    }
}

@MainActor
final class AppLauncherProvider: SearchProvider {
    private var apps: [AppInfo] = []

    init() {
        Task {
            await refreshInBackground()
        }
    }

    func canHandle(query _: String) -> Bool {
        true
    }

    func search(query: String) async -> [SearchResult] {
        let loweredQuery = query.lowercased()
        let terms = loweredQuery.split(separator: " ")
        guard !terms.isEmpty else { return [] }

        return apps.compactMap { app in
            let allMatch = terms.allSatisfy { app.nameLowercased.contains($0) }
            guard allMatch else { return nil }

            var score: Double = 0

            if app.nameLowercased.hasPrefix(String(terms[0])) {
                score += 500
            }

            if app.nameLowercased == loweredQuery {
                score += 1000
            }

            score += max(0, 100 - Double(app.name.count))

            for term in terms where app.nameLowercased.contains(term) {
                score += 50
            }

            return SearchResult(
                title: app.name,
                subtitle: app.url.path,
                icon: app.icon,
                iconIsTintable: false,
                action: .openURL(app.url),
                relevance: score,
            )
        }
    }

    // MARK: - Scanning

    private func refreshInBackground() async {
        let scanned = await Task.detached {
            Self.scanApps()
        }.value
        apps = scanned
    }

    private nonisolated static func scanApps() -> [AppInfo] {
        var found: [URL: AppInfo] = [:]

        let searchDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]

        for dir in searchDirs {
            scanDirectory(dir, into: &found, depth: 0)
        }

        return Array(found.values).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Pre-renders an app icon to a fixed-size bitmap so it displays instantly
    /// without lazy decoding or rescaling at draw time.
    private nonisolated static func prerenderIcon(_ source: NSImage) -> NSImage {
        let pointSize: CGFloat = 28
        let targetSize = NSSize(width: pointSize, height: pointSize)
        guard let copy = source.copy() as? NSImage else { return source }
        copy.size = targetSize
        guard let cgImage = copy.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return copy
        }
        return NSImage(cgImage: cgImage, size: targetSize)
    }

    private nonisolated static func scanDirectory(_ dir: URL, into found: inout [URL: AppInfo], depth: Int) {
        guard depth < 3 else { return }

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles],
        ) else { return }

        for entry in entries {
            if entry.pathExtension == "app" {
                if found[entry] == nil {
                    let name = entry.deletingPathExtension().lastPathComponent
                    let icon = prerenderIcon(NSWorkspace.shared.icon(forFile: entry.path))
                    found[entry] = AppInfo(name: name, url: entry, icon: icon)
                }
            } else if (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                scanDirectory(entry, into: &found, depth: depth + 1)
            }
        }
    }
}
