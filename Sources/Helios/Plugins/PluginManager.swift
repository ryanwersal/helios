import Foundation

@MainActor
final class PluginManager {
    private(set) var providers: [PluginProvider] = []

    private let pluginsDirectory: URL
    private let isPluginDisabled: (String) -> Bool

    init(pluginsDirectory: URL? = nil, isPluginDisabled: @escaping (String) -> Bool = { _ in false }) {
        self.pluginsDirectory = pluginsDirectory ?? Self.defaultPluginsDirectory
        self.isPluginDisabled = isPluginDisabled
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

        // In debug builds, load plugins from the source tree using executables from the build
        // directory. This allows `swift run` to pick up plugins without a full `mise run build`.
        #if DEBUG
            if let devDir = Self.devPluginsDirectory, let buildDir = Self.debugBuildDirectory {
                await loadPlugins(from: devDir) { pluginDir in
                    buildDir.appendingPathComponent(pluginDir.lastPathComponent)
                }
            }
        #endif

        await loadPlugins(from: pluginsDirectory)
    }

    #if DEBUG
        /// The source `Plugins/` directory adjacent to the Swift package root.
        private static var devPluginsDirectory: URL? {
            // Bundle.main.executableURL for `swift run` is inside `.build/debug/`.
            // Walk up to find the package root that contains a `Plugins` directory.
            guard let execURL = Bundle.main.executableURL else { return nil }
            var dir = execURL.deletingLastPathComponent()
            for _ in 0 ..< 5 {
                let candidate = dir.appendingPathComponent("Plugins")
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
                dir = dir.deletingLastPathComponent()
            }
            return nil
        }

        /// The `.build/debug` directory where `swift build` places plugin executables.
        private static var debugBuildDirectory: URL? {
            guard let execURL = Bundle.main.executableURL else { return nil }
            let dir = execURL.deletingLastPathComponent()
            guard dir.lastPathComponent == "debug" else { return nil }
            return dir
        }
    #endif

    /// Loads plugins from a directory. By default, expects each subdirectory to contain a `plugin`
    /// executable. Pass `resolveExecutable` to override how the executable URL is determined.
    private func loadPlugins(
        from directory: URL,
        resolveExecutable: ((URL) -> URL)? = nil,
    ) async {
        let candidates = discoverPlugins(in: directory, resolveExecutable: resolveExecutable)
        guard !candidates.isEmpty else { return }

        let launched = await launchPlugins(candidates)
        registerProviders(launched)
    }

    private func discoverPlugins(
        in directory: URL,
        resolveExecutable: ((URL) -> URL)?,
    ) -> [(manifest: PluginManifest, executableURL: URL)] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return [] }

        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
            )
        } catch {
            NSLog("[Helios] Failed to scan plugins directory: %@", error.localizedDescription)
            return []
        }

        var candidates: [(manifest: PluginManifest, executableURL: URL)] = []
        for entry in entries {
            guard isDirectory(entry) else { continue }

            let manifestURL = entry.appendingPathComponent("manifest.yaml")
            let executableURL = resolveExecutable?(entry) ?? entry.appendingPathComponent("plugin")

            guard fileManager.fileExists(atPath: manifestURL.path),
                  fileManager.fileExists(atPath: executableURL.path),
                  fileManager.isExecutableFile(atPath: executableURL.path)
            else { continue }

            do {
                let manifest = try PluginManifest.load(from: manifestURL)

                if providers.contains(where: { $0.manifest.name == manifest.name }) {
                    NSLog("[Helios] Skipping duplicate plugin: %@", manifest.name)
                    continue
                }

                if isPluginDisabled(manifest.name) {
                    NSLog("[Helios] Skipping disabled plugin: %@", manifest.name)
                    continue
                }

                candidates.append((manifest, executableURL))
            } catch {
                NSLog(
                    "[Helios] Failed to load plugin '%@': %@",
                    entry.lastPathComponent,
                    error.localizedDescription,
                )
            }
        }
        return candidates
    }

    /// Launch all plugin processes concurrently so slow initializers don't block the rest.
    private func launchPlugins(
        _ candidates: [(manifest: PluginManifest, executableURL: URL)],
    ) async -> [(PluginManifest, PluginProcess)] {
        await withTaskGroup(of: (PluginManifest, PluginProcess)?.self) { group in
            for (manifest, executableURL) in candidates {
                group.addTask {
                    let process = PluginProcess(name: manifest.name, executableURL: executableURL)
                    do {
                        try await process.launch()
                        return (manifest, process)
                    } catch {
                        NSLog(
                            "[Helios] Failed to launch plugin '%@': %@",
                            manifest.name,
                            error.localizedDescription,
                        )
                        return nil
                    }
                }
            }

            var results: [(PluginManifest, PluginProcess)] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results
        }
    }

    private func registerProviders(_ launched: [(PluginManifest, PluginProcess)]) {
        for (manifest, process) in launched {
            guard !providers.contains(where: { $0.manifest.name == manifest.name }) else {
                NSLog("[Helios] Skipping duplicate plugin: %@", manifest.name)
                continue
            }

            let provider = PluginProvider(manifest: manifest, process: process)
            providers.append(provider)
            NSLog("[Helios] Loaded plugin: %@", manifest.name)
        }
    }

    /// Returns manifests for all discovered plugins, regardless of disabled state.
    /// Used by the settings UI to show all available plugins with toggle state.
    func discoverAllManifests() -> [PluginManifest] {
        var manifests: [PluginManifest] = []
        var seen = Set<String>()

        func scan(directory: URL, resolveExecutable: ((URL) -> URL)? = nil) {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: directory.path) else { return }

            let entries: [URL]
            do {
                entries = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey],
                )
            } catch { return }

            for entry in entries {
                guard isDirectory(entry) else { continue }
                let manifestURL = entry.appendingPathComponent("manifest.yaml")
                let executableURL = resolveExecutable?(entry) ?? entry.appendingPathComponent("plugin")
                guard fileManager.fileExists(atPath: manifestURL.path),
                      fileManager.fileExists(atPath: executableURL.path),
                      fileManager.isExecutableFile(atPath: executableURL.path)
                else { continue }

                if let manifest = try? PluginManifest.load(from: manifestURL),
                   !seen.contains(manifest.name)
                {
                    seen.insert(manifest.name)
                    manifests.append(manifest)
                }
            }
        }

        if let bundledDir = Self.bundledPluginsDirectory {
            scan(directory: bundledDir)
        }

        #if DEBUG
            if let devDir = Self.devPluginsDirectory, let buildDir = Self.debugBuildDirectory {
                scan(directory: devDir) { pluginDir in
                    buildDir.appendingPathComponent(pluginDir.lastPathComponent)
                }
            }
        #endif

        scan(directory: pluginsDirectory)
        return manifests
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
