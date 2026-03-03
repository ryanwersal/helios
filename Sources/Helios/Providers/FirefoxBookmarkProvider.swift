import AppKit
import Foundation
import GRDB

struct Bookmark {
    let title: String
    let url: String
    let frecency: Int
    let titleLowercased: String
    let urlLowercased: String

    init(title: String, url: String, frecency: Int) {
        self.title = title
        self.url = url
        self.frecency = frecency
        self.titleLowercased = title.lowercased()
        self.urlLowercased = url.lowercased()
    }
}

@MainActor
final class FirefoxBookmarkProvider: SearchProvider {
    private var bookmarks: [Bookmark] = []
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 60

    init() {
        startTimer()
        Task {
            await refreshInBackground()
        }
    }

    func canHandle(query: String) -> Bool {
        true
    }

    func search(query: String) -> [SearchResult] {
        let terms = query.lowercased().split(separator: " ")
        guard !terms.isEmpty else { return [] }

        return bookmarks.compactMap { bookmark in
            let haystack = bookmark.titleLowercased + " " + bookmark.urlLowercased

            let allMatch = terms.allSatisfy { haystack.contains($0) }
            guard allMatch else { return nil }

            guard let url = URL(string: bookmark.url) else { return nil }

            var score = Double(bookmark.frecency)
            for term in terms {
                if bookmark.titleLowercased.contains(term) {
                    score += 100
                }
                if bookmark.titleLowercased.hasPrefix(String(term)) {
                    score += 200
                }
            }

            let icon = NSImage(systemSymbolName: "book", accessibilityDescription: "Bookmark")

            return SearchResult(
                title: bookmark.title,
                subtitle: bookmark.url,
                icon: icon,
                action: .openURL(url),
                relevance: score
            )
        }
    }

    // MARK: - Background Refresh

    private func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                await self?.refreshInBackground()
            }
        }
    }

    private func refreshInBackground() async {
        let loaded = await Task.detached {
            Self.loadBookmarks()
        }.value
        bookmarks = loaded
    }

    private nonisolated static func loadBookmarks() -> [Bookmark] {
        guard let sourcePath = FirefoxProfileLocator.placesDatabase() else { return [] }
        let sourceDir = sourcePath.deletingLastPathComponent()

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("helios-firefox-\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            for ext in ["", "-wal", "-shm"] {
                let src = sourceDir.appendingPathComponent("places.sqlite\(ext)")
                let dst = tempDir.appendingPathComponent("places.sqlite\(ext)")
                if FileManager.default.fileExists(atPath: src.path) {
                    try FileManager.default.copyItem(at: src, to: dst)
                }
            }

            let dbPath = tempDir.appendingPathComponent("places.sqlite").path
            let config = Configuration()
            let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

            let rows = try dbQueue.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT b.title, p.url, p.frecency
                    FROM moz_bookmarks b
                    JOIN moz_places p ON b.fk = p.id
                    WHERE b.type = 1 AND b.title IS NOT NULL
                    ORDER BY p.frecency DESC
                """)
            }

            return rows.compactMap { row in
                guard let title = row["title"] as? String,
                      let url = row["url"] as? String
                else { return nil }
                let frecency = (row["frecency"] as? Int) ?? 0
                return Bookmark(title: title, url: url, frecency: frecency)
            }
        } catch {
            NSLog("[Helios] Firefox bookmark refresh failed: %@", error.localizedDescription)
            return []
        }
    }
}
