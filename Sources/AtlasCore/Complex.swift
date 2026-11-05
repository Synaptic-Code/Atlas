import Foundation

// MARK: - Complex Numbers

/// A complex number `a + bi` in rectangular form.
///
/// This type is the arithmetic workhorse for the complex-aware command line
/// (`conj`, `arg`, `re`, `im`) and for the `i` constant exposed by the lexer.
/// Parsing of user text lives in ``parse``; display helpers live in
/// ``asRectangular`` and ``asPolar``.
///
/// The previous version of this file was dead code: it was never referenced by
/// the engine, its `init` was internal rather than public, and its parser could
/// not read any of the forms it advertised (`3i`, `1+2i`, `3∠45`). Those bugs
/// are fixed here.
public struct ComplexNumber: Equatable, Hashable, Sendable, CustomStringConvertible {
    public var real: Double
    public var imaginary: Double

    public init(real: Double = 0, imaginary: Double = 0) {
        self.real = real
        self.imaginary = imaginary
    }

    public init(_ real: Double) {
        self.init(real: real, imaginary: 0)
    }

    public static let zero = ComplexNumber(real: 0, imaginary: 0)
    public static let one = ComplexNumber(real: 1, imaginary: 0)
    /// The imaginary unit `i`, exposed to the expression parser.
    public static let imaginaryUnit = ComplexNumber(real: 0, imaginary: 1)

    // MARK: - Parsing

    /// Parses rectangular (`3i`, `2+4j`, `1.5 - 2i`) or polar (`3∠45`,
    /// `2<90°`) notation. Returns `nil` when the text is not a literal complex
    /// number; the expression parser is the right tool for general arithmetic.
    ///
    /// Plain real numbers parse successfully and yield a zero imaginary part.
    public static func parse(_ text: String, angleMode: AngleMode = .degrees) -> ComplexNumber? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let polar = parsePolar(trimmed, angleMode: angleMode) {
            return polar
        }

        let normalized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{2212}", with: "-")  // typographic minus
            .lowercased()

        let hasImaginaryUnit = normalized.contains("i") || normalized.contains("j")
        if hasImaginaryUnit {
            return parseRectangular(normalized)
        }

        guard let value = Double(normalized) else { return nil }
        return ComplexNumber(value)
    }

    /// Parses `r∠θ` and `r<θ`, in degrees when the angle carries `°` and in
    /// radians otherwise.
    ///
    /// The old implementation sliced the angle with
    /// `text.dropFirst(parts.count)`, which counted the *characters* of one
    /// half but dropped them from the whole string — an off-by-one that returned
    /// the real part unchanged and an imaginary part of zero.
    private static func parsePolar(_ text: String, angleMode: AngleMode) -> ComplexNumber? {
        let separators: [Character] = ["\u{2220}", "<"]  // ∠ or <
        guard let separatorIndex = text.firstIndex(where: { separators.contains($0) }) else {
            return nil
        }

        let magnitudeText = String(text[text.startIndex..<separatorIndex])
            .trimmingCharacters(in: .whitespaces)
        let angleText = String(text[text.index(after: separatorIndex)...])
            .trimmingCharacters(in: .whitespaces)

        guard let magnitude = Double(magnitudeText),
              var angle = Double(angleText.replacingOccurrences(of: "\u{00B0}", with: "")) else {
            return nil
        }
        // A degree sign always means degrees; without one, honour the caller's mode so
        // `3∠45` in degree mode really is 3∠45° (the old code always assumed radians,
        // which turned `3∠45` into 3∠45rad — an angle of 58.3°).
        if angleText.contains("\u{00B0}") || angleMode == .degrees {
            angle = angle * Double.pi / 180
        }
        return fromPolar(magnitude: magnitude, angle: angle)
    }

    /// Reads rectangular text that contains `i` or `j`.
    ///
    /// Supports `3i`, `-3i`, `i`, `-i`, `1+2i`, `1 - 2i`, `2i-3` and bare reals.
    private static func parseRectangular(_ text: String) -> ComplexNumber? {
        let hasImaginaryUnit = text.contains("i") || text.contains("j")
        guard hasImaginaryUnit else {
            guard let value = Double(text) else { return nil }
            return ComplexNumber(value)
        }

        // Split into at most two terms around the sign that separates the real
        // and imaginary parts. A leading sign belongs to the first term.
        var terms: [String] = []
        var current = ""
        for (offset, character) in text.enumerated() {
            if (character == "+" || character == "-"), offset > 0 {
                terms.append(current)
                current = String(character)
            } else {
                current.append(character)
            }
        }
        terms.append(current)

        guard terms.count == 2 else {
            // Exactly one term: either pure imaginary (`3i`) or a bare real.
            guard terms.count == 1 else { return nil }
            return imaginaryOnly(terms[0]) ?? Double(terms[0]).map(ComplexNumber.init)
        }

        let first = terms[0]
        let second = terms[1]
        if first.contains("i") || first.contains("j") {
            // `2i-3`
            guard let imaginary = imaginaryOnly(first),
                  let real = Double(second) else { return nil }
            return ComplexNumber(real: real, imaginary: imaginary.imaginary)
        } else {
            // `1+2i`
            guard let real = Double(first), let imaginary = imaginaryOnly(second) else {
                return nil
            }
            return ComplexNumber(real: real, imaginary: imaginary.imaginary)
        }
    }

    /// Parses a single term such as `3i`, `-i`, `+i`, `1.5j`.
    private static func imaginaryOnly(_ term: String) -> ComplexNumber? {
        var coefficient = term
        if coefficient.hasSuffix("i") || coefficient.hasSuffix("j") {
            coefficient.removeLast()
        } else {
            return nil
        }
        switch coefficient {
        case "", "+": return ComplexNumber(real: 0, imaginary: 1)
        case "-": return ComplexNumber(real: 0, imaginary: -1)
        default:
            guard let value = Double(coefficient) else { return nil }
            return ComplexNumber(real: 0, imaginary: value)
        }
    }

    // MARK: - Construction

    public static func fromPolar(magnitude: Double, angle: Double) -> ComplexNumber {
        ComplexNumber(real: magnitude * Foundation.cos(angle), imaginary: magnitude * Foundation.sin(angle))
    }

    // MARK: - Display

    /// `a + bi`, `a - bi`, `bi`, or `a` — whichever reads cleanest.
    ///
    /// The old version threw away the sign of a purely imaginary value:
    /// `-3i` was printed as `3i`.
    public var asRectangular: String {
        let value = normalized()
        let realText = NumberText.string(for: value.real)
        let imaginaryMagnitude = NumberText.string(for: abs(value.imaginary))

        if value.imaginary == 0 {
            return realText
        }
        let imaginaryText = imaginaryMagnitude == "1" ? "i" : "\(imaginaryMagnitude)i"
        if value.real == 0 {
            return value.imaginary < 0 ? "-\(imaginaryText)" : imaginaryText
        }
        return imaginary < 0
            ? "\(realText) − \(imaginaryText)"
            : "\(realText) + \(imaginaryText)"
    }

    public var description: String { asRectangular }

    /// `r∠θ` with the angle in `angleMode` (degrees by default, matching the
    /// app's default display mode).
    public func asPolar(angleMode: AngleMode = .degrees) -> String {
        let value = normalized()
        let cleanedAngle = value.argument
        let angle = angleMode == .degrees ? cleanedAngle * 180 / Double.pi : cleanedAngle
        let unit = angleMode == .degrees ? "\u{00B0}" : ""
        return "\(NumberText.string(for: value.magnitude))∠\(NumberText.string(for: angle))\(unit)"
    }

    /// Convenience for the roadmap's `r∠θ` display, in radians.
    public var asPolar: String { asPolar(angleMode: .radians) }

    // MARK: - Arithmetic

    public static func + (lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        ComplexNumber(real: lhs.real + rhs.real, imaginary: lhs.imaginary + rhs.imaginary)
    }

    public static func - (lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        ComplexNumber(real: lhs.real - rhs.real, imaginary: lhs.imaginary - rhs.imaginary)
    }

    /// `(a+bi)(c+di) = (ac − bd) + (ad + bc)i`.
    public static func * (lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        ComplexNumber(
            real: lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
            imaginary: lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
        )
    }

    public static func * (lhs: ComplexNumber, rhs: Double) -> ComplexNumber {
        ComplexNumber(real: lhs.real * rhs, imaginary: lhs.imaginary * rhs)
    }

    /// Throws ``MathError/divisionByZero`` when the divisor is zero.
    public static func / (lhs: ComplexNumber, rhs: ComplexNumber) throws -> ComplexNumber {
        let denominator = rhs.real * rhs.real + rhs.imaginary * rhs.imaginary
        guard denominator != 0 else { throw MathError.divisionByZero }
        return ComplexNumber(
            real: (lhs.real * rhs.real + lhs.imaginary * rhs.imaginary) / denominator,
            imaginary: (lhs.imaginary * rhs.real - lhs.real * rhs.imaginary) / denominator
        )
    }

    /// `z^w = e^(w · log z)`, with `log z = ln|z| + i·arg z`.
    ///
    /// Special-cases a zero base so `0^i` reports a domain error instead of
    /// returning a NaN pair.
    public static func power(_ base: ComplexNumber, _ exponent: ComplexNumber) throws -> ComplexNumber {
        if base == .zero {
            if exponent == .zero { throw MathError.domainError("0^0 is undefined.") }
            if exponent.imaginary == 0, exponent.real > 0 { return .zero }
            throw MathError.domainError("Zero cannot be raised to a non-positive power.")
        }
        let product = exponent * log(of: base)
        // `i²` computed through `e^(2·log i)` lands on `−1 + 1.2e-16i`. That is the exact
        // right answer buried under one ulp of trigonometric round-off, so snap it: a
        // component that is negligible against the modulus contributes nothing.
        return exp(of: product).normalized()
    }

    /// Natural logarithm: `ln|z| + i·arg z`.
    public static func log(of value: ComplexNumber) -> ComplexNumber {
        ComplexNumber(real: Foundation.log(value.magnitude), imaginary: value.argument)
    }

    public static func exp(of value: ComplexNumber) -> ComplexNumber {
        let scale = Foundation.exp(value.real)
        return ComplexNumber(
            real: scale * Foundation.cos(value.imaginary),
            imaginary: scale * Foundation.sin(value.imaginary)
        )
    }

    /// Principal square root, chosen on the right half-plane so `√-4` is `2i`.
    public static func sqrt(of value: ComplexNumber) throws -> ComplexNumber {
        try power(value, ComplexNumber(real: 0.5, imaginary: 0))
    }

    public static func sin(of value: ComplexNumber) -> ComplexNumber {
        ComplexNumber(
            real: Foundation.sin(value.real) * Foundation.cosh(value.imaginary),
            imaginary: Foundation.cos(value.real) * Foundation.sinh(value.imaginary)
        )
    }

    public static func cos(of value: ComplexNumber) -> ComplexNumber {
        ComplexNumber(
            real: Foundation.cos(value.real) * Foundation.cosh(value.imaginary),
            imaginary: -Foundation.sin(value.real) * Foundation.sinh(value.imaginary)
        )
    }

    public static func tan(of value: ComplexNumber) throws -> ComplexNumber {
        try sin(of: value) / cos(of: value)
    }

    // MARK: - Properties

    public var conjugate: ComplexNumber {
        ComplexNumber(real: real, imaginary: -imaginary)
    }

    public var magnitude: Double {
        hypot(real, imaginary)
    }

    /// Principal argument in radians, in `(-π, π]`.
    public var argument: Double {
        atan2(imaginary, real)
    }

    /// Snaps values that are a rounding error away from zero or from a whole number.
    ///
    /// Without this, `√-4` printed as `1.22×10⁻¹⁶ + 2i` and `i²` as `-1 + 1.22×10⁻¹⁶i` —
    /// mathematically exact results buried under trigonometric round-off.
    public func normalized(relativeTolerance: Double = 1e-12) -> ComplexNumber {
        let scale = max(1, magnitude)
        let cleanReal = abs(real) < relativeTolerance * scale ? 0 : real
        let cleanImaginary = abs(imaginary) < relativeTolerance * scale ? 0 : imaginary
        return ComplexNumber(real: cleanReal, imaginary: cleanImaginary)
    }

    public var isReal: Bool { imaginary == 0 }

    public var isFinite: Bool { real.isFinite && imaginary.isFinite }
}
