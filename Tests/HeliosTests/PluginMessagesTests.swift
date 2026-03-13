import Foundation
@testable import Helios
import Testing

struct PluginMessagesTests {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - PluginRequest

    @Test
    func `encode initialize request`() throws {
        let request = PluginRequest.initialize()
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(PluginRequest.self, from: data)
        #expect(decoded.type == .initialize)
        #expect(decoded.query == nil)
        #expect(decoded.id == nil)
    }

    @Test
    func `encode search request`() throws {
        let request = PluginRequest.search(query: "github", id: "abc123")
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(PluginRequest.self, from: data)
        #expect(decoded.type == .search)
        #expect(decoded.query == "github")
        #expect(decoded.id == "abc123")
    }

    @Test
    func `encode shutdown request`() throws {
        let request = PluginRequest.shutdown()
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(PluginRequest.self, from: data)
        #expect(decoded.type == .shutdown)
    }

    @Test
    func `request round trip`() throws {
        let request = PluginRequest.search(query: "test", id: "xyz")
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(PluginRequest.self, from: data)
        #expect(decoded.type == .search)
        #expect(decoded.query == "test")
        #expect(decoded.id == "xyz")
    }

    // MARK: - PluginResponse

    @Test
    func `decode ready response`() throws {
        let json = #"{"type":"ready"}"#
        let response = try decoder.decode(PluginResponse.self, from: #require(json.data(using: .utf8)))
        #expect(response.type == .ready)
        #expect(response.results == nil)
    }

    @Test
    func `decode results response`() throws {
        let json = """
        {
            "type": "results",
            "id": "abc123",
            "results": [{
                "title": "GitHub",
                "subtitle": "https://github.com",
                "relevance": 500,
                "action": {"type": "openURL", "url": "https://github.com"},
                "iconSystemName": "book"
            }]
        }
        """
        let response = try decoder.decode(PluginResponse.self, from: #require(json.data(using: .utf8)))
        #expect(response.type == .results)
        #expect(response.id == "abc123")
        #expect(response.results?.count == 1)
        #expect(response.results?[0].title == "GitHub")
        #expect(response.results?[0].action.type == .openURL)
        #expect(response.results?[0].action.url == "https://github.com")
        #expect(response.results?[0].iconSystemName == "book")
    }

    @Test
    func `response round trip`() throws {
        let response = PluginResponse(
            type: .results,
            id: "test-id",
            results: [
                PluginResultItem(
                    title: "Test",
                    subtitle: "Sub",
                    relevance: 100,
                    action: PluginAction(type: .copyToClipboard, url: nil, text: "copied"),
                    iconSystemName: nil,
                    iconPath: nil,
                    iconBase64: nil,
                    iconTintable: nil,
                ),
            ],
        )
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(PluginResponse.self, from: data)
        #expect(decoded.type == .results)
        #expect(decoded.id == "test-id")
        #expect(decoded.results?.count == 1)
        #expect(decoded.results?[0].action.type == .copyToClipboard)
        #expect(decoded.results?[0].action.text == "copied")
    }

    // MARK: - PluginResultItem icon fields

    @Test
    func `result item with all icon types`() throws {
        let json = """
        {
            "title": "T",
            "subtitle": "S",
            "relevance": 0,
            "action": {"type": "openURL", "url": "https://example.com"},
            "iconSystemName": "star",
            "iconPath": "/tmp/icon.png",
            "iconBase64": "iVBOR",
            "iconTintable": false
        }
        """
        let item = try decoder.decode(PluginResultItem.self, from: #require(json.data(using: .utf8)))
        #expect(item.iconSystemName == "star")
        #expect(item.iconPath == "/tmp/icon.png")
        #expect(item.iconBase64 == "iVBOR")
        #expect(item.iconTintable == false)
    }
}
