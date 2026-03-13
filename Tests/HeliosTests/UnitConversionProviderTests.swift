@testable import Helios
import Testing

@MainActor
struct UnitConversionProviderTests {
    let provider = UnitConversionProvider()

    // MARK: - canHandle

    @Test
    func `handles conversion with number`() {
        #expect(provider.canHandle(query: "5 cups in liters"))
        #expect(provider.canHandle(query: "100 kg to lbs"))
        #expect(provider.canHandle(query: "72 fahrenheit in celsius"))
    }

    @Test
    func `handles conversion without number`() {
        #expect(provider.canHandle(query: "cups to liters"))
        #expect(provider.canHandle(query: "km to miles"))
    }

    @Test
    func `rejects non-conversion queries`() {
        #expect(!provider.canHandle(query: "hello"))
        #expect(!provider.canHandle(query: "5 cups"))
        #expect(!provider.canHandle(query: ""))
    }

    @Test
    func `rejects mismatched unit types`() {
        #expect(!provider.canHandle(query: "5 kg in liters"))
        #expect(!provider.canHandle(query: "miles to celsius"))
    }

    // MARK: - Conversion correctness

    @Test
    func `cups to liters`() {
        let results = provider.search(query: "5 cups in liters")
        #expect(results.count == 1)
        #expect(results[0].title.contains("1.2"))
    }

    @Test
    func `kg to lbs`() {
        let results = provider.search(query: "100 kg to lbs")
        #expect(results.count == 1)
        #expect(results[0].title.contains("220.462"))
    }

    @Test
    func `fahrenheit to celsius`() {
        let results = provider.search(query: "72 fahrenheit in celsius")
        #expect(results.count == 1)
        #expect(results[0].title.contains("22.2"))
    }

    @Test
    func `bare query defaults to 1`() {
        let results = provider.search(query: "cups to liters")
        #expect(results.count == 1)
        #expect(results[0].title.contains("0.24"))
    }

    // MARK: - Edge cases

    @Test
    func `decimal input`() {
        let results = provider.search(query: "2.5 km to miles")
        #expect(results.count == 1)
        #expect(results[0].title.contains("1.553"))
    }

    @Test
    func `case insensitivity`() {
        #expect(provider.canHandle(query: "5 KG TO LBS"))
        let results = provider.search(query: "5 KG TO LBS")
        #expect(results.count == 1)
    }

    @Test
    func `result action is copyToClipboard`() {
        let results = provider.search(query: "5 cups in liters")
        #expect(results.count == 1)
        if case .copyToClipboard = results[0].action {
            // OK
        } else {
            Issue.record("Expected copyToClipboard action")
        }
    }
}
