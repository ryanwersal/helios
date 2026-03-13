import Foundation
import GRDB
import HeliosPluginProtocol

// MARK: - Firefox Profile Locator

enum FirefoxProfileLocator {
    static let firefoxSupportDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Firefox")

    static func defaultProfilePath() -> URL? {
        let profilesIni = firefoxSupportDir.appendingPathComponent("profiles.ini")
        guard let contents = try? String(contentsOf: profilesIni, encoding: .utf8) else {
            return nil
        }
        return parseDefaultProfile(from: contents, supportDir: firefoxSupportDir)
            ?? fallbackProfilePath()
    }

    static func parseDefaultProfile(from contents: String, supportDir: URL) -> URL? {
        var installDefault: String?
        var profileDefault: URL?

        var currentPath: String?
        var currentIsRelative = true
        var foundDefault = false
        var inInstallSection = false

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") {
                if !inInstallSection, foundDefault, let path = currentPath, profileDefault == nil {
                    profileDefault = resolvedProfileURL(
                        path: path, isRelative: currentIsRelative, supportDir: supportDir,
                    )
                }
                inInstallSection = trimmed.hasPrefix("[Install")
                currentPath = nil
                currentIsRelative = true
                foundDefault = false
            } else if inInstallSection, trimmed.hasPrefix("Default="), installDefault == nil {
                installDefault = String(trimmed.dropFirst("Default=".count))
            } else if trimmed.hasPrefix("Path=") {
                currentPath = String(trimmed.dropFirst("Path=".count))
            } else if trimmed.hasPrefix("IsRelative=") {
                currentIsRelative = String(trimmed.dropFirst("IsRelative=".count)) == "1"
            } else if trimmed == "Default=1" {
                foundDefault = true
            }
        }

        if !inInstallSection, foundDefault, let path = currentPath, profileDefault == nil {
            profileDefault = resolvedProfileURL(
                path: path, isRelative: currentIsRelative, supportDir: supportDir,
            )
        }

        if let installPath = installDefault {
            return supportDir.appendingPathComponent(installPath)
        }
        return profileDefault
    }

    static func placesDatabase() -> URL? {
        guard let profile = defaultProfilePath() else { return nil }
        let places = profile.appendingPathComponent("places.sqlite")
        return FileManager.default.fileExists(atPath: places.path) ? places : nil
    }

    private static func resolvedProfileURL(path: String, isRelative: Bool, supportDir: URL) -> URL {
        if isRelative {
            supportDir.appendingPathComponent(path)
        } else {
            URL(fileURLWithPath: path)
        }
    }

    private static func fallbackProfilePath() -> URL? {
        let profilesDir = firefoxSupportDir.appendingPathComponent("Profiles")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: profilesDir, includingPropertiesForKeys: nil,
        ) else {
            return nil
        }
        return entries.first { $0.lastPathComponent.hasSuffix(".default-release") }
            ?? entries.first { $0.lastPathComponent.hasSuffix(".default") }
            ?? entries.first
    }
}

// MARK: - Bookmark Data

struct Bookmark {
    let title: String
    let url: String
    let frecency: Int
    let faviconBase64: String?
    let titleLowercased: String
    let urlLowercased: String

    init(title: String, url: String, frecency: Int, faviconBase64: String? = nil) {
        self.title = title
        self.url = url
        self.frecency = frecency
        self.faviconBase64 = faviconBase64
        titleLowercased = title.lowercased()
        urlLowercased = url.lowercased()
    }
}

// MARK: - Bookmark Loading

func loadBookmarks() -> [Bookmark] {
    guard let sourcePath = FirefoxProfileLocator.placesDatabase() else { return [] }
    let sourceDir = sourcePath.deletingLastPathComponent()

    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("helios-firefox-plugin-\(UUID().uuidString)")

    do {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try copySQLiteDatabase(named: "places.sqlite", from: sourceDir, to: tempDir)

        let favicons = loadFavicons(sourceDir: sourceDir, tempDir: tempDir)

        let dbPath = tempDir.appendingPathComponent("places.sqlite").path
        let config = Configuration()
        let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

        let rows = try dbQueue.read { database in
            try Row.fetchAll(database, sql: """
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

            var faviconBase64: String?
            if let match = favicons[url] {
                faviconBase64 = match
            } else if let parsed = URL(string: url), let host = parsed.host {
                faviconBase64 = favicons["host:\(host)"]
            }

            return Bookmark(title: title, url: url, frecency: frecency, faviconBase64: faviconBase64)
        }
    } catch {
        log("Bookmark refresh failed: \(error.localizedDescription)")
        return []
    }
}

func loadFavicons(sourceDir: URL, tempDir: URL) -> [String: String] {
    let faviconsSource = sourceDir.appendingPathComponent("favicons.sqlite")
    guard FileManager.default.fileExists(atPath: faviconsSource.path) else { return [:] }

    do {
        try copySQLiteDatabase(named: "favicons.sqlite", from: sourceDir, to: tempDir)

        let dbPath = tempDir.appendingPathComponent("favicons.sqlite").path
        let config = Configuration()
        let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

        let rows = try dbQueue.read { database in
            try Row.fetchAll(database, sql: """
                SELECT p.page_url, i.data, i.width
                FROM moz_pages_w_icons p
                JOIN moz_icons_to_pages ip ON ip.page_id = p.id
                JOIN moz_icons i ON i.id = ip.icon_id
                WHERE i.data IS NOT NULL AND length(i.data) > 0
                ORDER BY i.width DESC
            """)
        }

        var result: [String: String] = [:]
        for row in rows {
            guard let pageURL = row["page_url"] as? String,
                  let data = row["data"] as? Data
            else { continue }

            let base64 = data.base64EncodedString()

            if result[pageURL] == nil {
                result[pageURL] = base64
            }

            if let parsed = URL(string: pageURL), let host = parsed.host {
                let hostKey = "host:\(host)"
                if result[hostKey] == nil {
                    result[hostKey] = base64
                }
            }
        }

        return result
    } catch {
        log("Favicon load failed: \(error.localizedDescription)")
        return [:]
    }
}

func copySQLiteDatabase(named name: String, from sourceDir: URL, to destDir: URL) throws {
    for ext in ["", "-wal", "-shm"] {
        let src = sourceDir.appendingPathComponent("\(name)\(ext)")
        let dst = destDir.appendingPathComponent("\(name)\(ext)")
        if FileManager.default.fileExists(atPath: src.path) {
            try FileManager.default.copyItem(at: src, to: dst)
        }
    }
}

// MARK: - Search

func searchBookmarks(query: String, in bookmarks: [Bookmark]) -> [PluginResultItem] {
    let terms = query.lowercased().split(separator: " ")
    guard !terms.isEmpty else { return [] }

    return bookmarks.compactMap { bookmark in
        let haystack = bookmark.titleLowercased + " " + bookmark.urlLowercased

        let allMatch = terms.allSatisfy { haystack.contains($0) }
        guard allMatch else { return nil }

        var score = Double(bookmark.frecency)
        for term in terms {
            if bookmark.titleLowercased.contains(term) {
                score += 100
            }
            if bookmark.titleLowercased.hasPrefix(String(term)) {
                score += 200
            }
        }

        return PluginResultItem(
            title: bookmark.title,
            subtitle: bookmark.url,
            relevance: score,
            action: PluginAction(type: .openURL, url: bookmark.url, text: nil),
            iconSystemName: bookmark.faviconBase64 == nil ? "book" : nil,
            iconPath: nil,
            iconBase64: bookmark.faviconBase64,
            iconTintable: bookmark.faviconBase64 == nil,
        )
    }
}

// MARK: - I/O

let encoder = JSONEncoder()
let decoder = JSONDecoder()

func sendResponse(_ response: PluginResponse) {
    guard var data = try? encoder.encode(response) else {
        log("Failed to encode response")
        return
    }
    data.append(contentsOf: [UInt8(ascii: "\n")])
    FileHandle.standardOutput.write(data)
}

func log(_ message: String) {
    FileHandle.standardError.write(Data("[firefox-bookmarks] \(message)\n".utf8))
}

// MARK: - Main Loop

nonisolated(unsafe) var bookmarks: [Bookmark] = []
nonisolated(unsafe) var lastRefresh: Date = .distantPast
let refreshInterval: TimeInterval = 60

func refreshIfNeeded() {
    let now = Date()
    if now.timeIntervalSince(lastRefresh) >= refreshInterval {
        bookmarks = loadBookmarks()
        lastRefresh = now
        log("Loaded \(bookmarks.count) bookmarks")
    }
}

// Read stdin line by line
while let line = readLine(strippingNewline: true) {
    guard !line.isEmpty,
          let data = line.data(using: .utf8),
          let request = try? decoder.decode(PluginRequest.self, from: data)
    else {
        continue
    }

    switch request.type {
    case .initialize:
        refreshIfNeeded()
        sendResponse(PluginResponse(type: .ready, id: nil, results: nil))

    case .search:
        guard let query = request.query, let requestId = request.id else { continue }
        refreshIfNeeded()
        let results = searchBookmarks(query: query, in: bookmarks)
        sendResponse(PluginResponse(type: .results, id: requestId, results: results))

    case .shutdown:
        exit(0)
    }
}
