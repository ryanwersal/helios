@testable import Helios
import Foundation
import Testing

@MainActor
struct QuickLinkStoreTests {
    private func makeTempConfigURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir.appendingPathComponent("quicklinks.yaml")
    }

    private func writeYAML(_ content: String, to url: URL) {
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test
    func `loads valid config`() {
        let url = makeTempConfigURL()
        writeYAML("""
        quicklinks:
          - keyword: sc
            name: Shortcut Story
            url: "https://app.shortcut.com/org/story/{query}"
          - keyword: gh
            name: GitHub
            url: "https://github.com/{query}"
        """, to: url)

        let store = QuickLinkStore(configURL: url)
        store.reload()

        #expect(store.quicklinks.count == 2)
        #expect(store.quicklinks[0].keyword == "sc")
        #expect(store.quicklinks[0].name == "Shortcut Story")
        #expect(store.quicklinks[1].keyword == "gh")
    }

    @Test
    func `handles missing file gracefully`() {
        let url = makeTempConfigURL()
        // Don't create any file
        let store = QuickLinkStore(configURL: url)
        store.reload()

        #expect(store.quicklinks.isEmpty)
    }

    @Test
    func `handles malformed YAML gracefully`() {
        let url = makeTempConfigURL()
        writeYAML("not: [valid: yaml: {", to: url)

        let store = QuickLinkStore(configURL: url)
        store.reload()

        #expect(store.quicklinks.isEmpty)
    }

    @Test
    func `add persists to file`() {
        let url = makeTempConfigURL()
        let store = QuickLinkStore(configURL: url)
        store.reload()

        store.add(QuickLink(keyword: "jira", name: "Jira", url: "https://jira.example.com/{query}"))

        #expect(store.quicklinks.count == 1)
        #expect(store.quicklinks[0].keyword == "jira")

        // Verify persistence by reloading
        let store2 = QuickLinkStore(configURL: url)
        store2.reload()
        #expect(store2.quicklinks.count == 1)
        #expect(store2.quicklinks[0].keyword == "jira")
    }

    @Test
    func `remove persists to file`() {
        let url = makeTempConfigURL()
        writeYAML("""
        quicklinks:
          - keyword: sc
            name: Shortcut
            url: "https://example.com/{query}"
          - keyword: gh
            name: GitHub
            url: "https://github.com/{query}"
        """, to: url)

        let store = QuickLinkStore(configURL: url)
        store.reload()
        store.remove(at: 0)

        #expect(store.quicklinks.count == 1)
        #expect(store.quicklinks[0].keyword == "gh")

        // Verify persistence
        let store2 = QuickLinkStore(configURL: url)
        store2.reload()
        #expect(store2.quicklinks.count == 1)
        #expect(store2.quicklinks[0].keyword == "gh")
    }

    @Test
    func `replace persists to file`() {
        let url = makeTempConfigURL()
        writeYAML("""
        quicklinks:
          - keyword: sc
            name: Shortcut
            url: "https://example.com/{query}"
        """, to: url)

        let store = QuickLinkStore(configURL: url)
        store.reload()
        store.replace(at: 0, with: QuickLink(keyword: "jira", name: "Jira", url: "https://jira.example.com/{query}"))

        #expect(store.quicklinks.count == 1)
        #expect(store.quicklinks[0].keyword == "jira")
        #expect(store.quicklinks[0].name == "Jira")

        // Verify persistence
        let store2 = QuickLinkStore(configURL: url)
        store2.reload()
        #expect(store2.quicklinks.count == 1)
        #expect(store2.quicklinks[0].keyword == "jira")
    }

    @Test
    func `replace out of bounds is safe`() {
        let url = makeTempConfigURL()
        let store = QuickLinkStore(configURL: url)
        store.reload()
        store.add(QuickLink(keyword: "sc", name: "Shortcut", url: "https://example.com/{query}"))

        store.replace(at: 5, with: QuickLink(keyword: "gh", name: "GitHub", url: "https://github.com/{query}"))
        #expect(store.quicklinks.count == 1)
        #expect(store.quicklinks[0].keyword == "sc")
    }

    @Test
    func `remove out of bounds is safe`() {
        let url = makeTempConfigURL()
        let store = QuickLinkStore(configURL: url)
        store.reload()

        store.remove(at: 5) // Should not crash
        #expect(store.quicklinks.isEmpty)
    }

    @Test
    func `round trip load modify save reload`() {
        let url = makeTempConfigURL()
        writeYAML("""
        quicklinks:
          - keyword: sc
            name: Shortcut
            url: "https://example.com/{query}"
        """, to: url)

        let store = QuickLinkStore(configURL: url)
        store.reload()
        store.add(QuickLink(keyword: "gh", name: "GitHub", url: "https://github.com/{query}"))
        store.remove(at: 0)

        store.reload()
        #expect(store.quicklinks.count == 1)
        #expect(store.quicklinks[0].keyword == "gh")
    }
}
