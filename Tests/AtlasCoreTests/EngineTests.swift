import XCTest
@testable import AtlasCore

final class EngineTests: XCTestCase {
    private func evaluate(
        _ source: String,
        angleMode: AngleMode = .degrees,
        variables: [String: Double] = [:]
    ) throws -> Double {
        var engine = CalculatorEngine(variables: variables, angleMode: angleMode)
        return try engine.evaluate(source).value
    }

    // MARK: Arithmetic

    func testBasicArithmetic() throws {
        XCTAssertEqual(try evaluate("1 + 1"), 2)
        XCTAssertEqual(try evaluate("2 + 3 * 4"), 14)
        XCTAssertEqual(try evaluate("(2 + 3) * 4"), 20)
        XCTAssertEqual(try evaluate("10 - 4 - 3"), 3)
        XCTAssertEqual(try evaluate("100 / 4 / 5"), 5)
    }

    func testExponentiation() throws {
        XCTAssertEqual(try evaluate("2 ^ 10"), 1024)
        XCTAssertEqual(try evaluate("2 ^ 3 ^ 2"), 512, "exponentiation is right-associative")
        XCTAssertEqual(try evaluate("-2 ^ 2"), -4, "unary minus binds looser than ^")
        XCTAssertEqual(try evaluate("2 ^ -3"), 0.125)
        XCTAssertEqual(try evaluate("9 ^ 0.5"), 3)
    }

    func testFactorialAndCombinations() throws {
        XCTAssertEqual(try evaluate("5!"), 120)
        XCTAssertEqual(try evaluate("0!"), 1)
        XCTAssertEqual(try evaluate("0.5!"), 0.886226925452758, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("ncr(5, 2)"), 10)
        XCTAssertEqual(try evaluate("npr(5, 2)"), 20)
        XCTAssertEqual(try evaluate("5! / (2! * 3!)"), 10)
    }

    func testPercent() throws {
        XCTAssertEqual(try evaluate("50%"), 0.5, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("200 + 10%"), 220, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("200 - 10%"), 180, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("200 * 10%"), 20, accuracy: 1e-12)
    }

    func testImplicitMultiplication() throws {
        XCTAssertEqual(try evaluate("2pi", angleMode: .radians), 2 * .pi, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("3(4 + 1)"), 15)
        XCTAssertEqual(try evaluate("(1 + 2)(3 + 4)"), 21)
        XCTAssertEqual(try evaluate("2sin(30)"), 1, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("3x", variables: ["x": 2]), 6)
    }

    func testUnicodeInput() throws {
        XCTAssertEqual(try evaluate("6 × 7"), 42)
        XCTAssertEqual(try evaluate("84 ÷ 2"), 42)
        XCTAssertEqual(try evaluate("10 − 3"), 7)
        XCTAssertEqual(try evaluate("√(81)"), 9)
        XCTAssertEqual(try evaluate("2π", angleMode: .radians), 2 * .pi, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("|−7|"), 7)
    }

    // MARK: Functions and constants

    func testTrigonometry() throws {
        XCTAssertEqual(try evaluate("sin(30)"), 0.5, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("cos(60)"), 0.5, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("tan(45)"), 1, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("sin(180)"), 0, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("cos(90)"), 0, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("asin(0.5)"), 30, accuracy: 1e-12)
    }

    func testRadianTrigonometry() throws {
        XCTAssertEqual(try evaluate("sin(pi / 2)", angleMode: .radians), 1, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("cos(pi)", angleMode: .radians), -1, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("sin(pi)", angleMode: .radians), 0, accuracy: 1e-12)
    }

    func testLogarithmsAndRoots() throws {
        XCTAssertEqual(try evaluate("ln(e)"), 1, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("log(1000)"), 3, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("log(8, 2)"), 3, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("log2(1024)"), 10, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("cbrt(−27)"), -3, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("root(3, 27)"), 3, accuracy: 1e-12)
    }

    func testCombinatoricsAndNumberTheory() throws {
        XCTAssertEqual(try evaluate("gcd(48, 18)"), 6)
        XCTAssertEqual(try evaluate("lcm(4, 6)"), 12)
        XCTAssertEqual(try evaluate("mod(17, 5)"), 2)
    }

    func testStatisticsHelpers() throws {
        XCTAssertEqual(try evaluate("mean(1, 2, 3, 4)"), 2.5)
        XCTAssertEqual(try evaluate("median(3, 1, 4, 1, 5)"), 3)
        XCTAssertEqual(try evaluate("sum(1, 2, 3)"), 6)
        XCTAssertEqual(try evaluate("prod(2, 3, 4)"), 24)
    }

    func testConstants() throws {
        XCTAssertEqual(try evaluate("phi"), (1 + 5.0.squareRoot()) / 2, accuracy: 1e-12)
        XCTAssertEqual(try evaluate("tau", angleMode: .radians), 2 * .pi, accuracy: 1e-12)
    }

    // MARK: Variables

    func testAssignments() throws {
        var engine = CalculatorEngine()
        let result = try engine.evaluate("x = 3 + 4")
        XCTAssertEqual(result.assignedVariable, "x")
        XCTAssertEqual(result.value, 7)
        XCTAssertEqual(try engine.evaluate("x * 2").value, 14)
        XCTAssertEqual(try engine.evaluate("ans + 1").value, 15)
    }

    // MARK: Errors

    func testErrors() {
        XCTAssertThrowsError(try evaluate("1 / 0"))
        XCTAssertThrowsError(try evaluate("sqrt(−1)"))
        XCTAssertThrowsError(try evaluate("nonsense(3)"))
        XCTAssertThrowsError(try evaluate("2 +"))
        XCTAssertThrowsError(try evaluate("(1 + 2"))
        XCTAssertThrowsError(try evaluate("pi = 3"))
        XCTAssertThrowsError(try evaluate("sin = 3"))
    }

    func testTrigonometricPoles() {
        XCTAssertThrowsError(try evaluate("tan(90)"))
        XCTAssertThrowsError(try evaluate("csc(0)"))
    }

    // MARK: Calculus

    func testDerivatives() throws {
        let engine = CalculatorEngine(angleMode: .radians)

        let parabola = try engine.calculus(for: "x^2")
        XCTAssertEqual(try parabola.derivative(at: 3), 6, accuracy: 1e-8)

        let sine = try engine.calculus(for: "sin(x)")
        XCTAssertEqual(try sine.derivative(at: 0), 1, accuracy: 1e-8)
        XCTAssertEqual(try sine.derivative(at: .pi / 2), 0, accuracy: 1e-8)

        let exponential = try engine.calculus(for: "e^x")
        XCTAssertEqual(try exponential.derivative(at: 1), M_E, accuracy: 1e-7)

        XCTAssertEqual(try parabola.derivative(at: 2, order: 2), 2, accuracy: 1e-5)
        XCTAssertEqual(try sine.derivative(at: 1, order: 2), -sin(1.0), accuracy: 1e-4)
    }

    func testIntegrals() throws {
        let engine = CalculatorEngine(angleMode: .radians)

        let parabola = try engine.calculus(for: "x^2")
        XCTAssertEqual(try parabola.integral(from: 0, to: 1), 1.0 / 3.0, accuracy: 1e-10)

        let sine = try engine.calculus(for: "sin(x)")
        XCTAssertEqual(try sine.integral(from: 0, to: .pi), 2, accuracy: 1e-9)
        XCTAssertEqual(try sine.integral(from: .pi, to: 0), -2, accuracy: 1e-9)

        let gaussian = try engine.calculus(for: "e^(-x^2)")
        XCTAssertEqual(try gaussian.integral(from: -.infinity, to: .infinity), .pi.squareRoot(), accuracy: 1e-7)
    }

    func testLimits() throws {
        let engine = CalculatorEngine(angleMode: .radians)

        let sinc = try engine.calculus(for: "sin(x) / x")
        XCTAssertEqual(try sinc.limit(at: 0), 1, accuracy: 1e-8)

        let reciprocal = try engine.calculus(for: "1 / x")
        XCTAssertThrowsError(try reciprocal.limit(at: 0))

        let atInfinity = try engine.calculus(for: "1 / x")
        XCTAssertEqual(try atInfinity.limit(at: .infinity), 0, accuracy: 1e-10)

        let quadratic = try engine.calculus(for: "(x^2 - 1) / (x - 1)")
        XCTAssertEqual(try quadratic.limit(at: 1), 2, accuracy: 1e-7)
    }

    func testRoots() throws {
        let engine = CalculatorEngine(angleMode: .radians)
        let quadratic = try engine.calculus(for: "x^2 - 4")
        let roots = try quadratic.roots(in: -10...10)
        XCTAssertEqual(roots.count, 2)
        XCTAssertEqual(roots[0], -2, accuracy: 1e-6)
        XCTAssertEqual(roots[1], 2, accuracy: 1e-6)

        let tangent = try engine.calculus(for: "(x - 1)^2")
        XCTAssertEqual(try tangent.roots(in: -5...5).first ?? .nan, 1, accuracy: 1e-4)

        let none = try engine.calculus(for: "x^2 + 1")
        XCTAssertThrowsError(try none.roots(in: -5...5))
    }

    func testSeries() throws {
        let engine = CalculatorEngine(angleMode: .radians)
        let naturalNumbers = try engine.calculus(for: "n", variable: "n")
        XCTAssertEqual(try naturalNumbers.summation(from: 1, to: 100), 5050)

        let factorialTerms = try engine.calculus(for: "1 / n^2", variable: "n")
        XCTAssertEqual(try factorialTerms.summation(from: 1, to: 10_000), .pi * .pi / 6, accuracy: 1e-3)

        let powers = try engine.calculus(for: "2^n", variable: "n")
        XCTAssertEqual(try powers.product(from: 1, to: 5), 32768)
    }

    func testMoreCalculus() throws {
        let engine = CalculatorEngine(angleMode: .radians)

        let reciprocal = try engine.calculus(for: "1 / x")
        XCTAssertEqual(try reciprocal.integral(from: 1, to: M_E), 1, accuracy: 1e-9)

        let eLimit = try engine.calculus(for: "(1 + 1/x)^x")
        XCTAssertEqual(try eLimit.limit(at: .infinity), M_E, accuracy: 1e-8)

        let exponentialSeries = try engine.calculus(for: "1 / n!", variable: "n")
        XCTAssertEqual(try exponentialSeries.summation(from: 0, to: 18), M_E, accuracy: 1e-10)

        let sine = try engine.calculus(for: "sin(x)")
        let sineRoots = try sine.roots(in: 0...10)
        XCTAssertEqual(sineRoots.count, 4)
        XCTAssertEqual(sineRoots[0], 0, accuracy: 1e-6)
        XCTAssertEqual(sineRoots[1], .pi, accuracy: 1e-6)
        XCTAssertEqual(sineRoots[2], 2 * .pi, accuracy: 1e-6)

        let cubic = try engine.calculus(for: "x^3")
        XCTAssertEqual(try cubic.derivative(at: 2, order: 3), 6, accuracy: 1e-3)
    }

    func testSingularitiesAreRejected() throws {
        let engine = CalculatorEngine(angleMode: .radians)

        // tan has poles at odd multiples of π/2, which must not be reported as roots.
        let tangent = try engine.calculus(for: "tan(x)")
        let tangentRoots = try tangent.roots(in: 0...10)
        XCTAssertEqual(tangentRoots.count, 4)
        XCTAssertEqual(tangentRoots[0], 0, accuracy: 1e-6)
        XCTAssertEqual(tangentRoots[1], .pi, accuracy: 1e-6)
        XCTAssertEqual(tangentRoots[2], 2 * .pi, accuracy: 1e-6)
        XCTAssertEqual(tangentRoots[3], 3 * .pi, accuracy: 1e-6)

        // A vertical asymptote is not a zero.
        let hyperbola = try engine.calculus(for: "1 / x")
        XCTAssertThrowsError(try hyperbola.roots(in: -2...2))

        // A pole makes a two-sided limit diverge.
        XCTAssertThrowsError(try tangent.limit(at: .pi / 2))
    }

    func testMoreArithmetic() throws {
        XCTAssertEqual(try evaluate("0^0"), 1)
        XCTAssertEqual(try evaluate("2^-2"), 0.25)
        XCTAssertThrowsError(try evaluate("(−8)^(1/3)"))
        XCTAssertEqual(try evaluate("mod(17, 5)"), 2)
        XCTAssertEqual(try evaluate("mod(−7, 3)"), -1)
    }

    // MARK: Formatting

    func testFormatting() {
        XCTAssertEqual(NumberText.string(for: 1.0 / 3.0), "0.333333333333")
        XCTAssertEqual(NumberText.string(for: 0.1 + 0.2), "0.3")
        XCTAssertEqual(NumberText.string(for: 1e13), "1×10¹³")
        XCTAssertEqual(NumberText.string(for: 1e-10), "1×10⁻¹⁰")
        XCTAssertEqual(NumberText.string(for: .nan), "undefined")
        XCTAssertEqual(NumberText.string(for: .infinity), "∞")
        XCTAssertEqual(NumberText.fraction(for: 0.75), "3/4")
        XCTAssertEqual(NumberText.fraction(for: 0.1 + 0.2), "3/10")
        XCTAssertNil(NumberText.fraction(for: .pi))
    }

    // MARK: LaTeX input

    func testLaTeXConversion() {
        XCTAssertEqual(LaTeX.expression(from: "2 \\times x^{2}"), "2 * x^2")
        XCTAssertEqual(LaTeX.expression(from: "\\frac{1}{2}x"), "(1)/(2)x")
        XCTAssertEqual(LaTeX.expression(from: "\\sqrt{5}"), "sqrt(5)")
        XCTAssertEqual(LaTeX.expression(from: "\\sqrt[3]{8}"), "root(3, 8)")
        XCTAssertEqual(LaTeX.expression(from: "\\left( x + 1 \\right)^{2}"), "( x + 1 )^2")
        XCTAssertEqual(LaTeX.pretty("x^{2} - 5x + 6 = 0"), "x² − 5x + 6 = 0")
        XCTAssertEqual(LaTeX.pretty("2 * x"), "2 × x")
        XCTAssertEqual(LaTeX.splitEquation("x^{2} = 4").left, "x^2")
        XCTAssertEqual(LaTeX.splitEquation("x^{2} = 4").right, "4")
    }

    // MARK: Algebra

    func testQuadraticRootsAndFactoring() throws {
        let solution = try AlgebraSolver.solve("x^{2} - 5x + 6 = 0")
        XCTAssertEqual(solution.degree, 2)
        XCTAssertEqual(solution.roots.map(\.real).sorted(), [2, 3])
        XCTAssertEqual(solution.discriminant, 1)
        XCTAssertEqual(solution.factoredForm, "(x − 2)(x − 3)")
        XCTAssertEqual(solution.standardForm, "x² − 5x + 6 = 0")
        XCTAssertEqual(solution.vertex?.x ?? .nan, 2.5, accuracy: 1e-12)
        XCTAssertEqual(solution.vertexForm, "(x − 5/2)² − 1/4")
    }

    func testNonMonicQuadratic() throws {
        let solution = try AlgebraSolver.solve("2x^{2} - 3x + 1 = 0")
        XCTAssertEqual(solution.roots.map(\.real).sorted(), [0.5, 1])
        XCTAssertNotNil(solution.factoredForm)
        XCTAssertTrue(solution.factoredForm?.contains("(2x − 1)") == true)
        XCTAssertTrue(solution.factoredForm?.contains("(x − 1)") == true)
    }

    func testFactoredInputAndRepeatedRoot() throws {
        let factored = try AlgebraSolver.solve("(x + 1)(x - 2) = 0")
        XCTAssertEqual(factored.roots.map(\.real).sorted(), [-1, 2])

        let repeated = try AlgebraSolver.solve("(x - 1)^{2} = 0")
        XCTAssertEqual(repeated.roots.count, 1)
        XCTAssertEqual(repeated.roots.first?.multiplicity, 2)
        XCTAssertEqual(repeated.factoredForm, "(x − 1)²")
        XCTAssertTrue(repeated.rootSummary.contains("double root"))
    }

    func testIrrationalAndComplexRoots() throws {
        let irrational = try AlgebraSolver.solve("x^{2} - 2 = 0")
        XCTAssertEqual(irrational.roots.map(\.real).sorted()[0], -2.0.squareRoot(), accuracy: 1e-12)
        XCTAssertNil(irrational.factoredForm)
        XCTAssertTrue(irrational.rootLines.contains { $0.contains("√2") })

        let complex = try AlgebraSolver.solve("x^{2} + 1 = 0")
        XCTAssertEqual(complex.roots.count, 2)
        XCTAssertEqual(complex.roots.map(\.imaginary).sorted(), [-1, 1])
        XCTAssertEqual(complex.rootSummary, "x = ±i")
        XCTAssertNil(complex.factoredForm)
    }

    func testLinearAndCubic() throws {
        let linear = try AlgebraSolver.solve("3x - 6 = 0")
        XCTAssertEqual(linear.roots.first?.real, 2)
        XCTAssertEqual(linear.factoredForm, "3(x − 2)")

        let cubic = try AlgebraSolver.solve("x^{3} - 6x^{2} + 11x - 6 = 0")
        XCTAssertEqual(cubic.roots.map(\.real).sorted(), [1, 2, 3])
        XCTAssertEqual(cubic.factoredForm, "(x − 1)(x − 2)(x − 3)")
    }

    func testFractionalCoefficientsAndEquationHeuristic() throws {
        let fractional = try AlgebraSolver.solve("\\frac{1}{2}x^{2} + 3x - 2 = 0")
        XCTAssertEqual(fractional.standardForm, "x² + 6x − 4 = 0")
        XCTAssertTrue(fractional.rootLines.contains { $0.contains("√13") })

        let heuristic = try AlgebraSolver.solve("y = x^{2} - 4")
        XCTAssertEqual(heuristic.variable, "x")
        XCTAssertEqual(heuristic.roots.map(\.real).sorted(), [-2, 2])
    }

    func testIdentityAndContradiction() throws {
        let identity = try AlgebraSolver.solve("x - x = 0")
        XCTAssertTrue(identity.isIdentity)

        let contradiction = try AlgebraSolver.solve("2 = 3")
        XCTAssertTrue(contradiction.isContradiction)
    }
}
