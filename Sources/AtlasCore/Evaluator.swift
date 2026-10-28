import Foundation

public struct EvalContext: Sendable {
    public var variables: [String: Double]
    public var angleMode: AngleMode

    public init(variables: [String: Double] = [:], angleMode: AngleMode = .radians) {
        self.variables = variables
        self.angleMode = angleMode
    }
}

struct Evaluator {
    let context: EvalContext

    func evaluate(_ expression: Expression) throws -> Double {
        switch expression {
        case .number(let value):
            return value

        case .variable(let name):
            if let value = context.variables[name] {
                return value
            }
            if let value = MathConstants.values[name] {
                return value
            }
            throw MathError.unknownIdentifier(name)

        case .unary(let op, let operand):
            let value = try evaluate(operand)
            switch op {
            case "-": return -value
            case "+": return value
            default: throw MathError.unexpectedToken(op)
            }

        case .binary(let op, let lhs, let rhs):
            switch op {
            case "+":
                let left = try evaluate(lhs)
                if case .percent(let percentOperand) = rhs {
                    return left + left * (try evaluate(percentOperand)) / 100
                }
                return left + (try evaluate(rhs))

            case "-":
                let left = try evaluate(lhs)
                if case .percent(let percentOperand) = rhs {
                    return left - left * (try evaluate(percentOperand)) / 100
                }
                return left - (try evaluate(rhs))

            case "*":
                return try evaluate(lhs) * (try evaluate(rhs))

            case "/":
                let denominator = try evaluate(rhs)
                guard denominator != 0 else { throw MathError.divisionByZero }
                return try evaluate(lhs) / denominator

            case "^":
                return try MathFunctions.power(try evaluate(lhs), try evaluate(rhs))

            default:
                throw MathError.unexpectedToken(op)
            }

        case .percent(let operand):
            return try evaluate(operand) / 100

        case .call(let name, let arguments):
            let values = try arguments.map { try evaluate($0) }
            return try MathFunctions.apply(name, values, angleMode: context.angleMode)
        }
    }
}
