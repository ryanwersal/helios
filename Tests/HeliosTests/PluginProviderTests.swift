import Foundation
@testable import Helios
import Testing

@MainActor
struct PluginProviderTests {
    // MARK: - canHandle

    @Test
    func `canHandle returns true without keyword`() {
        let manifest = PluginManifest(
            name: "Test",
            version: "1.0",
            description: "test",
            keyword: nil,
        )
        let process = PluginProcess(name: "test", executableURL: URL(fileURLWithPath: "/dev/null"))
        let provider = PluginProvider(manifest: manifest, process: process)
        #expect(provider.canHandle(query: "anything"))
    }

    @Test
    func `canHandle requires keyword prefix`() {
        let manifest = PluginManifest(
            name: "Test",
            version: "1.0",
            description: "test",
            keyword: "ff",
        )
        let process = PluginProcess(name: "test", executableURL: URL(fileURLWithPath: "/dev/null"))
        let provider = PluginProvider(manifest: manifest, process: process)
        #expect(provider.canHandle(query: "ff bookmarks"))
        #expect(provider.canHandle(query: "ff"))
        #expect(!provider.canHandle(query: "google bookmarks"))
        #expect(!provider.canHandle(query: "ffoo"))
    }

    // MARK: - search returns cached results

    @Test
    func `search returns empty when no cache`() {
        let manifest = PluginManifest(
            name: "Test",
            version: "1.0",
            description: "test",
        )
        let process = PluginProcess(name: "test", executableURL: URL(fileURLWithPath: "/dev/null"))
        let provider = PluginProvider(manifest: manifest, process: process)
        let results = provider.search(query: "hello")
        #expect(results.isEmpty)
    }

    // MARK: - Badge icon

    @Test
    func `badgeImage is populated for app path icon`() {
        let manifest = PluginManifest(
            name: "Test",
            version: "1.0",
            description: "test",
            icon: "/System/Applications/Safari.app",
        )
        let process = PluginProcess(name: "test", executableURL: URL(fileURLWithPath: "/dev/null"))
        let provider = PluginProvider(manifest: manifest, process: process)
        #expect(provider.badgeImage != nil)
    }

    @Test
    func `badgeImage is nil without icon`() {
        let manifest = PluginManifest(
            name: "Test",
            version: "1.0",
            description: "test",
        )
        let process = PluginProcess(name: "test", executableURL: URL(fileURLWithPath: "/dev/null"))
        let provider = PluginProvider(manifest: manifest, process: process)
        #expect(provider.badgeImage == nil)
    }

    @Test
    func `badgeImage resolves SF Symbol`() {
        let manifest = PluginManifest(
            name: "Test",
            version: "1.0",
            description: "test",
            icon: "star.fill",
        )
        let process = PluginProcess(name: "test", executableURL: URL(fileURLWithPath: "/dev/null"))
        let provider = PluginProvider(manifest: manifest, process: process)
        #expect(provider.badgeImage != nil)
    }
}
