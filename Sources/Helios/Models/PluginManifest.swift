import Foundation
import Yams

struct PluginManifest: Codable {
    let name: String
    let version: String
    let description: String
    let mode: PluginMode
    let keyword: String?
    let icon: String?

    enum PluginMode: String, Codable {
        case longRunning = "long-running"
        case perQuery = "per-query"
    }

    init(
        name: String,
        version: String,
        description: String,
        mode: PluginMode = .longRunning,
        keyword: String? = nil,
        icon: String? = nil,
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.mode = mode
        self.keyword = keyword
        self.icon = icon
    }

    static func load(from url: URL) throws -> PluginManifest {
        let data = try Data(contentsOf: url)
        let yaml = String(data: data, encoding: .utf8) ?? ""
        return try YAMLDecoder().decode(PluginManifest.self, from: yaml)
    }
}
