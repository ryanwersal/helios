@testable import Helios
import Testing

struct TimezoneMapTests {
    @Test
    func `az resolves to Phoenix`() {
        let zone = TimezoneMap.timezone(for: "az")
        #expect(zone?.identifier == "America/Phoenix")
    }

    @Test
    func `arizona resolves to Phoenix`() {
        let zone = TimezoneMap.timezone(for: "arizona")
        #expect(zone?.identifier == "America/Phoenix")
    }

    @Test
    func `case insensitive lookup`() {
        let zone = TimezoneMap.timezone(for: "AZ")
        #expect(zone?.identifier == "America/Phoenix")
    }

    @Test
    func `hawaii resolves to Honolulu`() {
        let zone = TimezoneMap.timezone(for: "hawaii")
        #expect(zone?.identifier == "Pacific/Honolulu")
    }

    @Test
    func `alaska resolves to Anchorage`() {
        let zone = TimezoneMap.timezone(for: "alaska")
        #expect(zone?.identifier == "America/Anchorage")
    }

    @Test
    func `raw IANA identifiers resolve case insensitively`() {
        let zone = TimezoneMap.timezone(for: "america/new_york")
        #expect(zone?.identifier == "America/New_York")
    }

    @Test(arguments: ["CST", "ist"])
    func `global abbreviations require disambiguation`(input: String) {
        guard case let .ambiguous(alternatives) = TimezoneMap.resolve(input) else {
            Issue.record("Expected \(input) to be ambiguous")
            return
        }
        #expect(alternatives.count == 3)
        #expect(TimezoneMap.timezone(for: input) == nil)
    }
}
