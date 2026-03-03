import Testing
@testable import Helios

@MainActor
@Suite("CalculatorProvider")
struct CalculatorProviderTests {
    let provider = CalculatorProvider()

    @Test("handles numeric queries")
    func canHandleNumeric() {
        #expect(provider.canHandle(query: "2+2"))
        #expect(provider.canHandle(query: "100/5"))
        #expect(provider.canHandle(query: "(3+4)*2"))
        #expect(provider.canHandle(query: "-5+10"))
    }

    @Test("rejects non-numeric queries")
    func canHandleRejectsText() {
        #expect(!provider.canHandle(query: "hello"))
        #expect(!provider.canHandle(query: "time in tokyo"))
        #expect(!provider.canHandle(query: ""))
    }

    @Test("basic arithmetic")
    func basicArithmetic() {
        let results = provider.search(query: "2+2")
        #expect(results.count == 1)
        #expect(results[0].title == "= 4")
    }

    @Test("decimal results")
    func decimalResults() {
        let results = provider.search(query: "10/3")
        #expect(results.count == 1)
        #expect(results[0].title.hasPrefix("= 3.333"))
    }

    @Test("percentage")
    func percentage() {
        let results = provider.search(query: "50%")
        #expect(results.count == 1)
        #expect(results[0].title == "= 0.5")
    }

    @Test("invalid expression returns empty")
    func invalidExpression() {
        let results = provider.search(query: "2++2")
        #expect(results.isEmpty)
    }

    @Test("result action is copyToClipboard")
    func resultAction() {
        let results = provider.search(query: "5*5")
        #expect(results.count == 1)
        if case .copyToClipboard(let value) = results[0].action {
            #expect(value == "25")
        } else {
            Issue.record("Expected copyToClipboard action")
        }
    }
}
