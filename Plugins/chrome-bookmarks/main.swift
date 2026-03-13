import Foundation
import HeliosPluginProtocol

// MARK: - Chrome Bookmark Data

struct ChromeBookmark {
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

// MARK: - Chrome Bookmark Loading

func chromeBookmarksPath() -> URL? {
    let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Google/Chrome/Default/Bookmarks")
    return FileManager.default.fileExists(atPath: path.path) ? path : nil
}

func loadChromeBookmarks() -> [ChromeBookmark] {
    guard let bookmarksPath = chromeBookmarksPath() else { return [] }

    do {
        let data = try Data(contentsOf: bookmarksPath)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let roots = json["roots"] as? [String: Any]
        else { return [] }

        var bookmarks: [ChromeBookmark] = []
        for (_, value) in roots {
            if let node = value as? [String: Any] {
                flattenBookmarkTree(node: node, into: &bookmarks)
            }
        }
        return bookmarks
    } catch {
        log("Failed to load Chrome bookmarks: \(error.localizedDescription)")
        return []
    }
}

func flattenBookmarkTree(node: [String: Any], into bookmarks: inout [ChromeBookmark]) {
    let nodeType = node["type"] as? String

    if nodeType == "url",
       let title = node["name"] as? String,
       let url = node["url"] as? String
    {
        bookmarks.append(ChromeBookmark(title: title, url: url))
    }

    if nodeType == "folder",
       let children = node["children"] as? [[String: Any]]
    {
        for child in children {
            flattenBookmarkTree(node: child, into: &bookmarks)
        }
    }
}

// MARK: - Search

func searchBookmarks(query: String, in bookmarks: [ChromeBookmark]) -> [PluginResultItem] {
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
    FileHandle.standardError.write(Data("[chrome-bookmarks] \(message)\n".utf8))
}

// MARK: - Main Loop

nonisolated(unsafe) var bookmarks: [ChromeBookmark] = []
nonisolated(unsafe) var lastRefresh: Date = .distantPast
let refreshInterval: TimeInterval = 60

func refreshIfNeeded() {
    let now = Date()
    if now.timeIntervalSince(lastRefresh) >= refreshInterval {
        bookmarks = loadChromeBookmarks()
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
