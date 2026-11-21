import Foundation
@testable import Helios
import Testing

// Exact user-visible conversion strings intentionally keep dates, identifiers, and offsets together.
// swiftlint:disable line_length

@MainActor
struct DateTimeProviderTests {
    private let provider: DateTimeProvider

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let referenceDate = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z")!
        provider = DateTimeProvider(
            now: { referenceDate },
            calendar: calendar,
            locale: Locale(identifier: "en_US_POSIX"),
        )
    }

    @Test
    func `everyday city conversion has exact canonical context and copy action`() async {
        let result = await onlyResult("3pm in New York to London")
        #expect(result.title == "8:00 PM in London")
        #expect(result.subtitle == "3:00 PM on Thursday, Jan 15, 2026 America/New_York (EST, UTC-05:00) → Europe/London (GMT, UTC+00:00)")
        #expect(result.action == .copyToClipboard(
            "8:00 PM in London — 3:00 PM on Thursday, Jan 15, 2026 America/New_York (EST, UTC-05:00) → Europe/London (GMT, UTC+00:00)",
        ))
    }

    @Test
    func `convert from syntax is case insensitive`() async {
        let result = await onlyResult("CONVERT 15:30 FROM Berlin TO Tokyo")
        #expect(result.title == "11:30 PM in Tokyo")
        #expect(result.subtitle == "3:30 PM on Thursday, Jan 15, 2026 Europe/Berlin (GMT+1, UTC+01:00) → Asia/Tokyo (GMT+9, UTC+09:00)")
        #expect(result.action == .copyToClipboard(
            "11:30 PM in Tokyo — 3:30 PM on Thursday, Jan 15, 2026 Europe/Berlin (GMT+1, UTC+01:00) → Asia/Tokyo (GMT+9, UTC+09:00)",
        ))
    }

    @Test
    func `legacy abbreviation syntax remains copyable`() async {
        let result = await onlyResult("3pm est in pst")
        #expect(result.title == "12:00 PM in PST")
        #expect(result.subtitle == "3:00 PM on Thursday, Jan 15, 2026 America/New_York (EST, UTC-05:00) → America/Los_Angeles (PST, UTC-08:00)")
        #expect(result.action == .copyToClipboard(
            "12:00 PM in PST — 3:00 PM on Thursday, Jan 15, 2026 America/New_York (EST, UTC-05:00) → America/Los_Angeles (PST, UTC-08:00)",
        ))
    }

    @Test
    func `raw IANA conversion reports destination rollover date`() async {
        let result = await onlyResult(
            "2026-01-15 11:30pm from America/Los_Angeles to Asia/Tokyo",
        )
        #expect(result.title == "4:30 PM on Friday, Jan 16, 2026 in Asia/Tokyo")
        #expect(result.subtitle == "11:30 PM on Thursday, Jan 15, 2026 America/Los_Angeles (PST, UTC-08:00) → Asia/Tokyo (GMT+9, UTC+09:00)")
        #expect(result.action == .copyToClipboard(
            "4:30 PM on Friday, Jan 16, 2026 in Asia/Tokyo — 11:30 PM on Thursday, Jan 15, 2026 America/Los_Angeles (PST, UTC-08:00) → Asia/Tokyo (GMT+9, UTC+09:00)",
        ))
    }

    @Test(arguments: [
        ("2026-01-15 12am from UTC to Tokyo", "9:00 AM on Thursday, Jan 15, 2026 in Tokyo"),
        ("2026-01-15 12pm from UTC to Tokyo", "9:00 PM on Thursday, Jan 15, 2026 in Tokyo"),
        ("2026-01-15 00:00 from UTC to Tokyo", "9:00 AM on Thursday, Jan 15, 2026 in Tokyo"),
        ("2026-01-15 23:59 from UTC to Tokyo", "8:59 AM on Friday, Jan 16, 2026 in Tokyo"),
    ])
    func `strict clock boundaries convert correctly`(query: String, title: String) async {
        let result = await onlyResult(query)
        #expect(result.title == title)
        #expect(result.subtitle.contains("UTC+00:00"))
        #expect(result.subtitle.contains("UTC+09:00"))
        guard case let .copyToClipboard(copyText) = result.action else {
            Issue.record("Expected a copy action")
            return
        }
        #expect(copyText.contains(title))
    }

    @Test(arguments: ["25:00", "12:60", "13pm"])
    func `invalid clocks return actionable non-copying guidance`(clock: String) async {
        let result = await onlyResult("\(clock) from Berlin to Tokyo")
        #expect(result.title == "Invalid time “\(clock)”")
        #expect(result.subtitle == "Use 1–12 with am/pm or 00:00–23:59, for example “15:30 from Berlin to Tokyo”.")
        #expect(result.action == .none)
    }

    @Test(arguments: ["CST", "IST"])
    func `global abbreviation ambiguity names concrete alternatives`(zone: String) async {
        let result = await onlyResult("3pm from \(zone) to London")
        #expect(result.title == "“\(zone)” is ambiguous")
        #expect(result.subtitle.contains("America/") || result.subtitle.contains("Asia/"))
        #expect(result.subtitle.contains("Choose a city or IANA zone"))
        #expect(result.action == .none)
    }

    @Test
    func `spring forward gap is rejected with a valid correction`() async {
        let result = await onlyResult(
            "2026-03-08 2:30am from America/New_York to Europe/London",
        )
        #expect(result.title == "2:30 AM does not exist in America/New_York on 2026-03-08")
        #expect(result.subtitle == "The clocks jump forward. Try “2026-03-08 03:00 from America/New_York to Europe/London”.")
        #expect(result.action == .none)
    }

    @Test
    func `fall back overlap returns both labeled real instants`() async {
        let results = await provider.search(
            query: "2026-11-01 1:30am from America/New_York to Europe/London",
        )
        #expect(results.count == 2)
        #expect(results[0].title == "First occurrence — 5:30 AM on Sunday, Nov 1, 2026 in Europe/London")
        #expect(results[0].subtitle == "1:30 AM on Sunday, Nov 1, 2026 America/New_York (EDT, UTC-04:00) → Europe/London (GMT, UTC+00:00)")
        #expect(results[1].title == "Second occurrence — 6:30 AM on Sunday, Nov 1, 2026 in Europe/London")
        #expect(results[1].subtitle == "1:30 AM on Sunday, Nov 1, 2026 America/New_York (EST, UTC-05:00) → Europe/London (GMT, UTC+00:00)")
        #expect(results[0].action == .copyToClipboard(
            "First occurrence — 5:30 AM on Sunday, Nov 1, 2026 in Europe/London — 1:30 AM on Sunday, Nov 1, 2026 America/New_York (EDT, UTC-04:00) → Europe/London (GMT, UTC+00:00)",
        ))
        #expect(results[1].action == .copyToClipboard(
            "Second occurrence — 6:30 AM on Sunday, Nov 1, 2026 in Europe/London — 1:30 AM on Sunday, Nov 1, 2026 America/New_York (EST, UTC-05:00) → Europe/London (GMT, UTC+00:00)",
        ))
    }

    @Test
    func `unknown zone is claimed and explained`() async {
        #expect(provider.canHandle(query: "3pm from Atlantis to London"))
        let result = await onlyResult("3pm from Atlantis to London")
        #expect(result.title == "Unknown time zone “Atlantis”")
        #expect(result.subtitle == "Use a city such as London or an IANA identifier such as Europe/London.")
        #expect(result.action == .none)
    }

    @Test(arguments: ["convert 3pm New York London", "3pm New York to London"])
    func `malformed conversion is claimed and teaches both syntaxes`(query: String) async {
        #expect(provider.canHandle(query: query))
        let result = await onlyResult(query)
        #expect(result.title == "Try “3pm in New York to London”")
        #expect(result.subtitle == "Or use a date: “2026-01-15 11:30pm from America/Los_Angeles to Asia/Tokyo”.")
        #expect(result.action == .none)
    }

    @Test
    func `invalid explicit date returns correction guidance`() async {
        let result = await onlyResult("2026-02-30 3pm from New York to London")
        #expect(result.title == "Invalid date “2026-02-30”")
        #expect(result.subtitle == "Use YYYY-MM-DD, for example “2026-01-15 11:30pm from Los Angeles to Tokyo”.")
        #expect(result.action == .none)
    }

    @Test
    func `time in city remains deterministic and copyable`() async {
        let result = await onlyResult("time in tokyo")
        #expect(result.title == "9:00 PM (+09:00) — Thursday, Jan 15")
        #expect(result.subtitle == "Tokyo (Asia/Tokyo)")
        #expect(result.action == .copyToClipboard("9:00 PM (+09:00) — Thursday, Jan 15"))
    }

    @Test
    func `city to city current time remains available`() async {
        let result = await onlyResult("arizona time in london")
        #expect(result.title == "12:00 PM (Z) — Thursday, Jan 15")
        #expect(result.subtitle == "Arizona (America/Phoenix) → London (Europe/London)")
        #expect(result.action == .copyToClipboard("12:00 PM (Z) — Thursday, Jan 15"))
    }

    @Test
    func `relative date remains deterministic`() async {
        let result = await onlyResult("5 days from now")
        #expect(result.title == "Tuesday, January 20, 2026")
        #expect(result.subtitle == "5 days from now")
        #expect(result.action == .copyToClipboard("Tuesday, January 20, 2026"))
    }

    @Test
    func `countdown remains deterministic`() async {
        let result = await onlyResult("days until 2026-01-20")
        #expect(result.title == "5 days")
        #expect(result.subtitle == "Days until 2026-01-20")
        #expect(result.action == .copyToClipboard("5 days"))
    }

    @Test
    func `empty state teaches memorable conversion syntax`() {
        #expect(EmptyStateView.hints.contains { $0.text.contains("3pm in New York to London") })
    }

    private func onlyResult(_ query: String) async -> SearchResult {
        #expect(provider.canHandle(query: query))
        let results = await provider.search(query: query)
        #expect(results.count == 1)
        return results[0]
    }
}

// swiftlint:enable line_length
