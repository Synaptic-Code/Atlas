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
        // A mantissa that rounds up to 10 must carry into the exponent.
        XCTAssertEqual(NumberText.string(for: 9.9999999999999e12), "1×10¹³")
        XCTAssertEqual(NumberText.string(for: -9.9999999999999e12), "-1×10¹³")
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

        // A scale of exactly 1 stays silent in the factored form — no "1(2x + 1)".
        let unitScale = try AlgebraSolver.solve("2x + 1 = 0")
        XCTAssertEqual(unitScale.roots.first?.real ?? .nan, -0.5, accuracy: 1e-12)
        XCTAssertEqual(unitScale.factoredForm, "(2x + 1)")
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

    // MARK: - Complex numbers

    func testComplexLiteralParsing() {
        XCTAssertEqual(ComplexNumber.parse("3i"), ComplexNumber(real: 0, imaginary: 3))
        XCTAssertEqual(ComplexNumber.parse("-3i"), ComplexNumber(real: 0, imaginary: -3))
        XCTAssertEqual(ComplexNumber.parse("i"), .imaginaryUnit)
        XCTAssertEqual(ComplexNumber.parse("-i"), ComplexNumber(real: 0, imaginary: -1))
        XCTAssertEqual(ComplexNumber.parse("1+2i"), ComplexNumber(real: 1, imaginary: 2))
        XCTAssertEqual(ComplexNumber.parse("1 - 2i"), ComplexNumber(real: 1, imaginary: -2))
        XCTAssertEqual(ComplexNumber.parse("2i-3"), ComplexNumber(real: -3, imaginary: 2))
        XCTAssertEqual(ComplexNumber.parse("2.5"), ComplexNumber(real: 2.5, imaginary: 0))
        XCTAssertNil(ComplexNumber.parse("abc"))
    }

    func testComplexPolarParsing() throws {
        // 3∠45° has magnitude 3 at 45°.
        let degrees = try XCTUnwrap(ComplexNumber.parse("3\u{2220}45"))
        XCTAssertEqual(degrees.real, 3 * sqrt(2) / 2, accuracy: 1e-12)
        XCTAssertEqual(degrees.imaginary, 3 * sqrt(2) / 2, accuracy: 1e-12)
        XCTAssertEqual(degrees.asPolar(angleMode: .degrees), "3\u{2220}45\u{00B0}")

        let right = try XCTUnwrap(ComplexNumber.parse("2\u{2220}90"))
        XCTAssertEqual(right.real, 0, accuracy: 1e-12)
        XCTAssertEqual(right.imaginary, 2, accuracy: 1e-12)
    }

    func testComplexDisplayKeepsSign() throws {
        XCTAssertEqual(ComplexNumber(real: 0, imaginary: -3).asRectangular, "-3i")
        XCTAssertEqual(ComplexNumber(real: 0, imaginary: 1).asRectangular, "i")
        XCTAssertEqual(ComplexNumber(real: 0, imaginary: -1).asRectangular, "-i")
        XCTAssertEqual(ComplexNumber(real: 1, imaginary: 2).asRectangular, "1 + 2i")
        XCTAssertEqual(ComplexNumber(real: 1, imaginary: -2).asRectangular, "1 − 2i")
        XCTAssertEqual(ComplexNumber(real: 2.5, imaginary: 0).asRectangular, "2.5")
        // Round-off must not leak into display.
        XCTAssertEqual(try ComplexNumber.sqrt(of: ComplexNumber(real: -4, imaginary: 0)).asRectangular, "2i")
    }

    func testComplexArithmeticIdentities() throws {
        let one = ComplexNumber(real: 1, imaginary: 2)
        let two = ComplexNumber(real: 3, imaginary: 4)

        XCTAssertEqual(one * two, ComplexNumber(real: -5, imaginary: 10))
        let quotient = try one / two
        XCTAssertEqual(quotient.real, 0.44, accuracy: 1e-12)
        XCTAssertEqual(quotient.imaginary, 0.08, accuracy: 1e-12)

        // i² = −1 and (1+i)² = 2i.
        XCTAssertEqual(try ComplexNumber.power(.imaginaryUnit, ComplexNumber(real: 2, imaginary: 0)),
                       ComplexNumber(real: -1, imaginary: 0))
        XCTAssertEqual(try ComplexNumber.power(ComplexNumber(real: 1, imaginary: 1), ComplexNumber(real: 2, imaginary: 0)),
                       ComplexNumber(real: 0, imaginary: 2))

        // Euler: e^{iπ} = −1.
        let euler = ComplexNumber.exp(of: ComplexNumber(real: 0, imaginary: .pi))
        XCTAssertEqual(euler.real, -1, accuracy: 1e-12)
        XCTAssertEqual(euler.imaginary, 0, accuracy: 1e-12)

        XCTAssertThrowsError(try ComplexNumber(real: 0, imaginary: 0) / ComplexNumber(real: 0, imaginary: 0))
        XCTAssertThrowsError(try ComplexNumber.power(ComplexNumber(real: 0, imaginary: 0), ComplexNumber(real: 0, imaginary: 0)))
    }

    func testComplexEngineEvaluation() throws {
        var engine = CalculatorEngine()

        XCTAssertEqual(try engine.evaluateComplex("2 + 3i").value.asRectangular, "2 + 3i")
        XCTAssertEqual(try engine.evaluateComplex("i * i").value.asRectangular, "-1")
        XCTAssertEqual(try engine.evaluateComplex("sqrt(-4)").value.asRectangular, "2i")
        XCTAssertEqual(try engine.evaluateComplex("conj(3 + 4i)").value.asRectangular, "3 − 4i")
        XCTAssertEqual(try engine.evaluateComplex("abs(3 + 4i)").value.asRectangular, "5")
        XCTAssertEqual(try engine.evaluateComplex("im(5 + 2i)").value.asRectangular, "2")
        XCTAssertEqual(try engine.evaluateComplex("re(5 + 2i)").value.asRectangular, "5")
        XCTAssertEqual(try engine.evaluateComplex("arg(i)").value.asRectangular, "90")
        XCTAssertEqual(try engine.evaluateComplex("ln(-1)").value.asRectangular, "3.14159265359i")

        // Real expressions must behave exactly as before.
        XCTAssertEqual(try engine.evaluateComplex("2 + 3 * 4").value.asRectangular, "14")
        XCTAssertEqual(try engine.evaluateComplex("200 + 10%").value.asRectangular, "220")

        // Real-only functions reject a complex argument rather than dropping the imaginary part.
        XCTAssertThrowsError(try engine.evaluateComplex("gcd(3 + 4i, 2)"))
    }

    // MARK: - Matrices

    func testMatrixParsingAndErrors() throws {
        XCTAssertEqual(try Matrix.parse("[1, 2; 3, 4]").description, "[1, 2; 3, 4]")
        XCTAssertEqual(try Matrix.parse("[1, 2; 3, 4]").rows, 2)
        XCTAssertEqual(try Matrix.parse("[1, 2; 3, 4]").columns, 2)
        XCTAssertThrowsError(try Matrix.parse("[1, 2; 3]"))
        XCTAssertThrowsError(try Matrix.parse("[1, x]"))
    }

    func testMatrixArithmetic() throws {
        let a = try Matrix.parse("[1, 2; 3, 4]")
        let b = try Matrix.parse("[5, 6; 7, 8]")

        XCTAssertEqual(try (a + b).description, "[6, 8; 10, 12]")
        XCTAssertEqual(try (b - a).description, "[4, 4; 4, 4]")
        XCTAssertEqual(try a.scaled(by: 2).description, "[2, 4; 6, 8]")
        XCTAssertEqual(try (a * b).description, "[19, 22; 43, 50]")
        XCTAssertEqual(try Matrix.parse("[1, 2, 3; 4, 5, 6]").transposed().description, "[1, 4; 2, 5; 3, 6]")
        XCTAssertEqual(try a.trace, 5)

        // Dimension mismatch must be reported, not guessed at.
        XCTAssertThrowsError(try a * Matrix.parse("[1, 2, 3]"))
        XCTAssertThrowsError(try a + Matrix.parse("[1, 2, 3]"))
    }

    func testMatrixDeterminantAndInverse() throws {
        XCTAssertEqual(try Matrix.parse("[1, 2; 3, 4]").determinant, -2, accuracy: 1e-12)
        XCTAssertEqual(try Matrix.parse("[6, 1, 1; 4, -2, 5; 2, 8, 7]").determinant, -306, accuracy: 1e-9)
        XCTAssertEqual(try Matrix.parse("[1, 2; 2, 4]").determinant, 0, accuracy: 1e-12)

        let inverse = try Matrix.parse("[4, 7; 2, 6]").inverse
        XCTAssertEqual(inverse.description, "[0.6, -0.7; -0.2, 0.4]")

        // A·A⁻¹ = I.
        let original = try Matrix.parse("[4, 7; 2, 6]")
        XCTAssertEqual(try (original * inverse).description, "[1, 0; 0, 1]")

        XCTAssertThrowsError(try Matrix.parse("[1, 2; 2, 4]").inverse)
    }

    func testMatrixSolveAndRREF() throws {
        let solution = try Matrix.parse("[2, 1; 1, 3]").solve([5, 10])
        XCTAssertEqual(solution[0], 1, accuracy: 1e-12)
        XCTAssertEqual(solution[1], 3, accuracy: 1e-12)

        // 3x3: x + y + z = 6, 2y + 5z = -4, 2x + 5y - z = 27 → (5, 3, -2)
        let system = try Matrix.parse("[1, 1, 1; 0, 2, 5; 2, 5, -1]")
        let answer = try system.solve([6, -4, 27])
        XCTAssertEqual(answer[0], 5, accuracy: 1e-9)
        XCTAssertEqual(answer[1], 3, accuracy: 1e-9)
        XCTAssertEqual(answer[2], -2, accuracy: 1e-9)

        XCTAssertThrowsError(try Matrix.parse("[1, 2; 2, 4]").solve([1, 2]))

        let reduced = try Matrix.parse("[1, 2, 3; 4, 5, 6]").reducedRowEchelonForm()
        XCTAssertEqual(reduced.matrix.description, "[1, 0, -1; 0, 1, 2]")
        XCTAssertEqual(reduced.pivotColumns, [0, 1])
    }

    func testMatrixEigenvalues() throws {
        // Symmetric: [2, 1; 1, 2] has eigenvalues 1 and 3.
        let symmetric = try Matrix.parse("[2, 1; 1, 2]")
        XCTAssertTrue(symmetric.isSymmetric)
        let pairs = try symmetric.eigenpairs
        XCTAssertEqual(pairs.count, 2)
        XCTAssertEqual(pairs[0].eigenvalue, 1, accuracy: 1e-9)
        XCTAssertEqual(pairs[1].eigenvalue, 3, accuracy: 1e-9)
        // Eigenvectors are unit length.
        for pair in pairs {
            let norm = sqrt(pair.eigenvector.map { $0 * $0 }.reduce(0, +))
            XCTAssertEqual(norm, 1, accuracy: 1e-9)
        }

        // Diagonal matrix: eigenvalues are the diagonal, in order.
        let diagonal = try Matrix.parse("[2, 0; 0, 3]").eigenpairs
        XCTAssertEqual(diagonal.map(\.eigenvalue), [2, 3])

        // Non-symmetric: the companion matrix of (x−1)(x−2)(x−3) has eigenvalues 1, 2, 3.
        // Exercises the QR path (a similarity transform R·Q, not R·Qᵀ).
        let companion = try Matrix.parse("[0, 0, 6; 1, 0, -11; 0, 1, 6]")
        XCTAssertFalse(companion.isSymmetric)
        let qrValues = try companion.eigenpairs.map(\.eigenvalue).sorted()
        XCTAssertEqual(qrValues.count, 3)
        for (actual, expected) in zip(qrValues, [1.0, 2.0, 3.0]) {
            XCTAssertEqual(actual, expected, accuracy: 1e-7)
        }
    }
}
