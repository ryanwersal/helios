import AppKit
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

    @Test(arguments: ["2026-01-15 3pm est in pst", "3pm from EST to PST", "3pm PST in EST"])
    func `the legacy exception applies only to the undated EST in PST form`(query: String) async {
        let result = await onlyResult(query)
        #expect(result.title.contains("is ambiguous"))
        #expect(result.action == .none)
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

    @Test(arguments: ["25:00", "12:60", "13pm", "100:00", "3xm", "3:005", "3:5", "3:"])
    func `invalid clocks return actionable non-copying guidance`(clock: String) async throws {
        try await expectInvalidClock("\(clock) from Berlin to Tokyo", clock: clock)
    }

    @Test
    func `dated malformed meridiem reaches the clock diagnostic`() async throws {
        try await expectInvalidClock("2026-01-15 3xm from Berlin to Tokyo", clock: "2026-01-15 3xm")
    }

    private func expectInvalidClock(_ query: String, clock: String) async throws {
        #expect(provider.canHandle(query: query))
        let result = try #require(await provider.search(query: query).first)
        #expect(result.title == "Invalid time “\(clock)”")
        #expect(result.subtitle == "Use 1–12 with am/pm or 00:00–23:59, for example “15:30 from Berlin to Tokyo”.")
        #expect(result.action == .none)
    }

    @Test(arguments: ["100 files from Berlin to Tokyo", "100 km to miles", "3km from Berlin to Tokyo", "3D models in Finder",
                      "3xm photos from Berlin", "100:00 timer app", "3xm notes in Finder"])
    func `ordinary searches do not become conversion attempts`(query: String) async {
        #expect(!provider.canHandle(query: query))
        #expect(await provider.search(query: query).isEmpty)
    }

    @Test(arguments: ["CST", "IST"])
    func `global abbreviation ambiguity names concrete alternatives`(zone: String) async {
        let result = await onlyResult("3pm from \(zone) to London")
        #expect(result.title == "“\(zone)” is ambiguous")
        #expect(result.subtitle.contains("America/") || result.subtitle.contains("Asia/"))
        #expect(result.subtitle.contains("Choose a city or IANA zone"))
        #expect(result.action == .none)
    }

    @Test(arguments: ["2026-01-15", "2026-07-15"])
    func `every abbreviation follows the regional ambiguity policy in both seasons`(day: String) async throws {
        let regions = [
            "aest": ["Australia/Sydney", "Australia/Brisbane"],
            "akst": ["America/Anchorage", "Etc/GMT+9"],
            "cet": ["Europe/Paris", "Africa/Algiers"],
            "cst": ["America/Chicago", "Asia/Shanghai", "America/Havana"],
            "eet": ["Europe/Athens", "Africa/Tripoli"],
            "est": ["America/New_York", "Etc/GMT+5"],
            "gmt": ["Europe/London", "UTC"],
            "hst": ["Pacific/Honolulu", "America/Adak"],
            "ist": ["Asia/Kolkata", "Europe/Dublin", "Asia/Jerusalem"],
            "jst": ["Asia/Tokyo"],
            "kst": ["Asia/Seoul"],
            "mst": ["America/Denver", "America/Phoenix"],
            "nzst": ["Pacific/Auckland", "Etc/GMT-12"],
            "pst": ["America/Los_Angeles", "Asia/Manila", "Etc/GMT+8"],
            "utc": ["UTC"],
        ]
        let instant = try #require(ISO8601DateFormatter().date(from: "\(day)T15:00:00Z"))
        #expect(Set(regions.keys) == TimezoneMap.abbreviationAliases)
        let conflicting = day == "2026-01-15"
            ? Set(["aest", "cst", "ist", "nzst", "pst"])
            : Set(["akst", "cet", "cst", "eet", "est", "gmt", "hst", "ist", "mst", "pst"])
        for (alias, identifiers) in regions.sorted(by: { $0.key < $1.key }) {
            let zones = try identifiers.map { identifier in try #require(TimeZone(identifier: identifier)) }
            let offsets = Set(zones.map { $0.secondsFromGMT(for: instant) })
            #expect((offsets.count > 1) == conflicting.contains(alias), "\(alias) on \(day)")
            let source = await onlyResult("\(day) 3pm from \(alias.uppercased()) to UTC")
            let destination = await onlyResult("\(day) 3pm from UTC to \(alias)")
            for result in [source, destination] {
                if identifiers.count > 1 {
                    #expect(result.title == "“\(alias.uppercased())” is ambiguous")
                    #expect(result.subtitle.contains("Choose a city or IANA zone"))
                    for identifier in identifiers {
                        #expect(result.subtitle.contains("(\(identifier))"))
                        #expect(TimezoneMap.timezone(for: identifier.lowercased()) == TimeZone(identifier: identifier))
                    }
                    #expect(result.action == .none)
                } else {
                    #expect(result.subtitle.contains("\(zones[0].identifier) ("))
                    guard case .copyToClipboard = result.action else {
                        Issue.record("Expected \(alias) to be copyable")
                        continue
                    }
                }
            }
        }
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

    @Test(arguments: [
        ("2011-12-30 12:00", "Pacific/Apia", "2011-12-31 00:00", "2011-12-30T10:00:00Z"),
        ("2026-10-04 02:15", "Australia/Lord_Howe", "2026-10-04 02:30", "2026-10-03T15:30:00Z"),
        ("1906-01-01 00:04", "Asia/Kolkata", "1906-01-01 00:09", "1905-12-31T18:39:00Z"),
    ])
    func `gap guidance suggests the first representable local minute`(
        invalid: String, identifier: String, expected: String, utc: String,
    ) async throws {
        let result = await onlyResult("\(invalid) from \(identifier) to UTC")
        #expect(result.title.contains("does not exist"))
        #expect(result.action == .none)
        let suggestion = try #require(result.subtitle.split(separator: "“").last?.split(separator: "”").first)
        #expect(suggestion == "\(expected) from \(identifier) to UTC")
        let corrected = await onlyResult(String(suggestion))
        guard case .copyToClipboard = corrected.action else {
            Issue.record("Expected the suggested query to convert")
            return
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let sourceZone = try #require(TimeZone(identifier: identifier))
        formatter.timeZone = sourceZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.isLenient = false
        let instant = try #require(ISO8601DateFormatter().date(from: utc))
        #expect(formatter.string(from: instant) == expected)
        #expect(formatter.date(from: expected) == instant)
    }

    @Test
    func `fall back on Lord Howe labels both half-hour-separated instants`() async {
        let results = await provider.search(query: "2026-04-05 01:45 from Australia/Lord_Howe to UTC")
        #expect(results.map(\.title) == [
            "First occurrence — 2:45 PM on Saturday, Apr 4, 2026 in UTC",
            "Second occurrence — 3:15 PM on Saturday, Apr 4, 2026 in UTC",
        ])
        #expect(results.first?.subtitle.contains("UTC+11:00") == true)
        #expect(results.last?.subtitle.contains("UTC+10:30") == true)
        for result in results {
            guard case .copyToClipboard = result.action else {
                Issue.record("Expected each occurrence to be copyable")
                continue
            }
        }
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
    func `empty state displays everyday, dated and unambiguous syntax`() throws {
        let view = EmptyStateView(frame: NSRect(
            x: 0, y: 0, width: SearchPanel.panelWidth, height: SearchPanel.emptyStateHeight,
        ))
        view.layoutSubtreeIfNeeded()
        let stack = try #require(view.subviews.first as? NSStackView)
        let labels = stack.arrangedSubviews.compactMap { row in
            (row as? NSStackView)?.arrangedSubviews.last as? NSTextField
        }.filter { !$0.isHiddenOrHasHiddenAncestor && view.bounds.contains(view.convert($0.bounds, from: $0)) }
        #expect(labels.contains { $0.stringValue.contains("3pm in New York to London") })
        #expect(labels.contains { $0.stringValue.contains("2026-01-15 15:30 from Berlin to Tokyo") })
        #expect(labels.contains { $0.stringValue.contains("city or IANA") && $0.stringValue.contains("Berlin or Europe/Berlin") })
    }

    private func onlyResult(_ query: String) async -> SearchResult {
        #expect(provider.canHandle(query: query))
        let results = await provider.search(query: query)
        #expect(results.count == 1)
        return results[0]
    }
}

// swiftlint:enable line_length
