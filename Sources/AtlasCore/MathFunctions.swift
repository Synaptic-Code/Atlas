import Foundation
import Darwin

public enum AngleMode: String, CaseIterable, Codable, Sendable {
    case radians
    case degrees

    public var label: String {
        switch self {
        case .radians: return "RAD"
        case .degrees: return "DEG"
        }
    }
}

enum MathConstants {
    static let values: [String: Double] = [
        "pi": .pi,
        "e": M_E,
        "tau": 2 * .pi,
        "phi": (1 + 5.0.squareRoot()) / 2,
        "inf": .infinity,
        "infinity": .infinity,
        "nan": .nan
    ]
}

/// The function library: everything callable as `name(arguments…)`.
enum MathFunctions {
    static let names: Set<String> = [
        "sin", "cos", "tan", "sec", "csc", "cot",
        "asin", "acos", "atan", "atan2", "arcsin", "arccos", "arctan",
        "sinh", "cosh", "tanh", "sech", "csch", "coth",
        "asinh", "acosh", "atanh",
        "ln", "log", "log10", "log2", "exp", "exp2", "sqrt", "cbrt", "root",
        "abs", "sign", "sgn", "floor", "ceil", "round", "trunc", "frac", "fract",
        "gamma", "lgamma", "factorial", "fact",
        "ncr", "npr", "choose", "comb", "perm",
        "gcd", "lcm", "mod", "hypot", "deg", "rad", "clamp", "pow",
        "min", "max", "sum", "prod", "product",
        "mean", "avg", "median", "stdev", "stddev", "variance", "var",
        "rand", "random"
    ]

    static func apply(_ rawName: String, _ args: [Double], angleMode: AngleMode) throws -> Double {
        let name = rawName.lowercased()

        switch name {
        // MARK: Trigonometry
        case "sin":
            try arity(args, 1, name)
            return sinValue(args[0], mode: angleMode)

        case "cos":
            try arity(args, 1, name)
            return cosValue(args[0], mode: angleMode)

        case "tan":
            try arity(args, 1, name)
            return try tanValue(args[0], mode: angleMode)

        case "sec":
            try arity(args, 1, name)
            let c = cosValue(args[0], mode: angleMode)
            guard c != 0 else { throw MathError.domainError("sec is undefined where cos is zero.") }
            return 1 / c

        case "csc":
            try arity(args, 1, name)
            let s = sinValue(args[0], mode: angleMode)
            guard s != 0 else { throw MathError.domainError("csc is undefined where sin is zero.") }
            return 1 / s

        case "cot":
            try arity(args, 1, name)
            let s = sinValue(args[0], mode: angleMode)
            guard s != 0 else { throw MathError.domainError("cot is undefined where sin is zero.") }
            return cosValue(args[0], mode: angleMode) / s

        case "asin", "arcsin":
            try arity(args, 1, name)
            guard args[0] >= -1, args[0] <= 1 else {
                throw MathError.domainError("asin is defined only between -1 and 1.")
            }
            return fromRadians(Darwin.asin(args[0]), mode: angleMode)

        case "acos", "arccos":
            try arity(args, 1, name)
            guard args[0] >= -1, args[0] <= 1 else {
                throw MathError.domainError("acos is defined only between -1 and 1.")
            }
            return fromRadians(Darwin.acos(args[0]), mode: angleMode)

        case "atan", "arctan":
            try arity(args, 1, name)
            return fromRadians(Darwin.atan(args[0]), mode: angleMode)

        case "atan2":
            try arity(args, 2, name)
            return fromRadians(Darwin.atan2(args[0], args[1]), mode: angleMode)

        // MARK: Hyperbolic
        case "sinh":
            try arity(args, 1, name)
            return Darwin.sinh(args[0])
        case "cosh":
            try arity(args, 1, name)
            return Darwin.cosh(args[0])
        case "tanh":
            try arity(args, 1, name)
            return Darwin.tanh(args[0])
        case "sech":
            try arity(args, 1, name)
            return 1 / Darwin.cosh(args[0])
        case "csch":
            try arity(args, 1, name)
            guard args[0] != 0 else { throw MathError.divisionByZero }
            return 1 / Darwin.sinh(args[0])
        case "coth":
            try arity(args, 1, name)
            guard args[0] != 0 else { throw MathError.divisionByZero }
            return Darwin.cosh(args[0]) / Darwin.sinh(args[0])
        case "asinh":
            try arity(args, 1, name)
            return Darwin.asinh(args[0])
        case "acosh":
            try arity(args, 1, name)
            guard args[0] >= 1 else { throw MathError.domainError("acosh is defined only for x ≥ 1.") }
            return Darwin.acosh(args[0])
        case "atanh":
            try arity(args, 1, name)
            guard args[0] > -1, args[0] < 1 else {
                throw MathError.domainError("atanh is defined only between -1 and 1.")
            }
            return Darwin.atanh(args[0])

        // MARK: Logarithms and exponentials
        case "ln":
            try arity(args, 1, name)
            return try logarithm(args[0])
        case "log":
            if args.count == 1 {
                return try logarithmBase(args[0], base: 10)
            } else if args.count == 2 {
                return try logarithmBase(args[0], base: args[1])
            }
            throw MathError.wrongArgumentCount(function: name, expected: "1 or 2", got: args.count)
        case "log10":
            try arity(args, 1, name)
            return try logarithmBase(args[0], base: 10)
        case "log2":
            try arity(args, 1, name)
            return try logarithmBase(args[0], base: 2)
        case "exp":
            try arity(args, 1, name)
            return try checked(Darwin.exp(args[0]))
        case "exp2":
            try arity(args, 1, name)
            return try checked(Darwin.exp2(args[0]))

        // MARK: Powers and roots
        case "sqrt":
            try arity(args, 1, name)
            guard args[0] >= 0 else { throw MathError.domainError("sqrt of a negative number isn’t real.") }
            return Darwin.sqrt(args[0])
        case "cbrt":
            try arity(args, 1, name)
            return Darwin.cbrt(args[0])
        case "root":
            try arity(args, 2, name)
            return try root(index: args[0], of: args[1])
        case "pow":
            try arity(args, 2, name)
            return try power(args[0], args[1])

        // MARK: Rounding and sign
        case "abs":
            try arity(args, 1, name)
            return abs(args[0])
        case "sign", "sgn":
            try arity(args, 1, name)
            if args[0] == 0 { return 0 }
            return args[0] < 0 ? -1 : 1
        case "floor":
            try arity(args, 1, name)
            return args[0].rounded(.down)
        case "ceil":
            try arity(args, 1, name)
            return args[0].rounded(.up)
        case "trunc":
            try arity(args, 1, name)
            return args[0].rounded(.towardZero)
        case "round":
            if args.count == 1 {
                return args[0].rounded(.toNearestOrAwayFromZero)
            } else if args.count == 2 {
                let places = args[1]
                guard abs(places) <= 15 else { throw MathError.domainError("Too many decimal places.") }
                let factor = Darwin.pow(10, places.rounded())
                return (args[0] * factor).rounded(.toNearestOrAwayFromZero) / factor
            }
            throw MathError.wrongArgumentCount(function: name, expected: "1 or 2", got: args.count)
        case "frac", "fract":
            try arity(args, 1, name)
            return args[0] - args[0].rounded(.towardZero)

        // MARK: Combinatorics
        case "gamma":
            try arity(args, 1, name)
            return try checked(Darwin.tgamma(args[0]))
        case "lgamma":
            try arity(args, 1, name)
            return Darwin.lgamma(args[0])
        case "factorial", "fact":
            try arity(args, 1, name)
            return try factorial(args[0])
        case "ncr", "choose", "comb":
            try arity(args, 2, name)
            return try combinations(args[0], args[1])
        case "npr", "perm":
            try arity(args, 2, name)
            return try permutations(args[0], args[1])

        // MARK: Number theory
        case "gcd":
            try atLeast(args, 2, name)
            var result = try integer(args[0], name)
            for argument in args.dropFirst() {
                let value = try integer(argument, name)
                result = greatestCommonDivisor(result, value)
            }
            return Double(result)
        case "lcm":
            try atLeast(args, 2, name)
            var result = try integer(args[0], name)
            for argument in args.dropFirst() {
                let value = try integer(argument, name)
                let divisor = greatestCommonDivisor(result, value)
                if divisor == 0 { return 0 }
                result = abs(result / divisor * value)
            }
            return Double(result)
        case "mod":
            try arity(args, 2, name)
            guard args[1] != 0 else { throw MathError.divisionByZero }
            return Darwin.fmod(args[0], args[1])

        // MARK: Geometry and conversions
        case "hypot":
            try arity(args, 2, name)
            return Darwin.hypot(args[0], args[1])
        case "deg":
            try arity(args, 1, name)
            return args[0] * 180 / .pi
        case "rad":
            try arity(args, 1, name)
            return args[0] * .pi / 180
        case "clamp":
            try arity(args, 3, name)
            return min(max(args[0], args[1]), args[2])

        // MARK: Collections
        case "min":
            try atLeast(args, 1, name)
            return args.min()!
        case "max":
            try atLeast(args, 1, name)
            return args.max()!
        case "sum":
            try atLeast(args, 1, name)
            return args.reduce(0, +)
        case "prod", "product":
            try atLeast(args, 1, name)
            return args.reduce(1, *)
        case "mean", "avg":
            try atLeast(args, 1, name)
            return args.reduce(0, +) / Double(args.count)
        case "median":
            try atLeast(args, 1, name)
            let sorted = args.sorted()
            let middle = sorted.count / 2
            if sorted.count.isMultiple(of: 2) {
                return (sorted[middle - 1] + sorted[middle]) / 2
            }
            return sorted[middle]
        case "variance", "var":
            try atLeast(args, 2, name)
            let average = args.reduce(0, +) / Double(args.count)
            let squares = args.reduce(0) { $0 + ($1 - average) * ($1 - average) }
            return squares / Double(args.count - 1)
        case "stdev", "stddev":
            try atLeast(args, 2, name)
            let average = args.reduce(0, +) / Double(args.count)
            let squares = args.reduce(0) { $0 + ($1 - average) * ($1 - average) }
            return Darwin.sqrt(squares / Double(args.count - 1))

        // MARK: Random
        case "rand", "random":
            if args.isEmpty {
                return Double.random(in: 0..<1)
            } else if args.count == 2 {
                return Double.random(in: min(args[0], args[1])...max(args[0], args[1]))
            }
            throw MathError.wrongArgumentCount(function: name, expected: "0 or 2", got: args.count)

        default:
            throw MathError.unknownFunction(rawName)
        }
    }

    // MARK: - Helpers

    private static func arity(_ args: [Double], _ count: Int, _ name: String) throws {
        guard args.count == count else {
            throw MathError.wrongArgumentCount(function: name, expected: "\(count)", got: args.count)
        }
    }

    private static func atLeast(_ args: [Double], _ count: Int, _ name: String) throws {
        guard args.count >= count else {
            throw MathError.wrongArgumentCount(function: name, expected: "at least \(count)", got: args.count)
        }
    }

    private static func checked(_ value: Double) throws -> Double {
        if value.isNaN { throw MathError.domainError("That function is undefined for this input.") }
        if value.isInfinite { throw MathError.overflow }
        return value
    }

    private static func integer(_ value: Double, _ name: String) throws -> Int64 {
        let rounded = value.rounded()
        guard abs(value - rounded) < 1e-9, abs(rounded) < 9e15 else {
            throw MathError.domainError("\(name)() needs whole numbers.")
        }
        return Int64(rounded)
    }

    private static func greatestCommonDivisor(_ a: Int64, _ b: Int64) -> Int64 {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            let remainder = x % y
            x = y
            y = remainder
        }
        return x
    }

    static func power(_ base: Double, _ exponent: Double) throws -> Double {
        if base < 0, exponent.rounded() != exponent {
            throw MathError.domainError("A negative number raised to a fractional power isn’t real.")
        }
        if base == 0, exponent < 0 {
            throw MathError.divisionByZero
        }
        let result = Darwin.pow(base, exponent)
        if result.isNaN { throw MathError.domainError("That power is undefined.") }
        if result.isInfinite, base.isFinite, exponent.isFinite { throw MathError.overflow }
        return result
    }

    static func root(index n: Double, of value: Double) throws -> Double {
        guard n != 0 else { throw MathError.domainError("The root index can’t be zero.") }
        if value < 0 {
            let isOddInteger = n.rounded() == n && abs(Darwin.fmod(n, 2)) == 1
            guard isOddInteger else {
                throw MathError.domainError("An even root of a negative number isn’t real.")
            }
            return -Darwin.pow(-value, 1 / n)
        }
        return Darwin.pow(value, 1 / n)
    }

    private static func logarithm(_ value: Double) throws -> Double {
        guard value > 0 else { throw MathError.domainError("Logarithms need a positive argument.") }
        return Darwin.log(value)
    }

    private static func logarithmBase(_ value: Double, base: Double) throws -> Double {
        guard value > 0 else { throw MathError.domainError("Logarithms need a positive argument.") }
        guard base > 0, base != 1 else {
            throw MathError.domainError("A logarithm base must be positive and not 1.")
        }
        return Darwin.log(value) / Darwin.log(base)
    }

    private static func factorial(_ value: Double) throws -> Double {
        guard value >= 0 else {
            throw MathError.domainError("Factorials are defined for non-negative numbers.")
        }
        guard value <= 170 else { throw MathError.overflow }
        let result = Darwin.tgamma(value + 1)
        guard result.isFinite else { throw MathError.overflow }
        // Keep whole-number factorials exact; leave the gamma extension untouched.
        if value.rounded() == value {
            return result.rounded()
        }
        return result
    }

    private static func combinations(_ n: Double, _ r: Double) throws -> Double {
        let nn = try integer(n, "ncr")
        let rr = try integer(r, "ncr")
        guard nn >= 0, rr >= 0 else {
            throw MathError.domainError("ncr() needs non-negative whole numbers.")
        }
        guard rr <= nn else { return 0 }
        let value = Darwin.exp(Darwin.lgamma(Double(nn) + 1) - Darwin.lgamma(Double(rr) + 1) - Darwin.lgamma(Double(nn - rr) + 1))
        return value.rounded()
    }

    private static func permutations(_ n: Double, _ r: Double) throws -> Double {
        let nn = try integer(n, "npr")
        let rr = try integer(r, "npr")
        guard nn >= 0, rr >= 0 else {
            throw MathError.domainError("npr() needs non-negative whole numbers.")
        }
        guard rr <= nn else { return 0 }
        let value = Darwin.exp(Darwin.lgamma(Double(nn) + 1) - Darwin.lgamma(Double(nn - rr) + 1))
        return value.rounded()
    }

    // MARK: - Exact-angle trigonometry
    //
    // Calculators that show `sin(180°) = 1.2e-16` feel broken. When the angle is an exact
    // multiple of a quarter turn we return the exact value instead.

    private static func degreeQuadrant(_ degrees: Double) -> Int? {
        let quotient = degrees / 90
        let rounded = quotient.rounded()
        guard abs(quotient - rounded) <= 1e-12 * max(1, abs(quotient)), abs(rounded) <= 1e9 else {
            return nil
        }
        let quadrant = Int(rounded) % 4
        return quadrant >= 0 ? quadrant : quadrant + 4
    }

    private static func radianQuadrant(_ radians: Double) -> Int? {
        let quotient = radians / (.pi / 2)
        let rounded = quotient.rounded()
        guard abs(quotient - rounded) <= 1e-12 * max(1, abs(quotient)), abs(rounded) <= 1e9 else {
            return nil
        }
        let quadrant = Int(rounded) % 4
        return quadrant >= 0 ? quadrant : quadrant + 4
    }

    private static func sinValue(_ angle: Double, mode: AngleMode) -> Double {
        switch mode {
        case .degrees:
            if let quadrant = degreeQuadrant(angle) {
                return [0.0, 1.0, 0.0, -1.0][quadrant]
            }
            return Darwin.sin(angle * .pi / 180)
        case .radians:
            if let quadrant = radianQuadrant(angle) {
                return [0.0, 1.0, 0.0, -1.0][quadrant]
            }
            return Darwin.sin(angle)
        }
    }

    private static func cosValue(_ angle: Double, mode: AngleMode) -> Double {
        switch mode {
        case .degrees:
            if let quadrant = degreeQuadrant(angle) {
                return [1.0, 0.0, -1.0, 0.0][quadrant]
            }
            return Darwin.cos(angle * .pi / 180)
        case .radians:
            if let quadrant = radianQuadrant(angle) {
                return [1.0, 0.0, -1.0, 0.0][quadrant]
            }
            return Darwin.cos(angle)
        }
    }

    private static func tanValue(_ angle: Double, mode: AngleMode) throws -> Double {
        let quadrant: Int?
        switch mode {
        case .degrees:
            quadrant = degreeQuadrant(angle)
            if let quadrant {
                if quadrant.isMultiple(of: 2) { return 0 }
                throw MathError.domainError("tan is undefined at odd multiples of 90°.")
            }
            return Darwin.tan(angle * .pi / 180)
        case .radians:
            quadrant = radianQuadrant(angle)
            if let quadrant {
                if quadrant.isMultiple(of: 2) { return 0 }
                throw MathError.domainError("tan is undefined at odd multiples of π/2.")
            }
            return Darwin.tan(angle)
        }
    }

    private static func fromRadians(_ value: Double, mode: AngleMode) -> Double {
        mode == .degrees ? value * 180 / .pi : value
    }
}
