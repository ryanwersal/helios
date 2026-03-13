import Foundation
import HeliosPluginProtocol

// MARK: - Safari Bookmark Data

struct SafariBookmark {
    let title: String
    let url: String
    let titleLowercased: String
    let urlLowercased: String

    init(title: String, url: String) {
        self.title = title
        self.url = url
        titleLowercased = title.lowercased()
        urlLowercased = url.lowercased()
    }
}

// MARK: - Safari Bookmark Loading

func safariBookmarksPath() -> URL? {
    let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Safari/Bookmarks.plist")
    return FileManager.default.fileExists(atPath: path.path) ? path : nil
}

func loadSafariBookmarks() -> [SafariBookmark] {
    guard let bookmarksPath = safariBookmarksPath() else { return [] }

    do {
        let data = try Data(contentsOf: bookmarksPath)
        guard let plist = try PropertyListSerialization.propertyList(
            from: data, options: [], format: nil,
        ) as? [String: Any] else { return [] }

        var bookmarks: [SafariBookmark] = []
        flattenBookmarkTree(node: plist, into: &bookmarks)
        return bookmarks
    } catch {
        log("Failed to load Safari bookmarks: \(error.localizedDescription)")
        return []
    }
}

func flattenBookmarkTree(node: [String: Any], into bookmarks: inout [SafariBookmark]) {
    let nodeType = node["WebBookmarkType"] as? String

    // Skip proxy nodes (History, Reading List, etc.)
    if nodeType == "WebBookmarkTypeProxy" {
        return
    }

    if nodeType == "WebBookmarkTypeLeaf",
       let url = node["URLString"] as? String
    {
        let title: String = if let uriDict = node["URIDictionary"] as? [String: Any],
                               let uriTitle = uriDict["title"] as? String
        {
            uriTitle
        } else {
            url
        }
        bookmarks.append(SafariBookmark(title: title, url: url))
    }

    if let children = node["Children"] as? [[String: Any]] {
        for child in children {
            flattenBookmarkTree(node: child, into: &bookmarks)
        }
    }
}

// MARK: - Search

func searchBookmarks(query: String, in bookmarks: [SafariBookmark]) -> [PluginResultItem] {
    let terms = query.lowercased().split(separator: " ")
    guard !terms.isEmpty else { return [] }

    return bookmarks.compactMap { bookmark in
        let haystack = bookmark.titleLowercased + " " + bookmark.urlLowercased

        let allMatch = terms.allSatisfy { haystack.contains($0) }
        guard allMatch else { return nil }

        var score: Double = 0
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
            iconSystemName: "book",
            iconPath: nil,
            iconBase64: nil,
            iconTintable: true,
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
    FileHandle.standardError.write(Data("[safari-bookmarks] \(message)\n".utf8))
}

// MARK: - Main Loop

nonisolated(unsafe) var bookmarks: [SafariBookmark] = []
nonisolated(unsafe) var lastRefresh: Date = .distantPast
let refreshInterval: TimeInterval = 60

func refreshIfNeeded() {
    let now = Date()
    if now.timeIntervalSince(lastRefresh) >= refreshInterval {
        bookmarks = loadSafariBookmarks()
        lastRefresh = now
        log("Loaded \(bookmarks.count) bookmarks")
    }
}

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
