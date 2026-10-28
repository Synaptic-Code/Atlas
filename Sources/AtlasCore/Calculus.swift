import Foundation
import Darwin

public enum LimitDirection: String, CaseIterable, Sendable, Codable {
    case both
    case left
    case right

    public var label: String {
        switch self {
        case .both: return "Both sides"
        case .left: return "From the left"
        case .right: return "From the right"
        }
    }
}

/// Numerical calculus over a parsed expression.
///
/// Everything here is evaluated in double precision with adaptive/extrapolated methods,
/// which is the right trade-off for a calculator: fast, dependency free, and accurate to
/// roughly 10–12 significant digits for well-behaved functions.
public struct CalculusEngine: Sendable {
    public let expression: Expression
    public let variable: String
    public let variables: [String: Double]
    public let angleMode: AngleMode

    public init(expression: Expression, variable: String, variables: [String: Double], angleMode: AngleMode) {
        self.expression = expression
        self.variable = variable.lowercased()
        self.variables = variables
        self.angleMode = angleMode
    }

    /// Throwing evaluation at a point.
    public func evaluate(at x: Double) throws -> Double {
        var values = variables
        values[variable] = x
        return try Evaluator(context: EvalContext(variables: values, angleMode: angleMode)).evaluate(expression)
    }

    /// Non-throwing evaluation used internally by the numeric routines; failures become NaN.
    public func sample(_ x: Double) -> Double {
        (try? evaluate(at: x)) ?? .nan
    }

    // MARK: - Differentiation

    public func derivative(at x: Double, order: Int = 1) throws -> Double {
        let n = max(1, min(order, 4))
        let value: Double
        if n == 1 {
            value = Self.ridders(sample, at: x)
        } else {
            value = Self.repeatedDifference(sample, at: x, order: n)
        }
        guard value.isFinite else {
            throw MathError.domainError("The derivative isn’t defined at this point.")
        }
        return NumberText.normalized(value, tolerance: 1e-10)
    }

    /// Ridders' method: central differences plus polynomial extrapolation.
    private static func ridders(_ f: (Double) -> Double, at x: Double) -> Double {
        let con = 1.4
        let con2 = con * con
        let ntab = 10
        var step = 0.01 * max(1, abs(x))
        var table = [[Double]](repeating: [Double](repeating: .nan, count: ntab), count: ntab)

        table[0][0] = (f(x + step) - f(x - step)) / (2 * step)
        var answer = table[0][0]
        var error = Double.infinity

        for column in 1..<ntab {
            step /= con
            table[0][column] = (f(x + step) - f(x - step)) / (2 * step)
            var factor = con2
            for row in 1...column {
                table[row][column] = (table[row - 1][column] * factor - table[row - 1][column - 1]) / (factor - 1)
                factor *= con2
                let candidate = table[row][column]
                guard candidate.isFinite else { continue }
                let candidateError = max(
                    abs(candidate - table[row - 1][column]),
                    abs(candidate - table[row - 1][column - 1])
                )
                if candidateError <= error {
                    error = candidateError
                    answer = candidate
                }
            }
        }
        return answer
    }

    /// Higher-order derivatives via repeated central differences.
    private static func repeatedDifference(_ f: (Double) -> Double, at x: Double, order: Int) -> Double {
        let step = pow(Double.ulpOfOne, 1.0 / Double(order + 2)) * max(1, abs(x))

        func difference(_ x: Double, _ order: Int) -> Double {
            if order == 1 {
                return (f(x + step) - f(x - step)) / (2 * step)
            }
            return (difference(x + step, order - 1) - difference(x - step, order - 1)) / (2 * step)
        }

        return difference(x, order)
    }

    // MARK: - Integration

    public func integral(from a: Double, to b: Double, tolerance: Double = 1e-10) throws -> Double {
        guard a.isFinite || a == -.infinity || a == .infinity else { throw MathError.domainError("Invalid bound.") }
        guard b.isFinite || b == -.infinity || b == .infinity else { throw MathError.domainError("Invalid bound.") }
        guard a != b else { return 0 }

        if a == .infinity || b == -.infinity {
            throw MathError.domainError("That integral runs the wrong way through infinity.")
        }

        let value: Double

        if a == -.infinity, b == .infinity {
            // x = t / (1 − t²) maps (−1, 1) onto the whole real line.
            let limit = 1 - 1e-12
            let integrand: (Double) -> Double = { t in
                let denominator = 1 - t * t
                let x = t / denominator
                return self.sample(x) * (1 + t * t) / (denominator * denominator)
            }
            value = Self.adaptiveSimpson(integrand, -limit, limit, tolerance, maxDepth: 60)
        } else if b == .infinity {
            // x = a + t / (1 − t) maps [0, 1) onto [a, ∞).
            let lower = a
            let integrand: (Double) -> Double = { t in
                let remaining = 1 - t
                return self.sample(lower + t / remaining) / (remaining * remaining)
            }
            value = Self.adaptiveSimpson(integrand, 0, 1 - 1e-12, tolerance, maxDepth: 60)
        } else if a == -.infinity {
            // x = b − t / (1 − t) maps [0, 1) onto (−∞, b].
            let upper = b
            let integrand: (Double) -> Double = { t in
                let remaining = 1 - t
                return self.sample(upper - t / remaining) / (remaining * remaining)
            }
            value = Self.adaptiveSimpson(integrand, 0, 1 - 1e-12, tolerance, maxDepth: 60)
        } else {
            let lower = min(a, b)
            let upper = max(a, b)
            let sign: Double = a <= b ? 1 : -1
            value = sign * Self.adaptiveSimpson(sample, lower, upper, tolerance, maxDepth: 60)
        }

        guard value.isFinite else {
            throw MathError.domainError("The integral didn’t converge — the function may be singular there.")
        }
        return NumberText.normalized(value, tolerance: 1e-10)
    }

    private final class EvaluationCounter {
        var remaining: Int
        init(limit: Int) { remaining = limit }
    }

    private static func adaptiveSimpson(
        _ f: (Double) -> Double,
        _ a: Double,
        _ b: Double,
        _ tolerance: Double,
        maxDepth: Int
    ) -> Double {
        // A pathological integrand must never wedge the UI; bail out to NaN instead.
        let counter = EvaluationCounter(limit: 200_000)
        func evaluate(_ x: Double) -> Double {
            guard counter.remaining > 0 else { return .nan }
            counter.remaining -= 1
            return f(x)
        }

        let fa = evaluate(a)
        let fb = evaluate(b)
        let middle = (a + b) / 2
        let fm = evaluate(middle)
        guard fa.isFinite, fb.isFinite, fm.isFinite else { return .nan }

        let whole = (b - a) / 6 * (fa + 4 * fm + fb)

        func recurse(
            _ a: Double, _ b: Double,
            _ fa: Double, _ fm: Double, _ fb: Double,
            _ whole: Double,
            _ epsilon: Double,
            _ depth: Int
        ) -> Double {
            let middle = (a + b) / 2
            let leftMiddle = (a + middle) / 2
            let rightMiddle = (middle + b) / 2
            let flm = evaluate(leftMiddle)
            let frm = evaluate(rightMiddle)
            guard flm.isFinite, frm.isFinite else { return .nan }

            let left = (middle - a) / 6 * (fa + 4 * flm + fm)
            let right = (b - middle) / 6 * (fm + 4 * frm + fb)
            let delta = left + right - whole

            if depth <= 0 || abs(delta) <= 15 * epsilon {
                return left + right + delta / 15
            }
            return recurse(a, middle, fa, flm, fm, left, epsilon / 2, depth - 1)
                + recurse(middle, b, fm, frm, fb, right, epsilon / 2, depth - 1)
        }

        return recurse(a, b, fa, fm, fb, whole, max(tolerance, 1e-14) * max(1, abs(b - a)), min(maxDepth, 30))
    }

    // MARK: - Limits

    public func limit(at x: Double, direction: LimitDirection = .both) throws -> Double {
        if !x.isFinite {
            // x → ±∞ becomes t → 0 with x = 1/t.
            let reciprocal: (Double) -> Double = { t in
                guard t != 0 else { return .nan }
                return self.sample(1 / t)
            }
            let oneSidedDirection: LimitDirection = x > 0 ? .right : .left
            let value = try Self.finiteLimit(reciprocal, at: 0, direction: oneSidedDirection)
            return value.isInfinite ? value : NumberText.normalized(value, tolerance: 1e-9)
        }

        let value = try Self.finiteLimit(sample, at: x, direction: direction)
        return NumberText.normalized(value, tolerance: 1e-9)
    }

    private static func finiteLimit(
        _ f: (Double) -> Double,
        at x0: Double,
        direction: LimitDirection
    ) throws -> Double {
        func approach(_ sign: Double) -> Double? {
            let initialStep = 0.1 * max(1, abs(x0))
            var steps: [Double] = []
            var values: [Double] = []

            for index in 0..<12 {
                let step = initialStep * pow(0.5, Double(index))
                let value = f(x0 + sign * step)
                if value.isFinite {
                    steps.append(step)
                    values.append(value)
                } else if values.isEmpty {
                    return nil
                }
            }

            guard values.count >= 3 else { return values.last }

            let window = min(7, values.count)
            let xs = Array(steps.suffix(window))
            let ys = Array(values.suffix(window))
            let extrapolated = neville(xs: xs, ys: ys, at: 0)

            // A sequence that keeps growing in magnitude is a divergent limit.
            if !extrapolated.isFinite || abs(extrapolated) > 1e12 {
                guard let last = ys.last else { return nil }
                return last < 0 ? -.infinity : .infinity
            }
            return extrapolated
        }

        switch direction {
        case .left:
            guard let value = approach(-1) else { throw MathError.limitDoesNotExist }
            return value
        case .right:
            guard let value = approach(1) else { throw MathError.limitDoesNotExist }
            return value
        case .both:
            let left = approach(-1)
            let right = approach(1)
            switch (left, right) {
            case let (leftValue?, rightValue?):
                if leftValue.isInfinite || rightValue.isInfinite {
                    if leftValue == rightValue { return leftValue }
                    throw MathError.limitDoesNotExist
                }
                let scale = max(1, abs(leftValue), abs(rightValue))
                if abs(leftValue - rightValue) > 1e-5 * scale {
                    throw MathError.limitDoesNotExist
                }
                return (leftValue + rightValue) / 2
            case let (nil, rightValue?):
                return rightValue
            case let (leftValue?, nil):
                return leftValue
            case (nil, nil):
                throw MathError.domainError("The function isn’t defined near that point.")
            }
        }
    }

    /// Neville's algorithm evaluates the interpolating polynomial at `target` — here used to
    /// extrapolate a sequence of increasingly accurate estimates to zero step size.
    private static func neville(xs: [Double], ys: [Double], at target: Double) -> Double {
        guard xs.count == ys.count, !xs.isEmpty else { return .nan }
        var table = ys
        for column in 1..<xs.count {
            for row in stride(from: xs.count - 1, through: column, by: -1) {
                let denominator = xs[row] - xs[row - column]
                if denominator == 0 { return .nan }
                table[row] = ((target - xs[row - column]) * table[row] - (target - xs[row]) * table[row - 1]) / denominator
            }
        }
        return table[xs.count - 1]
    }

    // MARK: - Roots

    public func roots(in range: ClosedRange<Double>, samples: Int = 400) throws -> [Double] {
        let lower = range.lowerBound
        let upper = range.upperBound
        guard lower.isFinite, upper.isFinite, lower < upper else {
            throw MathError.domainError("Give a finite range with the lower bound first.")
        }
        let count = max(16, samples)
        let step = (upper - lower) / Double(count)

        var found: [Double] = []
        var previousX = lower
        var previousY = sample(lower)

        for index in 1...count {
            let x = lower + Double(index) * step
            let y = sample(x)

            if y.isFinite, previousY.isFinite {
                if y == 0 {
                    appendUnique(x, to: &found)
                } else if previousY == 0 {
                    appendUnique(previousX, to: &found)
                } else if (previousY < 0) != (y < 0) {
                    if let root = bisect(previousX, x), abs(sample(root)) < 1e-5 {
                        appendUnique(root, to: &found)
                    }
                } else if abs(y) < 1e-6 {
                    // A touching root (like x² at 0) has no sign change.
                    if let root = refineTouch(previousX, x, y: y) {
                        appendUnique(root, to: &found)
                    }
                }
            }

            previousX = x
            previousY = y
        }

        guard !found.isEmpty else { throw MathError.noRootsFound }
        return found.sorted()
    }

    private func appendUnique(_ value: Double, to roots: inout [Double]) {
        for existing in roots where abs(existing - value) <= 1e-6 * max(1, abs(value)) {
            return
        }
        roots.append(value)
    }

    private func bisect(_ a: Double, _ b: Double) -> Double? {
        var lower = a
        var upper = b
        var lowerValue = sample(lower)
        guard lowerValue.isFinite else { return nil }

        for _ in 0..<90 {
            let middle = (lower + upper) / 2
            let middleValue = sample(middle)
            guard middleValue.isFinite else { return nil }
            if abs(middleValue) < 1e-14 { return middle }
            if (lowerValue < 0) != (middleValue < 0) {
                upper = middle
            } else {
                lower = middle
                lowerValue = middleValue
            }
            if upper - lower < 1e-14 * max(1, abs(middle)) { break }
        }
        return (lower + upper) / 2
    }

    private func refineTouch(_ a: Double, _ b: Double, y: Double) -> Double? {
        var lower = a
        var upper = b
        var best = (lower + upper) / 2
        var bestValue = abs(sample(best))

        for _ in 0..<80 {
            let leftThird = lower + (upper - lower) / 3
            let rightThird = upper - (upper - lower) / 3
            let leftValue = abs(sample(leftThird))
            let rightValue = abs(sample(rightThird))
            if leftValue < rightValue {
                upper = rightThird
            } else {
                lower = leftThird
            }
            let candidate = (lower + upper) / 2
            let candidateValue = abs(sample(candidate))
            if candidateValue < bestValue {
                best = candidate
                bestValue = candidateValue
            }
        }

        guard bestValue < 1e-7 else { return nil }
        return best
    }

    // MARK: - Series

    public func summation(from a: Double, to b: Double) throws -> Double {
        let (start, end) = try integerRange(from: a, to: b)
        var total = 0.0
        var compensation = 0.0
        for index in start...end {
            let term = sample(Double(index))
            guard term.isFinite else { throw MathError.domainError("The series has an undefined term.") }
            // Kahan summation keeps long series accurate.
            let adjusted = term - compensation
            let next = total + adjusted
            compensation = (next - total) - adjusted
            total = next
        }
        return total
    }

    public func product(from a: Double, to b: Double) throws -> Double {
        let (start, end) = try integerRange(from: a, to: b)
        var total = 1.0
        for index in start...end {
            let term = sample(Double(index))
            guard term.isFinite else { throw MathError.domainError("The product has an undefined term.") }
            total *= term
            if total.isInfinite { throw MathError.overflow }
        }
        return total
    }

    private func integerRange(from a: Double, to b: Double) throws -> (Int, Int) {
        let lower = a.rounded()
        let upper = b.rounded()
        guard abs(a - lower) < 1e-9, abs(b - upper) < 1e-9 else {
            throw MathError.domainError("The index must start and end at whole numbers.")
        }
        guard abs(lower) < 1e7, abs(upper) < 1e7 else {
            throw MathError.domainError("That range is too large.")
        }
        guard lower <= upper else {
            throw MathError.domainError("The end of the range must not be before the start.")
        }
        guard upper - lower < 1_000_000 else {
            throw MathError.domainError("That range has too many terms.")
        }
        return (Int(lower), Int(upper))
    }
}
