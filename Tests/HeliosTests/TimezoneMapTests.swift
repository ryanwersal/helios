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
}
