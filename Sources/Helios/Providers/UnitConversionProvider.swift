import AppKit
import Foundation

@MainActor
final class UnitConversionProvider: SearchProvider {
    private static let pattern = makeRegex(
        #"^(\d+(?:\.\d+)?\s+)?(.+?)\s+(?:in|to)\s+(.+)$"#,
    )

    private static func makeRegex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        } catch {
            fatalError("Invalid regex: \(pattern)")
        }
    }

    func canHandle(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = Self.pattern.firstMatch(in: trimmed, range: range) else { return false }

        let fromStr = extractGroup(2, from: match, in: trimmed)
        let toStr = extractGroup(3, from: match, in: trimmed)
        guard let fromUnit = UnitMap.unit(for: fromStr),
              let toUnit = UnitMap.unit(for: toStr)
        else { return false }

        return type(of: fromUnit) == type(of: toUnit)
    }

    func search(query: String) async -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = Self.pattern.firstMatch(in: trimmed, range: range) else { return [] }

        let numberStr = extractGroup(1, from: match, in: trimmed)
        let fromStr = extractGroup(2, from: match, in: trimmed)
        let toStr = extractGroup(3, from: match, in: trimmed)

        let value = Double(numberStr.trimmingCharacters(in: .whitespaces)) ?? 1.0
        let isBareQuery = numberStr.isEmpty

        guard let fromUnit = UnitMap.unit(for: fromStr),
              let toUnit = UnitMap.unit(for: toStr),
              type(of: fromUnit) == type(of: toUnit)
        else { return [] }

        let measurement = Measurement(value: value, unit: fromUnit)
        let converted = measurement.converted(to: toUnit)
        let formatted = formatNumber(converted.value)

        let icon = NSImage(
            systemSymbolName: "arrow.left.arrow.right",
            accessibilityDescription: "Unit conversion",
        )

        let subtitle = if isBareQuery {
            "1 \(fromStr) = \(formatNumber(Measurement(value: 1, unit: fromUnit).converted(to: toUnit).value)) \(toStr)"
        } else {
            "\(formatNumber(value)) \(fromStr) → \(toStr)"
        }

        return [SearchResult(
            title: "= \(formatted) \(toStr)",
            subtitle: subtitle,
            icon: icon,
            action: .copyToClipboard(formatted),
            relevance: 10000,
        )]
    }

    private func extractGroup(_ index: Int, from match: NSTextCheckingResult, in str: String) -> String {
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
