import Foundation

@MainActor
final class PluginManager {
    private(set) var providers: [PluginProvider] = []
    var onResultsUpdated: (() -> Void)?

    private let pluginsDirectory: URL

    init(pluginsDirectory: URL? = nil) {
        self.pluginsDirectory = pluginsDirectory ?? Self.defaultPluginsDirectory
    }

    private static var defaultPluginsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/helios/plugins")
    }

    private static var bundledPluginsDirectory: URL? {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Plugins")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
              isDir.boolValue
        else { return nil }
        return url
    }

    func loadPlugins() async {
        // Bundled plugins load first and take precedence over user plugins with the same name.
        if let bundledDir = Self.bundledPluginsDirectory {
            await loadPlugins(from: bundledDir)
        }
        await loadPlugins(from: pluginsDirectory)
    }

    private func loadPlugins(from directory: URL) async {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return }

        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
            )
        } catch {
            NSLog("[Helios] Failed to scan plugins directory: %@", error.localizedDescription)
            return
        }

        let loadedNames = Set(providers.map(\.manifest.name))

        for entry in entries {
            guard isDirectory(entry) else { continue }

            let manifestURL = entry.appendingPathComponent("manifest.yaml")
            let executableURL = entry.appendingPathComponent("plugin")

            guard fileManager.fileExists(atPath: manifestURL.path),
                  fileManager.fileExists(atPath: executableURL.path),
                  fileManager.isExecutableFile(atPath: executableURL.path)
            else { continue }

            do {
                let manifest = try PluginManifest.load(from: manifestURL)

                if loadedNames.contains(manifest.name) {
                    NSLog("[Helios] Skipping duplicate plugin: %@", manifest.name)
                    continue
                }

                let process = PluginProcess(name: manifest.name, executableURL: executableURL)
                try await process.launch()

                let provider = PluginProvider(manifest: manifest, process: process)
                provider.onResultsUpdated = { [weak self] in
                    self?.onResultsUpdated?()
                }
                providers.append(provider)
                NSLog("[Helios] Loaded plugin: %@", manifest.name)
            } catch {
                NSLog(
                    "[Helios] Failed to load plugin '%@': %@",
                    entry.lastPathComponent,
                    error.localizedDescription,
                )
            }
        }
    }

    func reloadPlugins() async {
        shutdownAll()
        providers.removeAll()
        await loadPlugins()
    }

    func shutdownAll() {
        for provider in providers {
            provider.shutdown()
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
