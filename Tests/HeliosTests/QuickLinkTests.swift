@testable import Helios
import Testing
import Yams

struct QuickLinkTests {
    @Test
    func `codable round trip`() throws {
        let original = QuickLink(keyword: "sc", name: "Shortcut", url: "https://example.com/{query}")
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(original)
        let decoded = try YAMLDecoder().decode(QuickLink.self, from: yaml)
        #expect(decoded == original)
    }

    @Test
    func `equatable conformance`() {
        let a = QuickLink(keyword: "gh", name: "GitHub", url: "https://github.com/{query}")
        let b = QuickLink(keyword: "gh", name: "GitHub", url: "https://github.com/{query}")
        let c = QuickLink(keyword: "gl", name: "GitLab", url: "https://gitlab.com/{query}")
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func `config codable round trip`() throws {
        let config = QuickLinksConfig(quicklinks: [
            QuickLink(keyword: "sc", name: "Shortcut", url: "https://example.com/{query}"),
            QuickLink(keyword: "gh", name: "GitHub", url: "https://github.com/{query}"),
        ])
        let yaml = try YAMLEncoder().encode(config)
        let decoded = try YAMLDecoder().decode(QuickLinksConfig.self, from: yaml)
        #expect(decoded.quicklinks == config.quicklinks)
    }
}
