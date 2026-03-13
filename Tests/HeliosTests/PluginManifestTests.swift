@testable import Helios
import Testing
import Yams

struct PluginManifestTests {
    @Test
    func `parses complete manifest`() throws {
        let yaml = """
        name: Firefox Bookmarks
        version: "1.0"
        description: Search Firefox bookmarks
        mode: long-running
        keyword: ff
        """
        let manifest = try YAMLDecoder().decode(PluginManifest.self, from: yaml)
        #expect(manifest.name == "Firefox Bookmarks")
        #expect(manifest.version == "1.0")
        #expect(manifest.description == "Search Firefox bookmarks")
        #expect(manifest.mode == .longRunning)
        #expect(manifest.keyword == "ff")
    }

    @Test
    func `parses per query mode`() throws {
        let yaml = """
        name: Test Plugin
        version: "0.1"
        description: A test
        mode: per-query
        """
        let manifest = try YAMLDecoder().decode(PluginManifest.self, from: yaml)
        #expect(manifest.mode == .perQuery)
    }

    @Test
    func `keyword is optional`() throws {
        let yaml = """
        name: Test Plugin
        version: "0.1"
        description: A test
        mode: long-running
        """
        let manifest = try YAMLDecoder().decode(PluginManifest.self, from: yaml)
        #expect(manifest.keyword == nil)
    }

    @Test
    func `missing required field throws`() {
        let yaml = """
        name: Test Plugin
        version: "0.1"
        """
        #expect(throws: Error.self) {
            _ = try YAMLDecoder().decode(PluginManifest.self, from: yaml)
        }
    }

    @Test
    func `init sets defaults`() {
        let manifest = PluginManifest(
            name: "Test",
            version: "1.0",
            description: "desc",
        )
        #expect(manifest.mode == .longRunning)
        #expect(manifest.keyword == nil)
    }
}
