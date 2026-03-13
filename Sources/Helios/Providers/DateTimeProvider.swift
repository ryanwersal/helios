import AppKit
import Foundation

@MainActor
final class DateTimeProvider: SearchProvider {
    private static let timeInPattern = makeRegex(#"^time\s+in\s+(.+)$"#)
    private static let convertPattern = makeRegex(
        #"^(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\s+(\S+)\s+in\s+(.+)$"#,
    )
    private static let cityTimeInPattern = makeRegex(#"^(.+?)\s+time\s+in\s+(.+)$"#)
    private static let fromNowPattern = makeRegex(
        #"^(\d+)\s+(minute|hour|day|week|month|year)s?\s+from\s+now$"#,
    )
    private static let daysUntilPattern = makeRegex(#"^days?\s+until\s+(.+)$"#)

    private static func makeRegex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        } catch {
            fatalError("Invalid regex: \(pattern)")
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a (ZZZZZ)"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private static let convertTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    private static let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()

    private static let parseFormatters: [(format: String, formatter: DateFormatter)] = {
        let formats = ["h:mm a", "h:mma", "ha", "h a", "HH:mm", "H:mm"]
        return formats.map { format in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            return (format, dateFormatter)
        }
    }()

    private static let dateParseFormatters: [(format: String, formatter: DateFormatter)] = {
        let formats = [
            "MMM d, yyyy", "MMM d yyyy", "MMMM d, yyyy", "MMMM d yyyy",
            "yyyy-MM-dd", "MM/dd/yyyy", "MM/dd/yy", "d MMM yyyy",
            "MMM d", "MMMM d",
        ]
        return formats.map { format in
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = format
            return (format, dateFormatter)
        }
    }()

    func canHandle(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return Self.convertPattern.firstMatch(in: trimmed, range: range) != nil
            || Self.cityTimeInPattern.firstMatch(in: trimmed, range: range) != nil
            || Self.timeInPattern.firstMatch(in: trimmed, range: range) != nil
            || Self.fromNowPattern.firstMatch(in: trimmed, range: range) != nil
            || Self.daysUntilPattern.firstMatch(in: trimmed, range: range) != nil
    }

    func search(query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)

        if let match = Self.convertPattern.firstMatch(in: trimmed, range: range) {
            return handleConvert(query: trimmed, match: match)
        }
        if let match = Self.cityTimeInPattern.firstMatch(in: trimmed, range: range) {
            return handleCityTimeIn(query: trimmed, match: match)
        }
        if let match = Self.timeInPattern.firstMatch(in: trimmed, range: range) {
            return handleTimeIn(query: trimmed, match: match)
        }
        if let match = Self.fromNowPattern.firstMatch(in: trimmed, range: range) {
            return handleFromNow(query: trimmed, match: match)
        }
        if let match = Self.daysUntilPattern.firstMatch(in: trimmed, range: range) {
            return handleDaysUntil(query: trimmed, match: match)
        }

        return []
    }

    // MARK: - "time in <city>"

    private func handleTimeIn(query: String, match: NSTextCheckingResult) -> [SearchResult] {
        guard let cityRange = Range(match.range(at: 1), in: query) else { return [] }
        let city = String(query[cityRange])
        guard let zone = TimezoneMap.timezone(for: city) else { return [] }

        Self.timeFormatter.timeZone = zone
        let timeStr = Self.timeFormatter.string(from: Date())

        Self.dayFormatter.timeZone = zone
        let dayStr = Self.dayFormatter.string(from: Date())

        let icon = NSImage(systemSymbolName: "clock", accessibilityDescription: "Time")
        let resultText = "\(timeStr) — \(dayStr)"

        return [SearchResult(
            title: resultText,
            subtitle: "\(city.capitalized) (\(zone.identifier))",
            icon: icon,
            action: .copyToClipboard(resultText),
            relevance: 10000,
        )]
    }

    // MARK: - "<city> time in <city>"

    private func handleCityTimeIn(query: String, match: NSTextCheckingResult) -> [SearchResult] {
        guard let fromRange = Range(match.range(at: 1), in: query),
              let toRange = Range(match.range(at: 2), in: query)
        else { return [] }

        let fromCity = String(query[fromRange])
        let toCity = String(query[toRange])

        guard let fromTZ = TimezoneMap.timezone(for: fromCity),
              let toTZ = TimezoneMap.timezone(for: toCity)
        else { return [] }

        let now = Date()
        Self.timeFormatter.timeZone = toTZ
        let timeStr = Self.timeFormatter.string(from: now)

        Self.dayFormatter.timeZone = toTZ
        let dayStr = Self.dayFormatter.string(from: now)

        let icon = NSImage(systemSymbolName: "globe", accessibilityDescription: "Timezone")
        let resultText = "\(timeStr) — \(dayStr)"

        return [SearchResult(
            title: resultText,
            subtitle: "\(fromCity.capitalized) → \(toCity.capitalized) (\(fromTZ.identifier) → \(toTZ.identifier))",
            icon: icon,
            action: .copyToClipboard(resultText),
            relevance: 10000,
        )]
    }

    // MARK: - "<time> <tz> in <tz>"

    private func handleConvert(query: String, match: NSTextCheckingResult) -> [SearchResult] {
        guard let timeRange = Range(match.range(at: 1), in: query),
              let fromRange = Range(match.range(at: 2), in: query),
              let toRange = Range(match.range(at: 3), in: query)
        else { return [] }

        let timeStr = String(query[timeRange]).trimmingCharacters(in: .whitespaces)
        let fromCity = String(query[fromRange])
        let toCity = String(query[toRange])

        guard let fromTZ = TimezoneMap.timezone(for: fromCity),
              let toTZ = TimezoneMap.timezone(for: toCity)
        else { return [] }

        guard let date = parseTime(timeStr, in: fromTZ) else { return [] }

        Self.convertTimeFormatter.timeZone = toTZ
        let converted = Self.convertTimeFormatter.string(from: date)

        let icon = NSImage(systemSymbolName: "globe", accessibilityDescription: "Timezone")
        let resultText = "\(converted) in \(toCity.capitalized)"

        return [SearchResult(
            title: resultText,
            subtitle: "\(timeStr) \(fromCity.uppercased()) → \(toCity.capitalized) (\(toTZ.identifier))",
            icon: icon,
            action: .copyToClipboard(resultText),
            relevance: 10000,
        )]
    }

    // MARK: - "<N> <unit> from now"

    private func handleFromNow(query: String, match: NSTextCheckingResult) -> [SearchResult] {
        guard let numRange = Range(match.range(at: 1), in: query),
              let unitRange = Range(match.range(at: 2), in: query),
              let num = Int(query[numRange])
        else { return [] }

        let unit = String(query[unitRange]).lowercased()
        let component: Calendar.Component
        switch unit {
        case "minute": component = .minute
        case "hour": component = .hour
        case "day": component = .day
        case "week": component = .weekOfYear
        case "month": component = .month
        case "year": component = .year
        default: return []
        }

        guard let future = Calendar.current.date(byAdding: component, value: num, to: Date()) else {
            return []
        }

        let formatter = component == .minute || component == .hour
            ? Self.fullDateTimeFormatter
            : Self.fullDateFormatter
        let resultText = formatter.string(from: future)

        let icon = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Date")

        return [SearchResult(
            title: resultText,
            subtitle: "\(num) \(unit)\(num == 1 ? "" : "s") from now",
            icon: icon,
            action: .copyToClipboard(resultText),
            relevance: 10000,
        )]
    }

    // MARK: - "days until <date>"

    private func handleDaysUntil(query: String, match: NSTextCheckingResult) -> [SearchResult] {
        guard let dateRange = Range(match.range(at: 1), in: query) else { return [] }
        let dateStr = String(query[dateRange])

        guard let targetDate = parseDate(dateStr) else { return [] }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)

        guard let days = components.day else { return [] }

        let resultText = if days == 0 {
            "Today!"
        } else if days == 1 {
            "Tomorrow (1 day)"
        } else if days > 0 {
            "\(days) days"
        } else {
            "\(abs(days)) days ago"
        }

        let icon = NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "Countdown")

        return [SearchResult(
            title: resultText,
            subtitle: "Days until \(dateStr)",
            icon: icon,
            action: .copyToClipboard(resultText),
            relevance: 10000,
        )]
    }

    // MARK: - Helpers

    private func parseTime(_ str: String, in zone: TimeZone) -> Date? {
        for (_, formatter) in Self.parseFormatters {
            formatter.timeZone = zone
            if let date = formatter.date(from: str) {
                let calendar = Calendar.current
                var comps = calendar.dateComponents(in: zone, from: Date())
                let timeComps = calendar.dateComponents(in: zone, from: date)
                comps.hour = timeComps.hour
                comps.minute = timeComps.minute
                comps.second = 0
                return calendar.date(from: comps)
            }
        }
        return nil
    }

    private func parseDate(_ str: String) -> Date? {
        for (format, formatter) in Self.dateParseFormatters {
            if let date = formatter.date(from: str) {
                if !format.contains("y") {
                    let calendar = Calendar.current
                    var comps = calendar.dateComponents([.month, .day], from: date)
                    comps.year = calendar.component(.year, from: Date())
                    if let thisYear = calendar.date(from: comps),
                       thisYear < calendar.startOfDay(for: Date())
                    {
                        comps.year = (comps.year ?? 0) + 1
                    }
                    return calendar.date(from: comps)
                }
                return date
            }
        }
        return nil
    }
}
