import AppKit
import Expression

@MainActor
final class CalculatorProvider: SearchProvider {
    private static let constants: [String: Any] = [
        "pi": Double.pi,
        "e": M_E,
    ]

    func canHandle(query: String) -> Bool {
        guard let first = query.unicodeScalars.first else { return false }
        // Starts with digit, opening paren, or negative sign followed by digit
        if CharacterSet.decimalDigits.contains(first) || first == "(" {
            return true
        }
        if first == "-", query.unicodeScalars.count > 1 {
            let second = query.unicodeScalars[query.unicodeScalars.index(after: query.unicodeScalars.startIndex)]
            return CharacterSet.decimalDigits.contains(second) || second == "("
        }
        return false
    }

    func search(query: String) -> [SearchResult] {
        // Preprocess: replace common symbols
        var expr = query
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "^", with: "**")

        // Handle percentage: convert trailing % to /100
        if expr.hasSuffix("%") {
            expr = "(\(expr.dropLast()))/100"
        }

        do {
            let expression = AnyExpression(expr, constants: Self.constants)
            let result: Double = try expression.evaluate()

            let formatted = if result == result.rounded(), abs(result) < 1e15 {
                String(format: "%.0f", result)
            } else {
                // Remove trailing zeros
                String(format: "%.10g", result)
            }

            let icon = NSImage(systemSymbolName: "equal.circle", accessibilityDescription: "Calculator")

            return [SearchResult(
                title: "= \(formatted)",
                subtitle: "Press Enter to copy",
                icon: icon,
                action: .copyToClipboard(formatted),
                relevance: 10000, // Calculator always on top
            )]
        } catch {
            return []
        }
    }
}
