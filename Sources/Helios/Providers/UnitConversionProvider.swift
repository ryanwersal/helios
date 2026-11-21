import AppKit
import Foundation

@MainActor
final class UnitConversionProvider: SearchProvider {
    private static let pattern = makeRegex(
        #"^(\d+(?:\.\d+)?\s+)?(.+?)\s+(?:in|to)\s+(.+)$"#,
    )

    private struct Conversion {
        let amount: String
        let source: String
        let destination: String
        let sourceUnit: Dimension
        let destinationUnit: Dimension
    }

    private static func makeRegex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        } catch {
            fatalError("Invalid regex: \(pattern)")
        }
    }

    func canHandle(query: String) -> Bool {
        Self.matches(query)
    }

    static func matches(_ query: String) -> Bool {
        conversion(for: query) != nil
    }

    private static func conversion(for query: String) -> Conversion? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = pattern.firstMatch(in: trimmed, range: range) else { return nil }

        let source = extractGroup(2, from: match, in: trimmed)
        let destination = extractGroup(3, from: match, in: trimmed)
        guard let sourceUnit = UnitMap.unit(for: source),
              let destinationUnit = UnitMap.unit(for: destination),
              type(of: sourceUnit) == type(of: destinationUnit)
        else { return nil }

        return Conversion(
            amount: extractGroup(1, from: match, in: trimmed),
            source: source,
            destination: destination,
            sourceUnit: sourceUnit,
            destinationUnit: destinationUnit,
        )
    }

    func search(query: String) async -> [SearchResult] {
        guard let conversion = Self.conversion(for: query) else { return [] }
        let value = Double(conversion.amount.trimmingCharacters(in: .whitespaces)) ?? 1.0
        let measurement = Measurement(value: value, unit: conversion.sourceUnit)
        let converted = measurement.converted(to: conversion.destinationUnit)
        let formatted = formatNumber(converted.value)

        let icon = NSImage(
            systemSymbolName: "arrow.left.arrow.right",
            accessibilityDescription: "Unit conversion",
        )

        let subtitle = if conversion.amount.isEmpty {
            "1 \(conversion.source) = \(formatted) \(conversion.destination)"
        } else {
            "\(formatNumber(value)) \(conversion.source) → \(conversion.destination)"
        }

        return [SearchResult(
            title: "= \(formatted) \(conversion.destination)",
            subtitle: subtitle,
            icon: icon,
            action: .copyToClipboard(formatted),
            relevance: 10000,
        )]
    }

    private static func extractGroup(_ index: Int, from match: NSTextCheckingResult, in str: String) -> String {
        guard let range = Range(match.range(at: index), in: str) else { return "" }
        return String(str[range])
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }
        // Up to 6 decimal places, trimming trailing zeros
        let formatted = String(format: "%.6f", value)
        var result = formatted
        while result.hasSuffix("0") {
            result = String(result.dropLast())
        }
        if result.hasSuffix(".") {
            result = String(result.dropLast())
        }
        return result
    }
}
