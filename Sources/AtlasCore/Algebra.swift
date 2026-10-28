import Foundation

// MARK: - Public model

/// One root of a polynomial, real or complex.
public struct AlgebraRoot: Sendable, Equatable {
    public let real: Double
    public let imaginary: Double
    public let multiplicity: Int
    /// An exact form such as `2`, `(3 + √5)/2`, or `1 + 2i` when one is available.
    public let exactText: String?
    /// A decimal rendering, always available.
    public let approximateText: String

    public init(
        real: Double,
        imaginary: Double = 0,
        multiplicity: Int = 1,
        exactText: String? = nil,
        approximateText: String
    ) {
        self.real = real
        self.imaginary = imaginary
        self.multiplicity = max(1, multiplicity)
        self.exactText = exactText
        self.approximateText = approximateText
    }

    public var isReal: Bool { abs(imaginary) < 1e-9 }
}

/// The turning point of a parabola.
public struct AlgebraVertex: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let exactText: String?

    public init(x: Double, y: Double, exactText: String?) {
        self.x = x
        self.y = y
        self.exactText = exactText
    }
}

/// Everything the Algebra tab needs to present a solution.
public struct AlgebraSolution: Sendable {
    public let variable: String
    public let degree: Int
    /// Coefficients in ascending order (constant first), normalised for display.
    public let coefficients: [Double]
    public let roots: [AlgebraRoot]
    public let standardForm: String
    public let factoredForm: String?
    public let factoredNote: String?
    public let vertexForm: String?
    public let vertex: AlgebraVertex?
    public let discriminant: Double?
    public let discriminantText: String?
    public let rootSummary: String
    public let rootLines: [String]
    public let notes: [String]
    public let isIdentity: Bool
    public let isContradiction: Bool

    public init(
        variable: String,
        degree: Int,
        coefficients: [Double],
        roots: [AlgebraRoot],
        standardForm: String,
        factoredForm: String?,
        factoredNote: String?,
        vertexForm: String?,
        vertex: AlgebraVertex?,
        discriminant: Double?,
        discriminantText: String?,
        rootSummary: String,
        rootLines: [String],
        notes: [String],
        isIdentity: Bool = false,
        isContradiction: Bool = false
    ) {
        self.variable = variable
        self.degree = degree
        self.coefficients = coefficients
        self.roots = roots
        self.standardForm = standardForm
        self.factoredForm = factoredForm
        self.factoredNote = factoredNote
        self.vertexForm = vertexForm
        self.vertex = vertex
        self.discriminant = discriminant
        self.discriminantText = discriminantText
        self.rootSummary = rootSummary
        self.rootLines = rootLines
        self.notes = notes
        self.isIdentity = isIdentity
        self.isContradiction = isContradiction
    }

    /// Evaluates the solved polynomial with Horner's method.
    public func value(at x: Double) -> Double {
        var result = 0.0
        for coefficient in coefficients.reversed() {
            result = result * x + coefficient
        }
        return result
    }
}

// MARK: - Solver

/// Exact-ish polynomial solver behind the Algebra tab.
///
/// Linear and quadratic equations get exact rational/radical answers; higher
/// degrees are factored over the rationals first and only fall back to a numeric
/// root finder for what is left.
public enum AlgebraSolver {
    public static func solve(
        _ source: String,
        engine: CalculatorEngine = CalculatorEngine()
    ) throws -> AlgebraSolution {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MathError.emptyExpression }

        let (leftText, rightText) = LaTeX.splitEquation(trimmed)
        guard !leftText.isEmpty else { throw MathError.emptyExpression }

        let left = try ExpressionParser.parse(LaTeX.expression(from: leftText))
        let right = try rightText.map { try ExpressionParser.parse(LaTeX.expression(from: $0)) }

        let leftVariables = freeVariables(in: left, engine: engine)
        let rightVariables = right.map { freeVariables(in: $0, engine: engine) } ?? []

        var variable = "x"
        var coefficients: [Double]
        var notes: [String] = []

        // `y = x² - 4` is naturally read as "solve the right-hand side for x".
        if let right,
           case .variable(let leftName) = left,
           !rightVariables.contains(leftName),
           rightVariables.count == 1 {
            variable = rightVariables.first!
            coefficients = try polynomial(from: right, variable: variable, engine: engine)
            notes.append("Solved the right-hand side for \(variable).")
        } else {
            let allVariables = leftVariables.union(rightVariables)
            guard allVariables.count <= 1 else {
                let names = allVariables.sorted().joined(separator: ", ")
                throw MathError.domainError("Use one variable at a time — I found \(names).")
            }
            variable = allVariables.first ?? "x"

            let leftPolynomial = try polynomial(from: left, variable: variable, engine: engine)
            let rightPolynomial = try right.map {
                try polynomial(from: $0, variable: variable, engine: engine)
            } ?? [0]
            coefficients = subtract(leftPolynomial, rightPolynomial)
        }

        coefficients = trim(coefficients)
        guard coefficients.count <= 9 else {
            throw MathError.domainError("That polynomial is too high-degree for this solver (8 max).")
        }

        return makeSolution(
            polynomial: coefficients,
            variable: variable,
            notes: notes
        )
    }

    // MARK: Solution assembly

    private static func makeSolution(
        polynomial rawCoefficients: [Double],
        variable: String,
        notes initialNotes: [String]
    ) -> AlgebraSolution {
        var coefficients = rawCoefficients
        if let leading = coefficients.last, leading < 0 {
            coefficients = coefficients.map { -$0 }
        }
        coefficients = coefficients.map { abs($0) < 1e-14 ? 0 : $0 }

        let degree = coefficients.count - 1
        let integers = integerCoefficients(coefficients)
        let standardForm = polynomialString(
            coefficients: coefficients,
            integers: integers,
            variable: variable
        ) + " = 0"

        var notes = initialNotes

        if degree == 0 {
            let value = coefficients.first ?? 0
            let identity = abs(value) < 1e-12
            return AlgebraSolution(
                variable: variable,
                degree: 0,
                coefficients: coefficients,
                roots: [],
                standardForm: standardForm,
                factoredForm: nil,
                factoredNote: nil,
                vertexForm: nil,
                vertex: nil,
                discriminant: nil,
                discriminantText: nil,
                rootSummary: identity ? "Every value of \(variable)" : "No solution",
                rootLines: [],
                notes: identity ? ["The two sides are identical."] : ["The equation is inconsistent."],
                isIdentity: identity,
                isContradiction: !identity
            )
        }

        if degree == 1 {
            let linear = solveLinear(coefficients: coefficients, integers: integers, variable: variable)
            return AlgebraSolution(
                variable: variable,
                degree: 1,
                coefficients: coefficients,
                roots: linear.roots,
                standardForm: standardForm,
                factoredForm: linear.factored,
                factoredNote: nil,
                vertexForm: nil,
                vertex: nil,
                discriminant: nil,
                discriminantText: nil,
                rootSummary: rootSummary(for: linear.roots, variable: variable).summary,
                rootLines: rootSummary(for: linear.roots, variable: variable).lines,
                notes: notes
            )
        }

        // Degree 2 and above: factor over the rationals, then solve the remainder.
        let factored = factor(coefficients: coefficients, integers: integers, variable: variable)
        let roots = factored.roots
        let summary = rootSummary(for: roots, variable: variable)

        var vertex: AlgebraVertex?
        var vertexForm: String?
        var discriminant: Double?
        var discriminantText: String?

        if degree == 2 {
            let a = coefficients[2]
            let b = coefficients[1]
            let c = coefficients[0]
            let d = b * b - 4 * a * c
            discriminant = d
            discriminantText = NumberText.string(for: d)
            vertex = makeVertex(for: coefficients, integers: integers)
            vertexForm = makeVertexForm(for: coefficients, integers: integers, variable: variable)

            if abs(d) < 1e-12 {
                notes.append("The discriminant is zero, so there is one repeated real root.")
            } else if d > 0 {
                notes.append("The discriminant is positive, so there are two distinct real roots.")
                if isPerfectSquare(d) {
                    notes.append("It is a perfect square, so the roots are rational.")
                }
            } else {
                notes.append("The discriminant is negative, so the roots are complex conjugates.")
            }
        }

        if factored.factored == nil {
            notes.append("No rational linear factors were found.")
        }

        return AlgebraSolution(
            variable: variable,
            degree: degree,
            coefficients: coefficients,
            roots: roots,
            standardForm: standardForm,
            factoredForm: factored.factored,
            factoredNote: factored.factored == nil
                ? "Irreducible over the rationals."
                : nil,
            vertexForm: vertexForm,
            vertex: vertex,
            discriminant: discriminant,
            discriminantText: discriminantText,
            rootSummary: summary.summary,
            rootLines: summary.lines,
            notes: notes
        )
    }

    // MARK: Linear

    private static func solveLinear(
        coefficients: [Double],
        integers: [Int64]?,
        variable: String
    ) -> (roots: [AlgebraRoot], factored: String?) {
        let a = coefficients[1]
        let b = coefficients[0]
        let rootValue = -b / a

        let exact: Fraction? = integers.flatMap { ints in
            ints.count == 2 ? Fraction(-ints[0], ints[1]) : nil
        }
        let exactText = exact?.text
        let approximate = decimal(rootValue)
        let root = AlgebraRoot(
            real: rootValue,
            multiplicity: 1,
            exactText: exactText,
            approximateText: approximate
        )

        var factored: String?
        if let exact, let integers, integers.count == 2 {
            let leading = Fraction(integers[1])
            let q = exact.denominator
            let scale = leading / Fraction(q)
            let factor = factorText(p: exact.numerator, q: exact.denominator, variable: variable)
            factored = scalePrefix(scale) + factor
        } else {
            let coefficient = abs(a - 1) < 1e-12
                ? ""
                : (abs(a + 1) < 1e-12 ? "−" : NumberText.string(for: a))
            factored = "\(coefficient)(\(variable) − \(approximate))"
        }

        return ([root], factored)
    }

    // MARK: Factoring

    private struct LinearFactor: Sendable {
        let p: Int64
        let q: Int64
        var count: Int
    }

    private struct FactoredResult {
        var roots: [AlgebraRoot]
        var factored: String?
    }

    private static func factor(
        coefficients: [Double],
        integers: [Int64]?,
        variable: String
    ) -> FactoredResult {
        guard let integers else {
            return FactoredResult(
                roots: numericRoots(coefficients),
                factored: nil
            )
        }

        var highFirst = Array(integers.reversed())
        trimHighFirst(&highFirst)

        var factors: [LinearFactor] = []
        var remainder = highFirst
        var iterations = 0

        while remainder.count > 1, iterations < 10 {
            iterations += 1
            guard let constant = remainder.last else { break }

            var found: (p: Int64, q: Int64, quotient: [Int64])?

            if constant == 0 {
                // Divide by x.
                found = (0, 1, Array(remainder.dropLast()))
            } else {
                for candidate in rationalCandidates(leading: remainder.first ?? 1, constant: constant) {
                    if let quotient = divide(remainder, p: candidate.p, q: candidate.q) {
                        found = (candidate.p, candidate.q, quotient)
                        break
                    }
                }
            }

            guard let found else { break }
            if let index = factors.firstIndex(where: { $0.p == found.p && $0.q == found.q }) {
                factors[index].count += 1
            } else {
                factors.append(LinearFactor(p: found.p, q: found.q, count: 1))
            }
            remainder = found.quotient
            trimHighFirst(&remainder)
        }

        var roots: [AlgebraRoot] = []
        for factor in factors {
            let value = Fraction(factor.p, factor.q)
            let real = value.doubleValue
            roots.append(
                AlgebraRoot(
                    real: real,
                    multiplicity: factor.count,
                    exactText: value.text,
                    approximateText: decimal(real)
                )
            )
        }

        let remainderLowFirst = Array(remainder.reversed())
        let remainderDegree = remainderLowFirst.count - 1

        if remainderDegree == 2 {
            roots.append(contentsOf: quadraticRoots(
                coefficients: remainderLowFirst.map(Double.init),
                integers: remainderLowFirst,
                variable: "x"
            ))
        } else if remainderDegree == 1 {
            let a = Double(remainderLowFirst[1])
            let b = Double(remainderLowFirst[0])
            let value = Fraction(-remainderLowFirst[0], remainderLowFirst[1])
            roots.append(
                AlgebraRoot(
                    real: -b / a,
                    multiplicity: 1,
                    exactText: value.text,
                    approximateText: decimal(value.doubleValue)
                )
            )
        } else if remainderDegree >= 3 {
            roots.append(contentsOf: numericRoots(remainderLowFirst.map(Double.init)))
        }

        let factored = factoredString(
            factors: factors,
            remainder: remainderLowFirst,
            variable: variable
        )

        return FactoredResult(roots: roots, factored: factored)
    }

    private static func factoredString(
        factors: [LinearFactor],
        remainder: [Int64],
        variable: String
    ) -> String? {
        guard !factors.isEmpty else { return nil }

        var remainder = remainder
        trimLowFirst(&remainder)

        var content: Int64 = 0
        for coefficient in remainder {
            content = greatestCommonDivisor(content, abs(coefficient))
        }
        if content == 0 { content = 1 }
        if let leading = remainder.last, leading < 0 {
            content = -content
        }
        if content != 1 {
            remainder = remainder.map { $0 / content }
        }

        var parts: [String] = []
        let scale = Fraction(content)
        let prefix = scalePrefix(scale)
        if prefix != "1", !prefix.isEmpty {
            parts.append(prefix)
        }

        let grouped = factors.sorted {
            let left = Double($0.p) / Double($0.q)
            let right = Double($1.p) / Double($1.q)
            if abs(left - right) > 1e-12 { return left < right }
            return $0.q < $1.q
        }

        for factor in grouped {
            let text = factorText(p: factor.p, q: factor.q, variable: variable)
            if factor.count > 1 {
                parts.append(text + superscript(factor.count))
            } else {
                parts.append(text)
            }
        }

        let remainderDegree = remainder.count - 1
        if remainderDegree > 0 {
            let text = polynomialString(coefficients: remainder.map(Double.init), integers: remainder, variable: variable)
            parts.append("(" + text + ")")
        }

        return parts.isEmpty ? nil : parts.joined()
    }

    private static func factorText(p: Int64, q: Int64, variable: String) -> String {
        if p == 0 {
            return q == 1 ? variable : "\(q)\(variable)"
        }
        let xTerm = q == 1 ? variable : "\(q)\(variable)"
        if p < 0 {
            return "(\(xTerm) + \((-p).description))"
        }
        return "(\(xTerm) − \(p))"
    }

    private static func rationalCandidates(leading: Int64, constant: Int64) -> [(p: Int64, q: Int64)] {
        guard leading != 0, constant != 0 else { return [] }
        let numeratorDivisors = divisors(of: abs(constant))
        let denominatorDivisors = divisors(of: abs(leading))
        guard !numeratorDivisors.isEmpty, !denominatorDivisors.isEmpty else { return [] }

        var seen = Set<CandidateKey>()
        var candidates: [(p: Int64, q: Int64)] = []

        for numerator in numeratorDivisors {
            for denominator in denominatorDivisors {
                let both = greatestCommonDivisor(numerator, denominator)
                let p = numerator / both
                let q = denominator / both
                for sign: Int64 in [-1, 1] {
                    let key = CandidateKey(p: p * sign, q: q)
                    guard !seen.contains(key) else { continue }
                    seen.insert(key)
                    candidates.append((p * sign, q))
                }
            }
        }

        return candidates.sorted {
            abs(Double($0.p) / Double($0.q)) < abs(Double($1.p) / Double($1.q))
        }
    }

    private struct CandidateKey: Hashable {
        let p: Int64
        let q: Int64
    }

    private static func divide(_ coefficients: [Int64], p: Int64, q: Int64) -> [Int64]? {
        guard coefficients.count > 1, q != 0 else { return nil }
        let degree = coefficients.count - 1
        guard coefficients[0] % q == 0 else { return nil }

        var quotient = [Int64](repeating: 0, count: degree)
        quotient[0] = coefficients[0] / q

        for index in 1..<degree {
            let product = p.multipliedReportingOverflow(by: quotient[index - 1])
            guard !product.overflow else { return nil }
            let sum = coefficients[index].addingReportingOverflow(product.partialValue)
            guard !sum.overflow else { return nil }
            guard sum.partialValue % q == 0 else { return nil }
            quotient[index] = sum.partialValue / q
        }

        let product = p.multipliedReportingOverflow(by: quotient[degree - 1])
        guard !product.overflow else { return nil }
        let sum = coefficients[degree].addingReportingOverflow(product.partialValue)
        guard !sum.overflow, sum.partialValue == 0 else { return nil }
        return quotient
    }

    private static func divisors(of value: Int64) -> [Int64] {
        guard value > 0, value <= 1_000_000_000 else { return [] }
        var result: [Int64] = []
        var factor: Int64 = 1
        while factor * factor <= value {
            if value % factor == 0 {
                result.append(factor)
                if factor * factor != value {
                    result.append(value / factor)
                }
            }
            factor += 1
        }
        return result.sorted()
    }

    // MARK: Quadratic

    private static func quadraticRoots(
        coefficients: [Double],
        integers: [Int64]?,
        variable: String
    ) -> [AlgebraRoot] {
        guard coefficients.count == 3 else { return [] }
        let a = coefficients[2]
        let b = coefficients[1]
        let c = coefficients[0]
        guard a != 0 else { return [] }

        if let integers, integers.count == 3,
           let disc = integerDiscriminant(integers) {
            let A = integers[2]
            let B = integers[1]

            if disc > 0 {
                let square = integerSquareRoot(disc)
                if square * square == disc {
                    let first = Fraction(-B + square, 2 * A)
                    let second = Fraction(-B - square, 2 * A)
                    return [
                        root(first, multiplicity: first == second ? 2 : 1),
                        root(second, multiplicity: first == second ? 2 : 1)
                    ]
                }

                let simplified = simplifySquareRoot(disc)
                let firstText = radicalRootText(
                    b: B,
                    outside: simplified.outside,
                    inside: simplified.inside,
                    denominator: 2 * A,
                    sign: 1
                )
                let secondText = radicalRootText(
                    b: B,
                    outside: simplified.outside,
                    inside: simplified.inside,
                    denominator: 2 * A,
                    sign: -1
                )
                let firstValue = (-Double(B) + Double(simplified.outside) * Double(simplified.inside).squareRoot()) / Double(2 * A)
                let secondValue = (-Double(B) - Double(simplified.outside) * Double(simplified.inside).squareRoot()) / Double(2 * A)
                return [
                    AlgebraRoot(
                        real: firstValue,
                        exactText: firstText,
                        approximateText: decimal(firstValue)
                    ),
                    AlgebraRoot(
                        real: secondValue,
                        exactText: secondText,
                        approximateText: decimal(secondValue)
                    )
                ]
            }

            if disc == 0 {
                let value = Fraction(-B, 2 * A)
                return [root(value, multiplicity: 2)]
            }

            let realPart = Fraction(-B, 2 * A)
            let simplified = simplifySquareRoot(-disc)
            let imaginaryText = imaginaryRootText(
                outside: simplified.outside,
                inside: simplified.inside,
                denominator: abs(2 * A)
            )
            let imaginary = Double(simplified.outside) * Double(simplified.inside).squareRoot() / Double(abs(2 * A))
            let realValue = realPart.doubleValue

            let positive = complexText(real: realPart, imaginary: imaginaryText, sign: 1)
            let negative = complexText(real: realPart, imaginary: imaginaryText, sign: -1)
            let positiveApprox = complexApproximate(real: realValue, imaginary: imaginary, sign: 1)
            let negativeApprox = complexApproximate(real: realValue, imaginary: imaginary, sign: -1)

            return [
                AlgebraRoot(
                    real: realValue,
                    imaginary: imaginary,
                    exactText: positive,
                    approximateText: positiveApprox
                ),
                AlgebraRoot(
                    real: realValue,
                    imaginary: -imaginary,
                    exactText: negative,
                    approximateText: negativeApprox
                )
            ]
        }

        // Fallback for coefficients that are not comfortably rational.
        let discriminant = b * b - 4 * a * c
        if discriminant >= 0 {
            let root = discriminant.squareRoot()
            let first = (-b + root) / (2 * a)
            let second = (-b - root) / (2 * a)
            return [
                AlgebraRoot(real: first, approximateText: decimal(first)),
                AlgebraRoot(real: second, approximateText: decimal(second))
            ]
        }

        let realPart = -b / (2 * a)
        let imaginary = (-discriminant).squareRoot() / abs(2 * a)
        return [
            AlgebraRoot(
                real: realPart,
                imaginary: imaginary,
                approximateText: complexApproximate(real: realPart, imaginary: imaginary, sign: 1)
            ),
            AlgebraRoot(
                real: realPart,
                imaginary: -imaginary,
                approximateText: complexApproximate(real: realPart, imaginary: imaginary, sign: -1)
            )
        ]
    }

    private static func root(_ fraction: Fraction, multiplicity: Int) -> AlgebraRoot {
        AlgebraRoot(
            real: fraction.doubleValue,
            multiplicity: multiplicity,
            exactText: fraction.text,
            approximateText: decimal(fraction.doubleValue)
        )
    }

    private static func integerDiscriminant(_ coefficients: [Int64]) -> Int64? {
        let a = coefficients[2]
        let b = coefficients[1]
        let c = coefficients[0]

        let bSquared = b.multipliedReportingOverflow(by: b)
        guard !bSquared.overflow else { return nil }
        let ac = a.multipliedReportingOverflow(by: c)
        guard !ac.overflow else { return nil }
        let fourAC = (4 as Int64).multipliedReportingOverflow(by: ac.partialValue)
        guard !fourAC.overflow else { return nil }
        let result = bSquared.partialValue.subtractingReportingOverflow(fourAC.partialValue)
        guard !result.overflow else { return nil }
        return result.partialValue
    }

    private static func integerSquareRoot(_ value: Int64) -> Int64 {
        guard value > 0 else { return 0 }
        var guess = Int64(Double(value).squareRoot())
        while guess * guess > value { guess -= 1 }
        while (guess + 1) * (guess + 1) <= value { guess += 1 }
        return guess
    }

    private static func simplifySquareRoot(_ value: Int64) -> (outside: Int64, inside: Int64) {
        guard value > 0 else { return (1, value) }
        var outside: Int64 = 1
        var inside = value
        var factor: Int64 = 2

        while factor * factor <= inside, factor <= 100_000 {
            let square = factor * factor
            while inside % square == 0 {
                inside /= square
                outside *= factor
            }
            factor += 1
        }

        return (outside, inside)
    }

    private static func radicalRootText(
        b: Int64,
        outside: Int64,
        inside: Int64,
        denominator: Int64,
        sign: Int64
    ) -> String {
        var common = greatestCommonDivisor(abs(b), outside)
        common = greatestCommonDivisor(common, abs(denominator))
        if common == 0 { common = 1 }

        var constant = -b / common
        var coefficient = outside / common
        var divisor = denominator / common
        if divisor < 0 {
            divisor = -divisor
            constant = -constant
            coefficient = -coefficient
        }

        let radical = radicalTerm(coefficient: coefficient, inside: inside)
        var numerator: String

        if constant == 0 {
            numerator = (sign > 0 ? "" : "−") + radical
        } else if sign > 0 {
            numerator = signedText(constant) + " + " + radical
        } else {
            numerator = signedText(constant) + " − " + radical
        }

        if divisor == 1 {
            return numerator
        }
        return "(\(numerator))/\(divisor)"
    }

    private static func radicalTerm(coefficient: Int64, inside: Int64) -> String {
        if inside == 1 {
            return coefficient == 1 ? "1" : "\(coefficient)"
        }
        return coefficient == 1 ? "√\(inside)" : "\(coefficient)√\(inside)"
    }

    private static func imaginaryRootText(outside: Int64, inside: Int64, denominator: Int64) -> String {
        let common = max(greatestCommonDivisor(outside, abs(denominator)), 1)
        let coefficient = outside / common
        let divisor = denominator / common
        let radical = radicalTerm(coefficient: coefficient, inside: inside)

        if divisor == 1 {
            return radical
        }
        return "(\(radical)/\(divisor))"
    }

    private static func complexText(real: Fraction, imaginary: String, sign: Int64) -> String {
        let imaginaryPart = (sign > 0 ? "" : "−") + (imaginary == "1" ? "i" : imaginary + "i")
        if real.numerator == 0 {
            return imaginaryPart
        }
        let realPart = real.text
        return realPart + (sign > 0 ? " + " : " − ") + (imaginary == "1" ? "i" : imaginary + "i")
    }

    private static func complexApproximate(real: Double, imaginary: Double, sign: Int64) -> String {
        let realText = decimal(real)
        let magnitude = abs(imaginary)
        let imaginaryText = abs(magnitude - 1) < 1e-12 ? "i" : decimal(magnitude) + "i"
        if abs(real) < 1e-12 {
            return (sign > 0 ? "" : "−") + imaginaryText
        }
        return realText + (sign > 0 ? " + " : " − ") + imaginaryText
    }

    // MARK: Vertex

    private static func makeVertex(for coefficients: [Double], integers: [Int64]?) -> AlgebraVertex? {
        guard coefficients.count == 3 else { return nil }
        let a = coefficients[2]
        let b = coefficients[1]
        let c = coefficients[0]
        guard a != 0 else { return nil }

        let x = -b / (2 * a)
        let y = c - b * b / (4 * a)

        if let integers, integers.count == 3 {
            let exactX = Fraction(-integers[1], 2 * integers[2])
            let numerator = 4 * integers[2] * integers[0] - integers[1] * integers[1]
            let exactY = Fraction(numerator, 4 * integers[2])
            return AlgebraVertex(x: x, y: y, exactText: "(\(exactX.text), \(exactY.text))")
        }

        return AlgebraVertex(
            x: x,
            y: y,
            exactText: "(\(decimal(x)), \(decimal(y)))"
        )
    }

    private static func makeVertexForm(
        for coefficients: [Double],
        integers: [Int64]?,
        variable: String
    ) -> String? {
        guard coefficients.count == 3 else { return nil }
        let a = coefficients[2]
        guard a != 0 else { return nil }

        if let integers, integers.count == 3 {
            let A = integers[2]
            let h = Fraction(-integers[1], 2 * A)
            let numerator = 4 * A * integers[0] - integers[1] * integers[1]
            let k = Fraction(numerator, 4 * A)
            let scale = Fraction(A)

            let leading: String
            if scale == Fraction(1) {
                leading = ""
            } else if scale == Fraction(-1) {
                leading = "−"
            } else {
                leading = scale.text
            }

            let hText = h.numerator == 0
                ? variable
                : (h.numerator < 0
                    ? "\(variable) + \(Fraction(-h.numerator, h.denominator).text)"
                    : "\(variable) − \(h.text)")
            let square = "(\(hText))\(superscript(2))"

            let tail: String
            if k.numerator == 0 {
                tail = ""
            } else if k.numerator < 0 {
                tail = " − \(Fraction(-k.numerator, k.denominator).text)"
            } else {
                tail = " + \(k.text)"
            }

            return leading + square + tail
        }

        let h = -coefficients[1] / (2 * a)
        let k = coefficients[0] - coefficients[1] * coefficients[1] / (4 * a)
        let hText = h == 0
            ? variable
            : (h < 0
                ? "\(variable) + \(NumberText.string(for: abs(h)))"
                : "\(variable) − \(NumberText.string(for: h))")
        let leading = a == 1 ? "" : (a == -1 ? "−" : decimal(a))
        let tail = k == 0
            ? ""
            : (k < 0
                ? " − \(NumberText.string(for: abs(k)))"
                : " + \(NumberText.string(for: k))")
        return "\(leading)(\(hText))\(superscript(2))\(tail)"
    }

    // MARK: Numeric roots

    private static func numericRoots(_ coefficients: [Double]) -> [AlgebraRoot] {
        var coefficients = trim(coefficients)
        while coefficients.count > 1, let last = coefficients.last, abs(last) < 1e-14 {
            coefficients.removeLast()
        }
        guard coefficients.count > 1, let leading = coefficients.last, leading != 0 else {
            return []
        }

        let normalised = coefficients.map { $0 / leading }
        let degree = normalised.count - 1
        let radius = 1 + (normalised.dropLast().map { abs($0) }.max() ?? 0)

        var values: [Complex] = (0..<degree).map { index in
            let angle = 2 * Double.pi * Double(index) / Double(degree) + 0.4
            return Complex(
                real: radius * cos(angle),
                imaginary: radius * sin(angle)
            )
        }

        for _ in 0..<400 {
            var maximumChange = 0.0
            for index in 0..<degree {
                var denominator = Complex(real: 1, imaginary: 0)
                for other in 0..<degree where other != index {
                    denominator = denominator * (values[index] - values[other])
                }
                guard abs(denominator.real) + abs(denominator.imaginary) > 1e-18 else { continue }
                let correction = evaluate(normalised, at: values[index]) / denominator
                values[index] = values[index] - correction
                maximumChange = max(maximumChange, correction.magnitude)
            }
            if maximumChange < 1e-13 { break }
        }

        var roots: [AlgebraRoot] = []
        for value in values {
            var real = value.real
            var imaginary = value.imaginary
            if abs(imaginary) < 1e-7 * max(1, abs(real)) { imaginary = 0 }
            if abs(real) < 1e-9 * max(1, abs(imaginary)) { real = 0 }
            real = NumberText.normalized(real, tolerance: 1e-9)
            imaginary = NumberText.normalized(imaginary, tolerance: 1e-9)

            let approximate = imaginary == 0
                ? decimal(real)
                : complexApproximate(
                    real: real,
                    imaginary: abs(imaginary),
                    sign: imaginary < 0 ? -1 : 1
                )
            roots.append(
                AlgebraRoot(
                    real: real,
                    imaginary: imaginary,
                    approximateText: approximate
                )
            )
        }

        // Merge numerically identical roots and count their multiplicity.
        var merged: [AlgebraRoot] = []
        for root in roots {
            if let index = merged.firstIndex(where: { sameRoot($0, root) }) {
                let existing = merged[index]
                merged[index] = AlgebraRoot(
                    real: existing.real,
                    imaginary: existing.imaginary,
                    multiplicity: existing.multiplicity + 1,
                    exactText: existing.exactText,
                    approximateText: existing.approximateText
                )
            } else {
                merged.append(root)
            }
        }

        return merged.sorted(by: rootOrder)
    }

    private static func evaluate(_ coefficients: [Double], at value: Complex) -> Complex {
        var result = Complex(real: 0, imaginary: 0)
        for coefficient in coefficients.reversed() {
            result = result * value + Complex(real: coefficient, imaginary: 0)
        }
        return result
    }

    private static func sameRoot(_ lhs: AlgebraRoot, _ rhs: AlgebraRoot) -> Bool {
        abs(lhs.real - rhs.real) < 1e-6 && abs(lhs.imaginary - rhs.imaginary) < 1e-6
    }

    // MARK: Root summaries

    private static func rootSummary(
        for roots: [AlgebraRoot],
        variable: String
    ) -> (summary: String, lines: [String]) {
        guard !roots.isEmpty else {
            return ("No real roots", [])
        }

        let ordered = roots.sorted(by: rootOrder)
        var summaryParts: [String] = []
        var lines: [String] = []

        var index = 0
        while index < ordered.count {
            let root = ordered[index]

            if root.isReal {
                let text = root.exactText ?? root.approximateText
                let multiplicityText = root.multiplicity == 2
                    ? " (double root)"
                    : (root.multiplicity > 2 ? " (multiplicity \(root.multiplicity))" : "")
                summaryParts.append("\(variable) = \(text)" + multiplicityText)

                var line = "\(variable) = \(text)"
                if let exact = root.exactText, exact != root.approximateText {
                    line += "   ≈ \(root.approximateText)"
                }
                line += multiplicityText
                lines.append(line)
                index += 1
                continue
            }

            // Pair conjugates when possible.
            if index + 1 < ordered.count {
                let next = ordered[index + 1]
                if !next.isReal,
                   abs(root.real - next.real) < 1e-7,
                   abs(root.imaginary + next.imaginary) < 1e-7 {
                    let first = root.exactText ?? root.approximateText
                    let second = next.exactText ?? next.approximateText

                    if second == "−" + first {
                        summaryParts.append("\(variable) = ±\(first)")
                    } else if let plus = first.range(of: " + ") {
                        let mirrored = first.replacingCharacters(in: plus, with: " − ")
                        if mirrored == second {
                            let compact = first.replacingCharacters(in: plus, with: " ± ")
                            summaryParts.append("\(variable) = \(compact)")
                        } else {
                            summaryParts.append("\(variable) = \(first), \(second)")
                        }
                    } else {
                        summaryParts.append("\(variable) = \(first), \(second)")
                    }

                    lines.append("\(variable) = \(first)")
                    lines.append("\(variable) = \(second)")
                    index += 2
                    continue
                }
            }

            summaryParts.append("\(variable) = \(root.exactText ?? root.approximateText)")
            lines.append("\(variable) = \(root.exactText ?? root.approximateText)")
            index += 1
        }

        return (summaryParts.joined(separator: ", "), lines)
    }

    private static func rootOrder(_ lhs: AlgebraRoot, _ rhs: AlgebraRoot) -> Bool {
        if lhs.isReal != rhs.isReal {
            return lhs.isReal && !rhs.isReal
        }
        if abs(lhs.real - rhs.real) > 1e-7 {
            return lhs.real < rhs.real
        }
        return lhs.imaginary > rhs.imaginary
    }

    // MARK: Polynomial parsing

    private static func polynomial(
        from expression: Expression,
        variable: String,
        engine: CalculatorEngine
    ) throws -> [Double] {
        switch expression {
        case .number(let value):
            return [value]

        case .variable(let name):
            if name == variable { return [0, 1] }
            if let value = MathConstants.values[name] { return [value] }
            if let value = engine.variables[name] { return [value] }
            throw MathError.domainError(
                "“\(name)” is another variable. Solve for one variable at a time."
            )

        case .unary(let op, let operand):
            let value = try polynomial(from: operand, variable: variable, engine: engine)
            switch op {
            case "-": return value.map { -$0 }
            case "+": return value
            default: throw MathError.unexpectedToken(op)
            }

        case .binary(let op, let lhs, let rhs):
            let left = try polynomial(from: lhs, variable: variable, engine: engine)
            let right = try polynomial(from: rhs, variable: variable, engine: engine)
            switch op {
            case "+": return add(left, right)
            case "-": return subtract(left, right)
            case "*": return multiply(left, right)
            case "/":
                let divisor = trim(right)
                guard divisor.count == 1, let constant = divisor.first, constant != 0 else {
                    throw MathError.domainError("Dividing by a variable isn’t polynomial.")
                }
                return left.map { $0 / constant }
            case "^":
                let exponent = trim(right)
                guard exponent.count == 1, let raw = exponent.first else {
                    throw MathError.domainError("The exponent must be a whole number.")
                }
                let rounded = raw.rounded()
                guard abs(raw - rounded) < 1e-9, rounded >= 0, rounded <= 8 else {
                    throw MathError.domainError("The exponent must be a whole number between 0 and 8.")
                }
                if trim(left).count == 1 {
                    return [pow(left[0], rounded)]
                }
                return try power(left, Int(rounded))
            default:
                throw MathError.unexpectedToken(op)
            }

        case .percent(let operand):
            let value = try polynomial(from: operand, variable: variable, engine: engine)
            return value.map { $0 / 100 }

        case .call:
            // A function call is only allowed when it has no variable in it.
            guard freeVariables(in: expression, engine: engine).isEmpty else {
                throw MathError.domainError("Functions of the variable aren’t polynomials.")
            }
            let value = try engine.value(of: expression)
            guard value.isFinite else {
                throw MathError.domainError("That coefficient isn’t a finite number.")
            }
            return [value]
        }
    }

    private static func freeVariables(
        in expression: Expression,
        engine: CalculatorEngine
    ) -> Set<String> {
        switch expression {
        case .number:
            return []
        case .variable(let name):
            if MathConstants.values[name] != nil { return [] }
            if name == "ans" { return [] }
            if engine.variables[name] != nil { return [] }
            return [name]
        case .unary(_, let operand):
            return freeVariables(in: operand, engine: engine)
        case .binary(_, let lhs, let rhs):
            return freeVariables(in: lhs, engine: engine)
                .union(freeVariables(in: rhs, engine: engine))
        case .call(_, let arguments):
            return arguments.reduce(into: Set<String>()) {
                $0.formUnion(freeVariables(in: $1, engine: engine))
            }
        case .percent(let operand):
            return freeVariables(in: operand, engine: engine)
        }
    }

    private static func add(_ lhs: [Double], _ rhs: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: max(lhs.count, rhs.count))
        for index in lhs.indices { result[index] += lhs[index] }
        for index in rhs.indices { result[index] += rhs[index] }
        return trim(result)
    }

    private static func subtract(_ lhs: [Double], _ rhs: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: max(lhs.count, rhs.count))
        for index in lhs.indices { result[index] += lhs[index] }
        for index in rhs.indices { result[index] -= rhs[index] }
        return trim(result)
    }

    private static func multiply(_ lhs: [Double], _ rhs: [Double]) -> [Double] {
        guard !lhs.isEmpty, !rhs.isEmpty else { return [0] }
        var result = [Double](repeating: 0, count: lhs.count + rhs.count - 1)
        for left in lhs.indices {
            for right in rhs.indices {
                result[left + right] += lhs[left] * rhs[right]
            }
        }
        return trim(result)
    }

    private static func power(_ base: [Double], _ exponent: Int) throws -> [Double] {
        guard exponent <= 8 else {
            throw MathError.domainError("That power is too high for this solver (8 max).")
        }

        var result: [Double] = [1]
        var factor = base
        var remaining = exponent
        while remaining > 0 {
            if remaining & 1 == 1 {
                result = multiply(result, factor)
                guard result.count <= 9 else {
                    throw MathError.domainError("That polynomial is too high-degree for this solver.")
                }
            }
            remaining >>= 1
            if remaining > 0 {
                factor = multiply(factor, factor)
                guard factor.count <= 9 else {
                    throw MathError.domainError("That polynomial is too high-degree for this solver.")
                }
            }
        }
        return result
    }

    private static func trim(_ coefficients: [Double]) -> [Double] {
        var result = coefficients
        while result.count > 1, let last = result.last, abs(last) < 1e-12 {
            result.removeLast()
        }
        return result.map { abs($0) < 1e-14 ? 0 : $0 }
    }

    private static func trimLowFirst(_ coefficients: inout [Int64]) {
        while coefficients.count > 1, coefficients.last == 0 {
            coefficients.removeLast()
        }
    }

    private static func trimHighFirst(_ coefficients: inout [Int64]) {
        while coefficients.count > 1, coefficients.first == 0 {
            coefficients.removeFirst()
        }
    }

    // MARK: Formatting

    private static func polynomialString(
        coefficients: [Double],
        integers: [Int64]?,
        variable: String
    ) -> String {
        if let integers, integers.count == coefficients.count {
            return integerPolynomialString(integers, variable: variable)
        }

        var parts: [String] = []
        for power in stride(from: coefficients.count - 1, through: 0, by: -1) {
            let coefficient = coefficients[power]
            if abs(coefficient) < 1e-12 { continue }
            let magnitude = abs(coefficient)
            let sign = coefficient < 0 ? "−" : "+"
            let body: String

            if power == 0 {
                body = NumberText.string(for: magnitude)
            } else {
                let variablePart = power == 1 ? variable : variable + superscript(power)
                body = abs(magnitude - 1) < 1e-12
                    ? variablePart
                    : NumberText.string(for: magnitude) + variablePart
            }

            if parts.isEmpty {
                parts.append((coefficient < 0 ? "−" : "") + body)
            } else {
                parts.append(" \(sign) " + body)
            }
        }

        return parts.isEmpty ? "0" : parts.joined()
    }

    private static func integerPolynomialString(_ coefficients: [Int64], variable: String) -> String {
        var parts: [String] = []
        for power in stride(from: coefficients.count - 1, through: 0, by: -1) {
            let coefficient = coefficients[power]
            if coefficient == 0 { continue }

            let magnitude = abs(coefficient)
            let body: String
            if power == 0 {
                body = "\(magnitude)"
            } else {
                let variablePart = power == 1 ? variable : variable + superscript(power)
                body = magnitude == 1 ? variablePart : "\(magnitude)" + variablePart
            }

            if parts.isEmpty {
                parts.append((coefficient < 0 ? "−" : "") + body)
            } else {
                parts.append((coefficient < 0 ? " − " : " + ") + body)
            }
        }
        return parts.isEmpty ? "0" : parts.joined()
    }

    private static func scalePrefix(_ scale: Fraction) -> String {
        if scale == Fraction(1) { return "1" }
        if scale == Fraction(-1) { return "−" }
        return scale.text
    }

    private static func signedText(_ value: Int64) -> String {
        value < 0 ? "−\(-value)" : "\(value)"
    }

    private static func superscript(_ power: Int) -> String {
        let digits: [Character: Character] = [
            "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
            "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"
        ]
        var text = ""
        for character in String(power) {
            text.append(digits[character] ?? character)
        }
        return text
    }

    private static func isPerfectSquare(_ value: Double) -> Bool {
        guard value >= 0 else { return false }
        let root = value.squareRoot().rounded()
        return abs(root * root - value) < 1e-9 * max(1, value)
    }

    private static func decimal(_ value: Double) -> String {
        NumberText.string(for: NumberText.normalized(value))
            .replacingOccurrences(of: "-", with: "−")
    }

    // MARK: Rational coefficients

    private static func integerCoefficients(_ coefficients: [Double]) -> [Int64]? {
        var fractions: [Fraction] = []
        for coefficient in coefficients {
            if abs(coefficient) < 1e-14 {
                fractions.append(Fraction(0))
                continue
            }
            guard let fraction = Fraction.approximate(coefficient) else { return nil }
            guard abs(fraction.numerator) < 10_000_000, fraction.denominator < 10_000 else { return nil }
            fractions.append(fraction)
        }

        var lcm: Int64 = 1
        for fraction in fractions {
            let product = lcm.multipliedReportingOverflow(by: fraction.denominator)
            guard !product.overflow else { return nil }
            lcm = product.partialValue / greatestCommonDivisor(lcm, fraction.denominator)
        }

        var integers: [Int64] = []
        for fraction in fractions {
            let scaled = fraction.numerator.multipliedReportingOverflow(by: lcm / fraction.denominator)
            guard !scaled.overflow else { return nil }
            integers.append(scaled.partialValue)
        }

        if let leading = integers.last, leading < 0 {
            integers = integers.map { -$0 }
        }

        return integers
    }
}

// MARK: - Rational numbers

private struct Fraction: Hashable, Sendable {
    let numerator: Int64
    let denominator: Int64

    init(_ numerator: Int64, _ denominator: Int64 = 1) {
        precondition(denominator != 0)
        var top = numerator
        var bottom = denominator
        if bottom < 0 {
            top = -top
            bottom = -bottom
        }
        let divisor = greatestCommonDivisor(abs(top), bottom)
        self.numerator = top / max(divisor, 1)
        self.denominator = bottom / max(divisor, 1)
    }

    var doubleValue: Double {
        Double(numerator) / Double(denominator)
    }

    var text: String {
        if denominator == 1 {
            return numerator < 0 ? "−\(-numerator)" : "\(numerator)"
        }
        let sign = numerator < 0 ? "−" : ""
        return "\(sign)\(abs(numerator))/\(denominator)"
    }

    static func / (lhs: Fraction, rhs: Fraction) -> Fraction {
        Fraction(lhs.numerator * rhs.denominator, lhs.denominator * rhs.numerator)
    }

    static func * (lhs: Fraction, rhs: Fraction) -> Fraction {
        Fraction(lhs.numerator * rhs.numerator, lhs.denominator * rhs.denominator)
    }

    static func approximate(_ value: Double) -> Fraction? {
        guard value.isFinite, abs(value) < 1e9 else { return nil }
        if abs(value.rounded() - value) < 1e-12 {
            return Fraction(Int64(value.rounded()))
        }

        let sign: Double = value < 0 ? -1 : 1
        var remainder = abs(value)
        var (previousNumerator, numerator) = (Int64(0), Int64(1))
        var (previousDenominator, denominator) = (Int64(1), Int64(0))
        var best: Fraction?

        for _ in 0..<24 {
            let whole = floor(remainder)
            guard whole < 1e9 else { break }

            let nextNumerator = Int64(whole) * numerator + previousNumerator
            let nextDenominator = Int64(whole) * denominator + previousDenominator
            guard nextDenominator != 0, nextDenominator <= 10_000 else { break }

            previousNumerator = numerator
            numerator = nextNumerator
            previousDenominator = denominator
            denominator = nextDenominator

            let candidate = Fraction(sign < 0 ? -numerator : numerator, denominator)
            let approximation = Double(candidate.numerator) / Double(candidate.denominator)
            if abs(approximation - value) <= 1e-9 * max(1, abs(value)) {
                return candidate
            }
            best = candidate

            let fractional = remainder - whole
            if fractional < 1e-12 { break }
            remainder = 1 / fractional
            if !remainder.isFinite || remainder > 1e12 { break }
        }

        guard let best else { return nil }
        let approximation = Double(best.numerator) / Double(best.denominator)
        guard abs(approximation - value) <= 1e-7 * max(1, abs(value)) else { return nil }
        return best
    }
}

private func greatestCommonDivisor(_ lhs: Int64, _ rhs: Int64) -> Int64 {
    var a = abs(lhs)
    var b = abs(rhs)
    while b != 0 {
        let remainder = a % b
        a = b
        b = remainder
    }
    return a
}

// MARK: - Complex numbers for the numeric root finder

private struct Complex {
    var real: Double
    var imaginary: Double

    var magnitude: Double { (real * real + imaginary * imaginary).squareRoot() }

    static func + (lhs: Complex, rhs: Complex) -> Complex {
        Complex(real: lhs.real + rhs.real, imaginary: lhs.imaginary + rhs.imaginary)
    }

    static func - (lhs: Complex, rhs: Complex) -> Complex {
        Complex(real: lhs.real - rhs.real, imaginary: lhs.imaginary - rhs.imaginary)
    }

    static func * (lhs: Complex, rhs: Complex) -> Complex {
        Complex(
            real: lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
            imaginary: lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
        )
    }

    static func / (lhs: Complex, rhs: Complex) -> Complex {
        let denominator = rhs.real * rhs.real + rhs.imaginary * rhs.imaginary
        return Complex(
            real: (lhs.real * rhs.real + lhs.imaginary * rhs.imaginary) / denominator,
            imaginary: (lhs.imaginary * rhs.real - lhs.real * rhs.imaginary) / denominator
        )
    }
}
