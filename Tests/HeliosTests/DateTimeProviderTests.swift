@testable import Helios
import Testing

@MainActor
struct DateTimeProviderTests {
    let provider = DateTimeProvider()

    @Test
    func `az time in utc returns result`() {
        #expect(provider.canHandle(query: "az time in utc"))
        let results = provider.search(query: "az time in utc")
        #expect(results.count == 1)
        #expect(results[0].subtitle.contains("America/Phoenix"))
        #expect(results[0].subtitle.contains("GMT") || results[0].subtitle.contains("UTC"))
    }

    @Test
    func `arizona time in london returns result`() {
        #expect(provider.canHandle(query: "arizona time in london"))
        let results = provider.search(query: "arizona time in london")
        #expect(results.count == 1)
        #expect(results[0].subtitle.contains("America/Phoenix"))
        #expect(results[0].subtitle.contains("Europe/London"))
    }

    @Test
    func `existing time in city still works`() {
        #expect(provider.canHandle(query: "time in tokyo"))
        let results = provider.search(query: "time in tokyo")
        #expect(results.count == 1)
        #expect(results[0].subtitle.contains("Tokyo"))
    }

    @Test
    func `existing time conversion still works`() {
        #expect(provider.canHandle(query: "3pm est in pst"))
        let results = provider.search(query: "3pm est in pst")
        #expect(results.count == 1)
    }

    @Test
    func `from now still works`() {
        #expect(provider.canHandle(query: "5 days from now"))
        let results = provider.search(query: "5 days from now")
        #expect(results.count == 1)
    }
}
