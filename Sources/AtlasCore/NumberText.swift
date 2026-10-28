import Foundation

/// Human-friendly number rendering for the display.
public enum NumberText {
    /// Formats a value for display, choosing plain decimal or scientific notation.
    public static func string(for value: Double, significantDigits: Int = 12) -> String {
        if value.isNaN { return "undefined" }
        if value.isInfinite { return value < 0 ? "−∞" : "∞" }
        if value == 0 { return "0" }

        let magnitude = abs(value)
        if magnitude >= 1e12 || magnitude < 1e-9 {
            return scientific(value, significantDigits: significantDigits)
        }

        let exponent = Int(floor(log10(magnitude)))
        let decimals = min(max(0, significantDigits - 1 - exponent), 15)
        var text = String(format: "%.\(decimals)f", value)
        text = trimTrailingZeros(text)
        return text == "-0" ? "0" : text
    }

    /// A parseable representation, used when continuing a calculation from a result.
    public static func expressionString(_ value: Double) -> String {
        if value.isNaN { return "nan" }
        if value.isInfinite { return value < 0 ? "-infinity" : "infinity" }
        if value == 0 { return "0" }
        return String(format: "%.12g", value)
    }

    /// A small fraction that closely matches the value, if one exists.
    public static func fraction(for value: Double, maxDenominator: Int = 10_000) -> String? {
        guard value.isFinite, value != value.rounded() else { return nil }
        guard abs(value) < 1e9 else { return nil }

        var (previousNumerator, numerator) = (0, 1)
        var (previousDenominator, denominator) = (1, 0)
        var remainder = value
        var best: (numerator: Int, denominator: Int)?

        for _ in 0..<32 {
            let whole = floor(remainder)
            guard abs(whole) < 1e9 else { return nil }
            let nextNumerator = Int(whole) * numerator + previousNumerator
            let nextDenominator = Int(whole) * denominator + previousDenominator
            guard nextDenominator != 0 else { break }
            previousNumerator = numerator
            numerator = nextNumerator
            previousDenominator = denominator
            denominator = nextDenominator

            if denominator > maxDenominator { break }
            best = (numerator, denominator)

            let approximation = Double(numerator) / Double(denominator)
            if abs(approximation - value) <= 1e-12 * max(1, abs(value)) { break }

            let fractionalPart = remainder - whole
            if fractionalPart == 0 { break }
            remainder = 1 / fractionalPart
            if !remainder.isFinite { break }
        }

        guard let best, best.denominator > 1 else { return nil }
        let approximation = Double(best.numerator) / Double(best.denominator)
        guard abs(approximation - value) <= 1e-9 * max(1, abs(value)) else { return nil }
        let prefix = best.numerator < 0 ? "−" : ""
        return "\(prefix)\(abs(best.numerator))/\(best.denominator)"
    }

    /// Rounds small floating-point noise (e.g. 1.0000000000000002) away for friendlier output.
    public static func normalized(_ value: Double, tolerance: Double = 1e-12) -> Double {
        guard value.isFinite else { return value }
        let nearest = value.rounded()
        if abs(value - nearest) <= tolerance * max(1, abs(value)) {
            return nearest
        }
        return value
    }

    private static func scientific(_ value: Double, significantDigits: Int) -> String {
        let exponent = Int(floor(log10(abs(value))))
        let mantissa = value / pow(10, Double(exponent))
        var mantissaText = String(format: "%.\(max(0, significantDigits - 1))f", mantissa)
        mantissaText = trimTrailingZeros(mantissaText)
        return "\(mantissaText)×10\(superscript(exponent))"
    }

    private static func trimTrailingZeros(_ text: String) -> String {
        guard text.contains(".") else { return text }
        var trimmed = text
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed.isEmpty ? "0" : trimmed
    }

    private static let superscriptDigits: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "−": "⁻"
    ]

    private static func superscript(_ exponent: Int) -> String {
        var text = exponent < 0 ? "⁻" : ""
        for character in String(abs(exponent)) {
            text.append(superscriptDigits[character] ?? character)
        }
        return text
    }
}
