@testable import Helios
import Testing

@MainActor
struct CalculatorProviderTests {
    let provider = CalculatorProvider()

    @Test
    func `handles numeric queries`() {
        #expect(provider.canHandle(query: "2+2"))
        #expect(provider.canHandle(query: "100/5"))
        #expect(provider.canHandle(query: "(3+4)*2"))
        #expect(provider.canHandle(query: "-5+10"))
    }

    @Test
    func `rejects non-numeric queries`() {
        #expect(!provider.canHandle(query: "hello"))
        #expect(!provider.canHandle(query: "time in tokyo"))
        #expect(!provider.canHandle(query: ""))
    }

    @Test
    func `basic arithmetic`() {
        let results = provider.search(query: "2+2")
        #expect(results.count == 1)
        #expect(results[0].title == "= 4")
    }

    @Test
    func `decimal results`() {
        let results = provider.search(query: "10/3")
        #expect(results.count == 1)
        #expect(results[0].title.hasPrefix("= 3.333"))
    }

    @Test
    func percentage() {
        let results = provider.search(query: "50%")
        #expect(results.count == 1)
        #expect(results[0].title == "= 0.5")
    }

    @Test
    func `invalid expression returns empty`() {
        let results = provider.search(query: "2++2")
        #expect(results.isEmpty)
    }

    @Test
    func `result action is copyToClipboard`() {
        let results = provider.search(query: "5*5")
        #expect(results.count == 1)
        if case let .copyToClipboard(value) = results[0].action {
            #expect(value == "25")
        } else {
            Issue.record("Expected copyToClipboard action")
        }
    }
}
