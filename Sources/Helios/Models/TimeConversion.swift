import Foundation

struct TimeConversionRequest: Equatable, Sendable {
    let originalTime: String
    let sourceInput: String
    let destinationInput: String
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let hasExplicitDate: Bool
}

struct TimeConversionPossibility: Equatable, Sendable {
    let instant: Date
    let sourceAbbreviation: String
    let sourceUTCOffset: String
    let destinationAbbreviation: String
    let destinationUTCOffset: String
}

struct TimeConversion: Equatable, Sendable {
    let request: TimeConversionRequest
    let sourceZone: TimeZone
    let destinationZone: TimeZone
    let possibilities: [TimeConversionPossibility]
}

enum TimeConversionDiagnostic: Equatable, Sendable {
    case malformed
    case invalidClock(String)
    case invalidDate(String)
    case unknownZone(String)
    case ambiguousZone(String, [TimezoneMap.Alternative])
    case nonexistentLocalTime(
        request: TimeConversionRequest,
        sourceZone: TimeZone,
        correction: Date?,
    )
}

enum TimeConversionOutcome: Equatable, Sendable {
    case conversion(TimeConversion)
    case diagnostic(TimeConversionDiagnostic)
}

/// Parses and resolves timezone conversions without depending on AppKit presentation.
struct TimeConversionEngine: Sendable {
    private static let dateTimePattern = #"(?:(\d{4}-\d{2}-\d{2})\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#
    /// A mistyped meridiem still looks like a clock. Exclude attached length units such as km.
    private static let clockLikeRegex = makeRegex(
        pattern: #"^(?:\d{4}-\d{2}-\d{2}\s+)?\d+(?::\d*)?(?:\s*(?:[ap][a-z]?|(?![cdkmnu]m)[a-z]m))?$"#,
        options: .caseInsensitive,
    )
    private static let everydayPattern = makeRegex(
        pattern: #"^(?:convert\s+)?(.+?)\s+in\s+(.+?)\s+to\s+(.+)$"#,
        options: .caseInsensitive,
    )
    private static let fromPattern = makeRegex(
        pattern: #"^(?:convert\s+)?(.+?)\s+from\s+(.+?)\s+to\s+(.+)$"#,
        options: .caseInsensitive,
    )
    private static let legacyPattern = makeRegex(
        pattern: #"^(.+?)\s+(\S+)\s+in\s+(.+)$"#,
        options: .caseInsensitive,
    )
    private static let dateTimeRegex = makeRegex(
        pattern: "^\(dateTimePattern)$",
        options: .caseInsensitive,
    )
    private static let offsetSearchWindow: TimeInterval = 2 * 24 * 60 * 60

    let calendar: Calendar
    let locale: Locale

    init(
        calendar: Calendar = Calendar(identifier: .gregorian),
        locale: Locale = Locale(identifier: "en_US_POSIX"),
    ) {
        self.calendar = calendar
        self.locale = locale
    }

    /// Recognize a complete conversion even when the clock fails strict validation.
    func hasClockLikeConversion(_ query: String) -> Bool {
        guard let fields = conversionFields(in: query), !fields.isLegacy else { return false }
        let clock = fields.dateTime
        return Self.clockLikeRegex.firstMatch(in: clock, range: NSRange(clock.startIndex..., in: clock)) != nil
    }

    func convert(query: String, referenceDate: Date) -> TimeConversionOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let fields = conversionFields(in: trimmed) else {
            return .diagnostic(.malformed)
        }
        let sourceZone: TimeZone
        let destinationZone: TimeZone
        switch resolveZones(in: fields) {
        case let .success(source, destination):
            sourceZone = source
            destinationZone = destination
        case let .diagnostic(diagnostic):
            return .diagnostic(diagnostic)
        }
        let parsed: ParsedLocalTime
        switch parseLocalTime(fields.dateTime, referenceDate: referenceDate, sourceZone: sourceZone) {
        case let .success(value):
            parsed = value
        case let .invalidClock(value):
            return .diagnostic(.invalidClock(value))
        case let .invalidDate(value):
            return .diagnostic(.invalidDate(value))
        }
        let request = TimeConversionRequest(
            originalTime: fields.dateTime,
            sourceInput: fields.source,
            destinationInput: fields.destination,
            year: parsed.year,
            month: parsed.month,
            day: parsed.day,
            hour: parsed.hour,
            minute: parsed.minute,
            hasExplicitDate: parsed.hasExplicitDate,
        )
        return outcome(for: request, sourceZone: sourceZone, destinationZone: destinationZone)
    }

    private static func makeRegex(pattern: String, options: NSRegularExpression.Options) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            fatalError("Invalid time conversion regex: \(pattern)")
        }
    }

    private func resolveZones(in fields: ConversionFields) -> ResolvedZones {
        let source = fields.source
        let destination = fields.destination
        // The undated "clock est in pst" syntax has always meant New York to Los Angeles.
        // All other forms require explicit zones for these abbreviations.
        if fields.isLegacy, !fields.dateTime.contains("-"),
           source.lowercased() == "est", destination.lowercased() == "pst",
           let eastern = TimeZone(identifier: "America/New_York"),
           let pacific = TimeZone(identifier: "America/Los_Angeles")
        {
            return .success(eastern, pacific)
        }
        let sourceZone: TimeZone
        switch TimezoneMap.resolve(source) {
        case let .resolved(zone): sourceZone = zone
        case let .ambiguous(alternatives): return .diagnostic(.ambiguousZone(source, alternatives))
        case .unknown: return .diagnostic(.unknownZone(source))
        }
        switch TimezoneMap.resolve(destination) {
        case let .resolved(zone): return .success(sourceZone, zone)
        case let .ambiguous(alternatives): return .diagnostic(.ambiguousZone(destination, alternatives))
        case .unknown: return .diagnostic(.unknownZone(destination))
        }
    }

    private func outcome(
        for request: TimeConversionRequest,
        sourceZone: TimeZone,
        destinationZone: TimeZone,
    ) -> TimeConversionOutcome {
        let candidates = matchingInstants(for: request, in: sourceZone)
        guard !candidates.isEmpty else {
            let correction = nextValidLocalTime(after: request, in: sourceZone)
            return .diagnostic(.nonexistentLocalTime(
                request: request,
                sourceZone: sourceZone,
                correction: correction,
            ))
        }

        let possibilities = candidates.map { instant in
            TimeConversionPossibility(
                instant: instant,
                sourceAbbreviation: abbreviation(for: instant, in: sourceZone),
                sourceUTCOffset: Self.utcOffset(sourceZone.secondsFromGMT(for: instant)),
                destinationAbbreviation: abbreviation(for: instant, in: destinationZone),
                destinationUTCOffset: Self.utcOffset(destinationZone.secondsFromGMT(for: instant)),
            )
        }
        return .conversion(TimeConversion(
            request: request,
            sourceZone: sourceZone,
            destinationZone: destinationZone,
            possibilities: possibilities,
        ))
    }

    private func conversionFields(in query: String) -> ConversionFields? {
        if let fields = fields(matching: Self.everydayPattern, in: query) {
            return fields
        }
        if let fields = fields(matching: Self.fromPattern, in: query) {
            return fields
        }
        return fields(matching: Self.legacyPattern, in: query, isLegacy: true)
    }

    private func fields(
        matching regex: NSRegularExpression, in query: String, isLegacy: Bool = false,
    ) -> ConversionFields? {
        let range = NSRange(query.startIndex..., in: query)
        guard let match = regex.firstMatch(in: query, range: range),
              let dateTimeRange = Range(match.range(at: 1), in: query),
              let sourceRange = Range(match.range(at: 2), in: query),
              let destinationRange = Range(match.range(at: 3), in: query)
        else { return nil }

        return ConversionFields(
            dateTime: String(query[dateTimeRange]).trimmingCharacters(in: .whitespaces),
            source: String(query[sourceRange]).trimmingCharacters(in: .whitespaces),
            destination: String(query[destinationRange]).trimmingCharacters(in: .whitespaces),
            isLegacy: isLegacy,
        )
    }

    private func parseLocalTime(
        _ input: String,
        referenceDate: Date,
        sourceZone: TimeZone,
    ) -> LocalTimeParseResult {
        let range = NSRange(input.startIndex..., in: input)
        guard let match = Self.dateTimeRegex.firstMatch(in: input, range: range),
              let hourRange = Range(match.range(at: 2), in: input),
              let hourValue = Int(input[hourRange])
        else { return .invalidClock(input) }

        let minute = if let minuteRange = Range(match.range(at: 3), in: input) {
            Int(input[minuteRange]) ?? -1
        } else {
            0
        }
        guard minute >= 0, minute <= 59 else { return .invalidClock(input) }

        let meridiem = Range(match.range(at: 4), in: input).map {
            input[$0].lowercased()
        }
        let hour: Int
        if let meridiem {
            guard (1 ... 12).contains(hourValue) else { return .invalidClock(input) }
            hour = (hourValue % 12) + (meridiem == "pm" ? 12 : 0)
        } else {
            guard (0 ... 23).contains(hourValue) else { return .invalidClock(input) }
            hour = hourValue
        }

        if let dateRange = Range(match.range(at: 1), in: input) {
            return parseExplicitDate(String(input[dateRange]), hour: hour, minute: minute)
        }

        var sourceCalendar = calendar
        sourceCalendar.timeZone = sourceZone
        let date = sourceCalendar.dateComponents([.year, .month, .day], from: referenceDate)
        guard let year = date.year, let month = date.month, let day = date.day else {
            return .invalidDate(input)
        }
        return .success(ParsedLocalTime(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            hasExplicitDate: false,
        ))
    }

    private func parseExplicitDate(_ dateText: String, hour: Int, minute: Int) -> LocalTimeParseResult {
        let pieces = dateText.split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3,
              isValidDate(year: pieces[0], month: pieces[1], day: pieces[2])
        else { return .invalidDate(dateText) }
        return .success(ParsedLocalTime(
            year: pieces[0],
            month: pieces[1],
            day: pieces[2],
            hour: hour,
            minute: minute,
            hasExplicitDate: true,
        ))
    }

    private func isValidDate(year: Int, month: Int, day: Int) -> Bool {
        var utcCalendar = calendar
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = utcCalendar.date(from: components) else { return false }
        let roundTrip = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return roundTrip.year == year && roundTrip.month == month && roundTrip.day == day
    }

    private func matchingInstants(for request: TimeConversionRequest, in zone: TimeZone) -> [Date] {
        guard let localReference = utcDate(for: request) else { return [] }

        var offsets = Set<Int>()
        for seconds in stride(from: -Self.offsetSearchWindow, through: Self.offsetSearchWindow, by: 3600) {
            offsets.insert(zone.secondsFromGMT(for: localReference.addingTimeInterval(seconds)))
        }

        var zoneCalendar = calendar
        zoneCalendar.timeZone = zone
        let candidates = offsets.compactMap { offset -> Date? in
            let candidate = localReference.addingTimeInterval(TimeInterval(-offset))
            let values = zoneCalendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: candidate,
            )
            guard values.year == request.year,
                  values.month == request.month,
                  values.day == request.day,
                  values.hour == request.hour,
                  values.minute == request.minute,
                  values.second == 0
            else { return nil }
            return candidate
        }
        return Array(Set(candidates)).sorted()
    }

    private func utcDate(for request: TimeConversionRequest) -> Date? {
        var utcCalendar = calendar
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return utcCalendar.date(from: DateComponents(
            year: request.year,
            month: request.month,
            day: request.day,
            hour: request.hour,
            minute: request.minute,
            second: 0,
        ))
    }

    private func nextValidLocalTime(after request: TimeConversionRequest, in zone: TimeZone) -> Date? {
        guard let localReference = utcDate(for: request) else { return nil }
        var cursor = localReference - Self.offsetSearchWindow
        let limit = localReference + Self.offsetSearchWindow
        // Foundation reports offset transitions here, including changes to the standard offset.
        while let transition = zone.nextDaylightSavingTimeTransition(after: cursor), transition <= limit {
            let gapStart = transition + TimeInterval(zone.secondsFromGMT(for: transition - 1))
            let gapEnd = transition + TimeInterval(zone.secondsFromGMT(for: transition))
            if gapStart <= localReference, localReference < gapEnd {
                var localCalendar = calendar
                localCalendar.timeZone = zone
                // The query grammar has minute precision, while historical transitions can have seconds.
                let second = localCalendar.component(.second, from: transition)
                return transition + TimeInterval((60 - second) % 60)
            }
            cursor = transition
        }
        return nil
    }

    private static func utcOffset(_ seconds: Int) -> String {
        let sign = seconds < 0 ? "-" : "+"
        let absolute = abs(seconds)
        return String(format: "UTC%@%02d:%02d", sign, absolute / 3600, (absolute % 3600) / 60)
    }

    private func abbreviation(for date: Date, in zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = zone
        formatter.dateFormat = "zzz"
        let value = formatter.string(from: date)
        return value == "GMT+0" || value == "GMT-0" ? "GMT" : value
    }
}

private struct ConversionFields {
    let dateTime: String
    let source: String
    let destination: String
    let isLegacy: Bool
}

private struct ParsedLocalTime {
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let hasExplicitDate: Bool
}

private enum LocalTimeParseResult {
    case success(ParsedLocalTime)
    case invalidClock(String)
    case invalidDate(String)
}

private enum ResolvedZones {
    case success(TimeZone, TimeZone)
    case diagnostic(TimeConversionDiagnostic)
}
