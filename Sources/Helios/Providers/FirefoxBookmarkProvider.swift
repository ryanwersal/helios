import AppKit
import Foundation
import GRDB

struct Bookmark {
    let title: String
    let url: String
    let frecency: Int
    let icon: NSImage?
    let titleLowercased: String
    let urlLowercased: String

    init(title: String, url: String, frecency: Int, icon: NSImage? = nil) {
        self.title = title
        self.url = url
        self.frecency = frecency
        self.icon = icon
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

            let icon = bookmark.icon
                ?? NSImage(systemSymbolName: "book", accessibilityDescription: "Bookmark")
            let tintable = bookmark.icon == nil

            return SearchResult(
                title: bookmark.title,
                subtitle: bookmark.url,
                icon: icon,
                iconIsTintable: tintable,
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

            try copySQLiteDatabase(named: "places.sqlite", from: sourceDir, to: tempDir)

            let favicons = loadFavicons(sourceDir: sourceDir, tempDir: tempDir)

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

                var icon: NSImage?
                if let match = favicons[url] {
                    icon = match
                } else if let parsed = URL(string: url), let host = parsed.host {
                    icon = favicons["host:\(host)"]
                }

                return Bookmark(title: title, url: url, frecency: frecency, icon: icon)
            }
        } catch {
            NSLog("[Helios] Firefox bookmark refresh failed: %@", error.localizedDescription)
            return []
        }
    }

    // MARK: - Favicons

    private nonisolated static func loadFavicons(
        sourceDir: URL, tempDir: URL
    ) -> [String: NSImage] {
        let faviconsSource = sourceDir.appendingPathComponent("favicons.sqlite")
        guard FileManager.default.fileExists(atPath: faviconsSource.path) else { return [:] }

        do {
            try copySQLiteDatabase(named: "favicons.sqlite", from: sourceDir, to: tempDir)

            let dbPath = tempDir.appendingPathComponent("favicons.sqlite").path
            let config = Configuration()
            let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

            let rows = try dbQueue.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT p.page_url, i.data, i.width
                    FROM moz_pages_w_icons p
                    JOIN moz_icons_to_pages ip ON ip.page_id = p.id
                    JOIN moz_icons i ON i.id = ip.icon_id
                    WHERE i.data IS NOT NULL AND length(i.data) > 0
                    ORDER BY i.width DESC
                """)
            }

            var result: [String: NSImage] = [:]
            for row in rows {
                guard let pageURL = row["page_url"] as? String,
                      let data = row["data"] as? Data,
                      let image = NSImage(data: data)
                else { continue }

                let rendered = prerenderIcon(image)

                // Keep largest icon per URL (rows ordered by width DESC, first write wins)
                if result[pageURL] == nil {
                    result[pageURL] = rendered
                }

                // Host-based fallback
                if let parsed = URL(string: pageURL), let host = parsed.host {
                    let hostKey = "host:\(host)"
                    if result[hostKey] == nil {
                        result[hostKey] = rendered
                    }
                }
            }

            return result
        } catch {
            NSLog("[Helios] Firefox favicon load failed: %@", error.localizedDescription)
            return [:]
        }
    }

    /// Copies a SQLite database and its WAL/SHM files from one directory to another.
    private nonisolated static func copySQLiteDatabase(
        named name: String, from sourceDir: URL, to destDir: URL
    ) throws {
        for ext in ["", "-wal", "-shm"] {
            let src = sourceDir.appendingPathComponent("\(name)\(ext)")
            let dst = destDir.appendingPathComponent("\(name)\(ext)")
            if FileManager.default.fileExists(atPath: src.path) {
                try FileManager.default.copyItem(at: src, to: dst)
            }
        }
    }

    /// Pre-renders a favicon to a fixed-size bitmap for instant display.
    private nonisolated static func prerenderIcon(_ source: NSImage) -> NSImage {
        let pointSize: CGFloat = 28
        let targetSize = NSSize(width: pointSize, height: pointSize)
        let copy = source.copy() as! NSImage
        copy.size = targetSize
        guard let cgImage = copy.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return copy
        }
        return NSImage(cgImage: cgImage, size: targetSize)
    }
}
