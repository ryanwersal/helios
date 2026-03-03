import AppKit
import Foundation

@MainActor
final class DateTimeProvider: SearchProvider {
    private static let timeInPattern = try! NSRegularExpression(
        pattern: #"^time\s+in\s+(.+)$"#, options: .caseInsensitive
    )
    private static let convertPattern = try! NSRegularExpression(
        pattern: #"^(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\s+(\S+)\s+in\s+(.+)$"#,
        options: .caseInsensitive
    )
    private static let fromNowPattern = try! NSRegularExpression(
        pattern: #"^(\d+)\s+(minute|hour|day|week|month|year)s?\s+from\s+now$"#,
        options: .caseInsensitive
    )
    private static let daysUntilPattern = try! NSRegularExpression(
        pattern: #"^days?\s+until\s+(.+)$"#, options: .caseInsensitive
    )

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a (ZZZZZ)"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static let convertTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    private static let fullDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .short
        return f
    }()

    private static let parseFormatters: [(format: String, formatter: DateFormatter)] = {
        let formats = ["h:mm a", "h:mma", "ha", "h a", "HH:mm", "H:mm"]
        return formats.map { format in
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = Locale(identifier: "en_US_POSIX")
            return (format, f)
        }
    }()

    private static let dateParseFormatters: [(format: String, formatter: DateFormatter)] = {
        let formats = [
            "MMM d, yyyy", "MMM d yyyy", "MMMM d, yyyy", "MMMM d yyyy",
            "yyyy-MM-dd", "MM/dd/yyyy", "MM/dd/yy", "d MMM yyyy",
            "MMM d", "MMMM d",
        ]
        return formats.map { format in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            return (format, f)
        }
    }()

    func canHandle(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        let range = NSRange(q.startIndex..., in: q)
        return Self.timeInPattern.firstMatch(in: q, range: range) != nil
            || Self.convertPattern.firstMatch(in: q, range: range) != nil
            || Self.fromNowPattern.firstMatch(in: q, range: range) != nil
            || Self.daysUntilPattern.firstMatch(in: q, range: range) != nil
    }

    func search(query: String) -> [SearchResult] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let range = NSRange(q.startIndex..., in: q)

        if let match = Self.timeInPattern.firstMatch(in: q, range: range) {
            return handleTimeIn(query: q, match: match)
        }
        if let match = Self.convertPattern.firstMatch(in: q, range: range) {
            return handleConvert(query: q, match: match)
        }
        if let match = Self.fromNowPattern.firstMatch(in: q, range: range) {
            return handleFromNow(query: q, match: match)
        }
        if let match = Self.daysUntilPattern.firstMatch(in: q, range: range) {
            return handleDaysUntil(query: q, match: match)
        }

        return []
    }

    // MARK: - "time in <city>"

    private func handleTimeIn(query: String, match: NSTextCheckingResult) -> [SearchResult] {
        guard let cityRange = Range(match.range(at: 1), in: query) else { return [] }
        let city = String(query[cityRange])
        guard let tz = TimezoneMap.timezone(for: city) else { return [] }

        Self.timeFormatter.timeZone = tz
        let timeStr = Self.timeFormatter.string(from: Date())

        Self.dayFormatter.timeZone = tz
        let dayStr = Self.dayFormatter.string(from: Date())

        let icon = NSImage(systemSymbolName: "clock", accessibilityDescription: "Time")
        let resultText = "\(timeStr) — \(dayStr)"

        return [SearchResult(
            title: resultText,
            subtitle: "\(city.capitalized) (\(tz.identifier))",
            icon: icon,
            action: .copyToClipboard(resultText),
            relevance: 10000
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
            relevance: 10000
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
            relevance: 10000
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

        let resultText: String
        if days == 0 {
            resultText = "Today!"
        } else if days == 1 {
            resultText = "Tomorrow (1 day)"
        } else if days > 0 {
            resultText = "\(days) days"
        } else {
            resultText = "\(abs(days)) days ago"
        }

        let icon = NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: "Countdown")

        return [SearchResult(
            title: resultText,
            subtitle: "Days until \(dateStr)",
            icon: icon,
            action: .copyToClipboard(resultText),
            relevance: 10000
        )]
    }

    // MARK: - Helpers

    private func parseTime(_ str: String, in tz: TimeZone) -> Date? {
        for (_, formatter) in Self.parseFormatters {
            formatter.timeZone = tz
            if let date = formatter.date(from: str) {
                let calendar = Calendar.current
                var comps = calendar.dateComponents(in: tz, from: Date())
                let timeComps = calendar.dateComponents(in: tz, from: date)
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
