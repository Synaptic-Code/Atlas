import Foundation

/// Result of evaluating an expression in complex arithmetic.
///
/// The engine evaluates every expression twice: once in `Double` (the fast, exact
/// real path the whole app already relies on) and, when that path reports a domain
/// error involving the imaginary unit, once here. Keeping the real path untouched
/// means adding complex support cannot regress any existing real calculation.
public struct ComplexEvaluationResult: Sendable {
    public let value: ComplexNumber
    public let expression: Expression
    public let assignedVariable: String?

    public init(value: ComplexNumber, expression: Expression, assignedVariable: String? = nil) {
        self.value = value
        self.expression = expression
        self.assignedVariable = assignedVariable
    }

    /// True when the value has a non-zero imaginary part.
    public var isComplex: Bool { value.imaginary != 0 }
}

/// Evaluates an expression over the complex numbers.
///
/// Delegates every real sub-expression to the existing `Evaluator`, so percentages,
/// variables and the whole function library keep behaving exactly as before; only
/// values that genuinely need an imaginary part switch to `ComplexNumber`.
struct ComplexEvaluator {
    let context: EvalContext

    func evaluate(_ expression: Expression) throws -> ComplexNumber {
        switch expression {
        case .number(let value):
            return ComplexNumber(value)

        case .variable(let name):
            if MathConstants.imaginaryNames.contains(name) {
                return .imaginaryUnit
            }
            if let value = context.variables[name] {
                return ComplexNumber(value)
            }
            if let value = MathConstants.values[name] {
                return ComplexNumber(value)
            }
            throw MathError.unknownIdentifier(name)

        case .unary(let op, let operand):
            let value = try evaluate(operand)
            switch op {
            case "-": return ComplexNumber(real: -value.real, imaginary: -value.imaginary)
            case "+": return value
            default: throw MathError.unexpectedToken(op)
            }

        case .binary(let op, let lhs, let rhs):
            switch op {
            case "+", "-", "*":
                let left = try realOrComplex(lhs)
                let right = try realOrComplex(rhs)
                if case .percent(let percentOperand) = rhs, op != "*" {
                    // Contextual percent on a complex left operand.
                    let fraction = try evaluate(percentOperand) / ComplexNumber(real: 100, imaginary: 0)
                    let delta = left * fraction
                    return op == "+"
                        ? left + delta
                        : ComplexNumber(real: left.real - delta.real, imaginary: left.imaginary - delta.imaginary)
                }
                switch op {
                case "+": return left + right
                case "-": return ComplexNumber(real: left.real - right.real, imaginary: left.imaginary - right.imaginary)
                default: return left * right
                }

            case "/":
                let left = try realOrComplex(lhs)
                let right = try realOrComplex(rhs)
                return try left / right

            case "^":
                let base = try realOrComplex(lhs)
                let exponent = try realOrComplex(rhs)
                return try ComplexNumber.power(base, exponent)

            default:
                throw MathError.unexpectedToken(op)
            }

        case .percent(let operand):
            return try evaluate(operand) / ComplexNumber(real: 100, imaginary: 0)

        case .call(let name, let arguments):
            return try call(name, arguments)
        }
    }

    /// Evaluates a sub-expression, preferring the real path so results stay exact.
    private func realOrComplex(_ expression: Expression) throws -> ComplexNumber {
        if let real = try? Evaluator(context: context).evaluate(expression) {
            return ComplexNumber(real)
        }
        return try evaluate(expression)
    }

    private func call(_ name: String, _ arguments: [Expression]) throws -> ComplexNumber {
        let lowercased = name.lowercased()

        if MathFunctions.complexNames.contains(lowercased) {
            return try complexCall(lowercased, arguments)
        }

        if hasComplexModulus(lowercased), arguments.count == 1 {
            let value = try realOrComplex(arguments[0])
            return ComplexNumber(real: value.magnitude, imaginary: 0)
        }

        // The real fast path may only be used when no argument is actually complex.
        // It used to take `3 + 4i` and silently keep the real part, so `abs(3+4i)`
        // returned 3 and `sin(2+3i)` returned sin(2).
        let hasComplexArgument = arguments.contains { realOrComplexOrNil($0)?.imaginary ?? 0 != 0 }
        if !hasComplexArgument, let real = try? evaluateAsReal(name, arguments) {
            return ComplexNumber(real)
        }

        let values = try arguments.map { try realOrComplex($0) }
        switch lowercased {
        case "sqrt":
            try requireCount(values, 1, lowercased)
            return try ComplexNumber.sqrt(of: values[0])
        case "exp":
            try requireCount(values, 1, lowercased)
            return ComplexNumber.exp(of: values[0])
        case "ln":
            try requireCount(values, 1, lowercased)
            return ComplexNumber.log(of: values[0])
        case "log" where values.count == 1:
            return ComplexNumber.log(of: values[0])
        case "sin":
            try requireCount(values, 1, lowercased)
            return ComplexNumber.sin(of: values[0])
        case "cos":
            try requireCount(values, 1, lowercased)
            return ComplexNumber.cos(of: values[0])
        case "tan":
            try requireCount(values, 1, lowercased)
            return try ComplexNumber.tan(of: values[0])
        default:
            // Any non-real argument to a function the complex path does not know about is a
            // genuine limitation, and saying so is better than returning a misleading real.
            if let offending = values.first(where: { $0.imaginary != 0 }) {
                throw MathError.domainError(
                    "\(lowercased)() does not accept complex arguments (got \(offending.asRectangular))."
                )
            }
            throw MathError.unknownFunction(lowercased)
        }
    }

    /// `abs` is not a "complex helper", but on a complex value it means the modulus.
    private func hasComplexModulus(_ name: String) -> Bool { name == "abs" }

    private func complexCall(_ name: String, _ arguments: [Expression]) throws -> ComplexNumber {
        let values = try arguments.map { try realOrComplex($0) }
        switch name {
        case "conj", "conjugate":
            try requireCount(values, 1, name)
            return values[0].conjugate

        case "arg", "argument":
            try requireCount(values, 1, name)
            let radians = values[0].argument
            if context.angleMode == .degrees {
                return ComplexNumber(real: radians * 180 / Double.pi, imaginary: 0)
            }
            return ComplexNumber(real: radians, imaginary: 0)

        case "re", "real":
            try requireCount(values, 1, name)
            return ComplexNumber(real: values[0].real, imaginary: 0)

        case "im", "imag", "imaginary":
            try requireCount(values, 1, name)
            return ComplexNumber(real: values[0].imaginary, imaginary: 0)

        case "polar":
            try requireCount(values, 1, name)
            return ComplexNumber(real: values[0].magnitude, imaginary: values[0].argument)

        case "rectangular":
            try requireCount(values, 2, name)
            return values[0]

        default:
            throw MathError.unknownFunction(name)
        }
    }

    private func evaluateAsReal(_ name: String, _ arguments: [Expression]) throws -> Double {
        let values = try arguments.map { try realOrComplex($0).real }
        return try MathFunctions.apply(name, values, angleMode: context.angleMode)
    }

    /// `realOrComplex` that reports failure as `nil`.
    private func realOrComplexOrNil(_ expression: Expression) -> ComplexNumber? {
        try? realOrComplex(expression)
    }

    private func requireCount(_ values: [ComplexNumber], _ expected: Int, _ name: String) throws {
        guard values.count == expected else {
            throw MathError.wrongArgumentCount(function: name, expected: "\(expected)", got: values.count)
        }
    }
}

extension CalculatorEngine {
    /// Evaluates `source` over the complex numbers, applying `x = …` assignments.
    ///
    /// This is the complex counterpart of ``evaluate(_:)``. Real expressions still go
    /// through the real evaluator first, so results, rounding and formatting are
    /// identical to the plain calculator for everything that has no imaginary part.
    public mutating func evaluateComplex(_ source: String) throws -> ComplexEvaluationResult {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MathError.emptyExpression }

        let tokens = try Lexer.tokenize(trimmed)
        let (expression, assignedVariable) = try ExpressionParser.parse(tokens: tokens)

        // Try the real path first so the common case is bit-identical to `evaluate`.
        // The guard is explicit rather than relying on the real path failing: `i` used to
        // be present in `MathConstants.values` as 0, so `3i` evaluated to `3 × 0 = 0`
        // without ever reaching the complex branch.
        if !mentionsImaginaryUnit(expression),
           let real = try? Evaluator(context: makeComplexContext()).evaluate(expression) {
            let value = ComplexNumber(real)
            if let assignedVariable { storeVariable(assignedVariable, real) }
            storeVariable("ans", real)
            return ComplexEvaluationResult(value: value, expression: expression, assignedVariable: assignedVariable)
        }

        let value = try ComplexEvaluator(context: makeComplexContext()).evaluate(expression)
        if let assignedVariable {
            guard value.imaginary == 0 else {
                throw MathError.domainError(
                    "Only real values can be stored in variables (got \(value.asRectangular))."
                )
            }
            storeVariable(assignedVariable, value.real)
        }
        storeVariable("ans", value.real)
        return ComplexEvaluationResult(value: value, expression: expression, assignedVariable: assignedVariable)
    }

    private func makeComplexContext() -> EvalContext {
        EvalContext(variables: variables, angleMode: angleMode)
    }

    /// Whether the expression tree refers to `i` or `j` anywhere.
    ///
    /// Scans the AST instead of the raw text so identifiers that merely *contain* an `i`
    /// (like `min` or `imag`) do not falsely trigger the complex path.
    private func mentionsImaginaryUnit(_ expression: Expression) -> Bool {
        switch expression {
        case .number:
            return false
        case .variable(let name):
            return MathConstants.imaginaryNames.contains(name)
        case .unary(_, let operand):
            return mentionsImaginaryUnit(operand)
        case .binary(_, let lhs, let rhs):
            return mentionsImaginaryUnit(lhs) || mentionsImaginaryUnit(rhs)
        case .call(_, let arguments):
            return arguments.contains { mentionsImaginaryUnit($0) }
        case .percent(let operand):
            return mentionsImaginaryUnit(operand)
        }
    }
}
