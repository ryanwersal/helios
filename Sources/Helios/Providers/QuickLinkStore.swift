import Foundation
import Yams

@MainActor
final class QuickLinkStore {
    private(set) var quicklinks: [QuickLink] = []

    let configURL: URL

    init(configURL: URL? = nil) {
        self.configURL = configURL ?? Self.defaultConfigURL
    }

    private static var defaultConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/helios/quicklinks.yaml")
    }

    func reload() {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            quicklinks = []
            return
        }

        do {
            let data = try Data(contentsOf: configURL)
            let yaml = String(data: data, encoding: .utf8) ?? ""
            let config = try YAMLDecoder().decode(QuickLinksConfig.self, from: yaml)
            quicklinks = config.quicklinks
        } catch {
            quicklinks = []
        }
    }

    func add(_ quicklink: QuickLink) {
        quicklinks.append(quicklink)
        save()
    }

    func replace(at index: Int, with quicklink: QuickLink) {
        guard quicklinks.indices.contains(index) else { return }
        quicklinks[index] = quicklink
        save()
    }

    func remove(at index: Int) {
        guard quicklinks.indices.contains(index) else { return }
        quicklinks.remove(at: index)
        save()
    }

    private func save() {
        let config = QuickLinksConfig(quicklinks: quicklinks)
        do {
            let yaml = try YAMLEncoder().encode(config)
            let dir = configURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try yaml.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            // Save failed silently — config will be stale until next successful save
        }
    }
}
