import AppKit
import Foundation

@MainActor
final class DateTimeProvider: SearchProvider {
    private static let timeInPattern = makeRegex(#"^time\s+in\s+(.+)$"#)
    private static let cityTimeInPattern = makeRegex(#"^(.+?)\s+time\s+in\s+(.+)$"#)
    private static let fromNowPattern = makeRegex(
        #"^(\d+)\s+(minute|hour|day|week|month|year)s?\s+from\s+now$"#,
    )
    private static let daysUntilPattern = makeRegex(#"^days?\s+until\s+(.+)$"#)
    private static let clockPrefixPattern = makeRegex(
        #"^(?:convert\s+)?(?:\d{4}-\d{2}-\d{2}\s+)?\d{1,2}(?::\d{1,2})?\s*(?:am|pm)?\b"#,
    )

    private let now: @MainActor () -> Date
    private let calendar: Calendar
    private let locale: Locale
    private let conversionEngine: TimeConversionEngine
    private let conversionPresenter: TimeConversionPresenter

    init(
        now: @escaping @MainActor () -> Date = { Date() },
        calendar: Calendar = Calendar(identifier: .gregorian),
        locale: Locale = Locale(identifier: "en_US_POSIX"),
    ) {
        self.now = now
        self.calendar = calendar
        self.locale = locale
        conversionEngine = TimeConversionEngine(calendar: calendar, locale: locale)
        conversionPresenter = TimeConversionPresenter(calendar: calendar, locale: locale)
    }

    func canHandle(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return Self.cityTimeInPattern.firstMatch(in: trimmed, range: range) != nil
            || Self.timeInPattern.firstMatch(in: trimmed, range: range) != nil
            || Self.fromNowPattern.firstMatch(in: trimmed, range: range) != nil
            || Self.daysUntilPattern.firstMatch(in: trimmed, range: range) != nil
            || isConversionIntent(trimmed)
    }

    func search(query: String) async -> [SearchResult] {
        results(for: query)
    }

    /// Synchronous entry point shared by launcher searches and the packaged-app smoke command.
    func results(for query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)

        if let match = Self.fromNowPattern.firstMatch(in: trimmed, range: range) {
            return handleFromNow(query: trimmed, match: match)
        }
        if let match = Self.daysUntilPattern.firstMatch(in: trimmed, range: range) {
            return handleDaysUntil(query: trimmed, match: match)
        }
        if let match = Self.cityTimeInPattern.firstMatch(in: trimmed, range: range) {
            return handleCityTimeIn(query: trimmed, match: match)
        }
        if let match = Self.timeInPattern.firstMatch(in: trimmed, range: range) {
            return handleTimeIn(query: trimmed, match: match)
        }
        if isConversionIntent(trimmed) {
            return handleConversion(query: trimmed)
        }
        return []
    }

    private static func makeRegex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        } catch {
            fatalError("Invalid regex: \(pattern)")
        }
    }

    private func isConversionIntent(_ query: String) -> Bool {
        let lowercased = query.lowercased()
        if lowercased.hasPrefix("convert ") {
            return true
        }
        let range = NSRange(query.startIndex..., in: query)
        guard Self.clockPrefixPattern.firstMatch(in: query, range: range) != nil else {
            return false
        }
        return lowercased.contains(" to ") || lowercased.contains(" in ") || lowercased.contains(" from ")
    }

    // MARK: - Current time

    private func handleTimeIn(query: String, match: NSTextCheckingResult) -> [SearchResult] {
        guard let cityRange = Range(match.range(at: 1), in: query) else { return [] }
        let city = String(query[cityRange])
        return currentTimeResult(for: city, subtitlePrefix: city.capitalized, iconName: "clock")
    }

    private func handleCityTimeIn(query: String, match: NSTextCheckingResult) -> [SearchResult] {
        guard let fromRange = Range(match.range(at: 1), in: query),
              let toRange = Range(match.range(at: 2), in: query)
        else { return [] }

        let source = String(query[fromRange])
        let destination = String(query[toRange])
        guard case let .resolved(sourceZone) = TimezoneMap.resolve(source) else {
            return zoneDiagnostic(for: source)
        }
        return currentTimeResult(
            for: destination,
            subtitlePrefix: "\(source.capitalized) (\(sourceZone.identifier)) "
                + "→ \(destination.capitalized)",
            iconName: "globe",
        )
    }

    private func currentTimeResult(
        for zoneInput: String,
        subtitlePrefix: String,
        iconName: String,
    ) -> [SearchResult] {
        guard case let .resolved(zone) = TimezoneMap.resolve(zoneInput) else {
            return zoneDiagnostic(for: zoneInput)
        }
        let referenceDate = now()
        let time = format(referenceDate, format: "h:mm a (XXXXX)", timeZone: zone)
        let day = format(referenceDate, format: "EEEE, MMM d", timeZone: zone)
        let resultText = "\(time) — \(day)"
        return [SearchResult(
            title: resultText,
            subtitle: "\(subtitlePrefix) (\(zone.identifier))",
            icon: NSImage(systemSymbolName: iconName, accessibilityDescription: "Time"),
            action: .copyToClipboard(resultText),
            relevance: 10000,
        )]
    }

    // MARK: - Conversion

    private func handleConversion(query: String) -> [SearchResult] {
        switch conversionEngine.convert(query: query, referenceDate: now()) {
        case let .conversion(conversion):
            conversionPresenter.results(for: conversion)
        case let .diagnostic(diagnostic):
            [conversionPresenter.diagnosticResult(diagnostic)]
        }
    }

    private func zoneDiagnostic(for input: String) -> [SearchResult] {
        let diagnostic: TimeConversionDiagnostic? = switch TimezoneMap.resolve(input) {
        case let .ambiguous(alternatives): .ambiguousZone(input, alternatives)
        case .unknown: .unknownZone(input)
        case .resolved: nil
        }
        guard let diagnostic else { return [] }
        return [conversionPresenter.diagnosticResult(diagnostic)]
    }

    // MARK: - Relative dates and countdowns

    private func handleFromNow(query: String, match: NSTextCheckingResult) -> [SearchResult] {
        guard let numRange = Range(match.range(at: 1), in: query),
              let unitRange = Range(match.range(at: 2), in: query),
              let number = Int(query[numRange])
        else { return [] }

        let unit = String(query[unitRange]).lowercased()
        let component: Calendar.Component? = switch unit {
        case "minute": .minute
        case "hour": .hour
        case "day": .day
        case "week": .weekOfYear
        case "month": .month
        case "year": .year
        default: nil
        }
        guard let component, let future = calendar.date(byAdding: component, value: number, to: now()) else {
            return []
        }
        let resultText = format(
            future,
            dateStyle: .full,
            timeStyle: component == .minute || component == .hour ? .short : .none,
        )
        return [SearchResult(
            title: resultText,
            subtitle: "\(number) \(unit)\(number == 1 ? "" : "s") from now",
            icon: NSImage(systemSymbolName: "calendar", accessibilityDescription: "Date"),
            action: .copyToClipboard(resultText),
            relevance: 10000,
        )]
    }

    private func handleDaysUntil(query: String, match: NSTextCheckingResult) -> [SearchResult] {
        guard let dateRange = Range(match.range(at: 1), in: query) else { return [] }
        let dateString = String(query[dateRange])
        guard let targetDate = parseDate(dateString) else { return [] }

        let start = calendar.startOfDay(for: now())
        let target = calendar.startOfDay(for: targetDate)
        guard let days = calendar.dateComponents([.day], from: start, to: target).day else {
            return []
        }
        let resultText = if days == 0 {
            "Today!"
        } else if days == 1 {
            "Tomorrow (1 day)"
        } else if days > 0 {
            "\(days) days"
        } else {
            "\(abs(days)) days ago"
        }
        return [SearchResult(
            title: resultText,
            subtitle: "Days until \(dateString)",
            icon: NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "Countdown"),
            action: .copyToClipboard(resultText),
            relevance: 10000,
        )]
    }

    private func parseDate(_ input: String) -> Date? {
        let formats = [
            "MMM d, yyyy", "MMM d yyyy", "MMMM d, yyyy", "MMMM d yyyy",
            "yyyy-MM-dd", "MM/dd/yyyy", "MM/dd/yy", "d MMM yyyy", "MMM d", "MMMM d",
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.dateFormat = format
            formatter.isLenient = false
            if let parsed = formatter.date(from: input) {
                guard !format.contains("y") else { return parsed }
                var components = calendar.dateComponents([.month, .day], from: parsed)
                components.year = calendar.component(.year, from: now())
                if let thisYear = calendar.date(from: components),
                   thisYear < calendar.startOfDay(for: now())
                {
                    components.year = (components.year ?? 0) + 1
                }
                return calendar.date(from: components)
            }
        }
        return nil
    }

    // MARK: - Formatting

    private func format(_ date: Date, format: String, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private func format(
        _ date: Date,
        dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style,
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }
}
