import Foundation

public struct EvaluationResult: Sendable {
    public let value: Double
    public let expression: Expression
    public let assignedVariable: String?

    public init(value: Double, expression: Expression, assignedVariable: String? = nil) {
        self.value = value
        self.expression = expression
        self.assignedVariable = assignedVariable
    }
}

/// Stateful front door to the engine: holds variables, the angle mode, and `ans`.
public struct CalculatorEngine: Sendable {
    public private(set) var variables: [String: Double]
    public var angleMode: AngleMode

    public init(variables: [String: Double] = [:], angleMode: AngleMode = .degrees) {
        var initial = variables
        if initial["ans"] == nil { initial["ans"] = 0 }
        self.variables = initial
        self.angleMode = angleMode
    }

    /// Parses and evaluates `source`, applying `x = …` assignments to the engine.
    public mutating func evaluate(_ source: String) throws -> EvaluationResult {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MathError.emptyExpression }

        let tokens = try Lexer.tokenize(trimmed)
        let (expression, assignedVariable) = try ExpressionParser.parse(tokens: tokens)
        let value = try Evaluator(context: makeContext()).evaluate(expression)

        if let assignedVariable {
            variables[assignedVariable] = value
        }
        variables["ans"] = value
        return EvaluationResult(value: value, expression: expression, assignedVariable: assignedVariable)
    }

    /// Evaluates without mutating variables — used for live previews.
    public func preview(_ source: String) throws -> Double {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MathError.emptyExpression }
        let expression = try parse(trimmed)
        return try Evaluator(context: makeContext()).evaluate(expression)
    }

    public func parse(_ source: String) throws -> Expression {
        try ExpressionParser.parse(source)
    }

    public func value(of expression: Expression, bindings: [String: Double] = [:]) throws -> Double {
        var variables = variables
        for (name, value) in bindings { variables[name] = value }
        return try Evaluator(context: EvalContext(variables: variables, angleMode: angleMode))
            .evaluate(expression)
    }

    /// Creates a calculus session for `source`, treating `variable` as the free variable.
    public func calculus(for source: String, variable: String = "x") throws -> CalculusEngine {
        let expression = try parse(source)
        return CalculusEngine(
            expression: expression,
            variable: variable.lowercased(),
            variables: variables,
            angleMode: angleMode
        )
    }

    public mutating func setAnswer(_ value: Double) {
        variables["ans"] = value
    }

    public mutating func removeVariable(named name: String) {
        guard name != "ans" else { return }
        variables.removeValue(forKey: name.lowercased())
    }

    public var userVariables: [(name: String, value: Double)] {
        variables
            .filter { $0.key != "ans" }
            .sorted { $0.key < $1.key }
            .map { (name: $0.key, value: $0.value) }
    }

    private func makeContext() -> EvalContext {
        EvalContext(variables: variables, angleMode: angleMode)
    }
}
