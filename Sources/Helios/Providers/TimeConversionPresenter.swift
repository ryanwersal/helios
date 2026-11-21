import AppKit
import Foundation

/// Maps conversion-domain outcomes to launcher result rows.
@MainActor
struct TimeConversionPresenter {
    let calendar: Calendar
    let locale: Locale

    func results(for conversion: TimeConversion) -> [SearchResult] {
        conversion.possibilities.enumerated().map { index, possibility in
            result(for: possibility, at: index, in: conversion)
        }
    }

    func diagnosticResult(_ diagnostic: TimeConversionDiagnostic) -> SearchResult {
        let content = diagnosticContent(diagnostic)
        return SearchResult(
            title: content.title,
            subtitle: content.subtitle,
            icon: NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: "Time conversion help",
            ),
            action: .none,
            relevance: 10000,
        )
    }

    private func result(
        for possibility: TimeConversionPossibility,
        at index: Int,
        in conversion: TimeConversion,
    ) -> SearchResult {
        let occurrence = occurrenceLabel(index: index, count: conversion.possibilities.count)
        let convertedText = destinationText(for: possibility.instant, in: conversion)
        let subtitle = contextText(for: possibility, in: conversion)
        return SearchResult(
            title: "\(occurrence)\(convertedText)",
            subtitle: subtitle,
            icon: NSImage(systemSymbolName: "globe", accessibilityDescription: "Timezone"),
            action: .copyToClipboard("\(occurrence)\(convertedText) — \(subtitle)"),
            relevance: 10000 - Double(index),
        )
    }

    private func destinationText(for instant: Date, in conversion: TimeConversion) -> String {
        let time = format(instant, format: "h:mm a", timeZone: conversion.destinationZone)
        let sourceDate = format(instant, format: "yyyy-MM-dd", timeZone: conversion.sourceZone)
        let destinationDate = format(instant, format: "yyyy-MM-dd", timeZone: conversion.destinationZone)
        let includeDate = conversion.request.hasExplicitDate || sourceDate != destinationDate
        let destination = displayName(
            input: conversion.request.destinationInput,
            canonicalIdentifier: conversion.destinationZone.identifier,
        )
        guard includeDate else { return "\(time) in \(destination)" }
        let date = format(
            instant,
            format: "EEEE, MMM d, yyyy",
            timeZone: conversion.destinationZone,
        )
        return "\(time) on \(date) in \(destination)"
    }

    private func contextText(
        for possibility: TimeConversionPossibility,
        in conversion: TimeConversion,
    ) -> String {
        let sourceLocal = format(
            possibility.instant,
            format: "h:mm a 'on' EEEE, MMM d, yyyy",
            timeZone: conversion.sourceZone,
        )
        return "\(sourceLocal) \(conversion.sourceZone.identifier) "
            + "(\(possibility.sourceAbbreviation), \(possibility.sourceUTCOffset)) → "
            + "\(conversion.destinationZone.identifier) "
            + "(\(possibility.destinationAbbreviation), \(possibility.destinationUTCOffset))"
    }

    private func diagnosticContent(_ diagnostic: TimeConversionDiagnostic) -> (title: String, subtitle: String) {
        switch diagnostic {
        case .malformed:
            return (
                "Try “3pm in New York to London”",
                "Or use a date: “2026-01-15 11:30pm from America/Los_Angeles to Asia/Tokyo”.",
            )
        case let .invalidClock(value):
            return (
                "Invalid time “\(value)”",
                "Use 1–12 with am/pm or 00:00–23:59, for example “15:30 from Berlin to Tokyo”.",
            )
        case let .invalidDate(value):
            return (
                "Invalid date “\(value)”",
                "Use YYYY-MM-DD, for example “2026-01-15 11:30pm from Los Angeles to Tokyo”.",
            )
        case let .unknownZone(value):
            return (
                "Unknown time zone “\(value)”",
                "Use a city such as London or an IANA identifier such as Europe/London.",
            )
        case let .ambiguousZone(value, alternatives):
            let choices = alternatives.map { "\($0.label) (\($0.identifier))" }.joined(separator: ", ")
            return ("“\(value.uppercased())” is ambiguous", "Choose a city or IANA zone: \(choices).")
        case let .nonexistentLocalTime(request, sourceZone, correction):
            return nonexistentTimeContent(request: request, sourceZone: sourceZone, correction: correction)
        }
    }

    private func nonexistentTimeContent(
        request: TimeConversionRequest,
        sourceZone: TimeZone,
        correction: DateComponents,
    ) -> (title: String, subtitle: String) {
        let inputDate = dateText(request.year, request.month, request.day)
        let correctedDate = dateText(correction.year, correction.month, correction.day)
        let correctedTime = queryClockText(correction.hour, correction.minute)
        let title = "\(clockText(request.hour, request.minute)) does not exist "
            + "in \(sourceZone.identifier) on \(inputDate)"
        let subtitle = "The clocks jump forward. Try “\(correctedDate) \(correctedTime) "
            + "from \(sourceZone.identifier) to \(request.destinationInput)”."
        return (title, subtitle)
    }

    private func occurrenceLabel(index: Int, count: Int) -> String {
        guard count > 1 else { return "" }
        return index == 0 ? "First occurrence — " : "Second occurrence — "
    }

    private func displayName(input: String, canonicalIdentifier: String) -> String {
        if input.contains("/") {
            return canonicalIdentifier
        }
        if TimezoneMap.abbreviationAliases.contains(input.lowercased()) {
            return input.uppercased()
        }
        return input.capitalized
    }

    private func format(_ date: Date, format: String, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private func dateText(_ year: Int?, _ month: Int?, _ day: Int?) -> String {
        String(format: "%04d-%02d-%02d", year ?? 0, month ?? 0, day ?? 0)
    }

    private func clockText(_ hour: Int, _ minute: Int) -> String {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        guard let date = components.date else { return queryClockText(hour, minute) }
        return format(date, format: "h:mm a", timeZone: TimeZone(secondsFromGMT: 0)!)
    }

    private func queryClockText(_ hour: Int?, _ minute: Int?) -> String {
        String(format: "%02d:%02d", hour ?? 0, minute ?? 0)
    }
}
