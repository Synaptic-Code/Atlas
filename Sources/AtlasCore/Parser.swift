import Foundation

/// A parsed mathematical expression.
public indirect enum Expression: Equatable, Sendable {
    case number(Double)
    case variable(String)
    case unary(String, Expression)
    case binary(String, Expression, Expression)
    case call(String, [Expression])
    /// A postfix percent sign. Kept distinct so `200 + 10%` can mean 220.
    case percent(Expression)
}

extension Expression: CustomStringConvertible {
    public var description: String {
        switch self {
        case .number(let value):
            return NumberText.expressionString(value)
        case .variable(let name):
            return name
        case .unary(let op, let operand):
            return "\(op)\(operand)"
        case .binary(let op, let lhs, let rhs):
            return "(\(lhs) \(op) \(rhs))"
        case .call(let name, let arguments):
            return "\(name)(\(arguments.map(\.description).joined(separator: ", ")))"
        case .percent(let operand):
            return "\(operand)%"
        }
    }
}

/// Recursive-descent parser for the expression language.
///
/// Precedence, loosest to tightest:
/// `=` · `+ -` · `* /` (and implicit multiplication) · unary `+ -` · `^` (right assoc) · postfix `! %`
public struct ExpressionParser {
    private let tokens: [Token]
    private var index = 0

    public init(tokens: [Token]) {
        self.tokens = tokens
    }

    public static func parse(tokens: [Token]) throws -> (expression: Expression, assignedVariable: String?) {
        var parser = ExpressionParser(tokens: tokens)
        return try parser.parseProgram()
    }

    public static func parse(_ source: String) throws -> Expression {
        let tokens = try Lexer.tokenize(source)
        return try parse(tokens: tokens).expression
    }

    // MARK: - Cursor

    private var current: Token {
        tokens[min(index, tokens.count - 1)]
    }

    private var lookahead: Token {
        tokens[min(index + 1, tokens.count - 1)]
    }

    @discardableResult
    private mutating func advance() -> Token {
        let token = current
        if index < tokens.count - 1 {
            index += 1
        }
        return token
    }

    private func isSymbol(_ symbol: String) -> Bool {
        current.kind == .symbol(symbol)
    }

    private mutating func match(_ symbol: String) -> Bool {
        guard isSymbol(symbol) else { return false }
        advance()
        return true
    }

    private mutating func expectEnd() throws {
        guard current.kind == .end else {
            if case .symbol(let symbol) = current.kind {
                if symbol == ")" { throw MathError.expectedClosingParenthesis }
                throw MathError.unexpectedToken(symbol)
            }
            throw MathError.unexpectedToken(current.text)
        }
    }

    // MARK: - Grammar

    private mutating func parseProgram() throws -> (Expression, String?) {
        guard current.kind != .end else { throw MathError.emptyExpression }

        if case .identifier(let name) = current.kind, lookahead.kind == .symbol("=") {
            advance() // name
            advance() // =
            guard !Reserved.names.contains(name) else {
                throw MathError.reservedName(name)
            }
            let expression = try parseExpression()
            try expectEnd()
            return (expression, name)
        }

        let expression = try parseExpression()
        try expectEnd()
        return (expression, nil)
    }

    private mutating func parseExpression() throws -> Expression {
        try parseAdditive()
    }

    private mutating func parseAdditive() throws -> Expression {
        var lhs = try parseMultiplicative()
        while isSymbol("+") || isSymbol("-") {
            let op = advance().text
            let rhs = try parseMultiplicative()
            lhs = .binary(op == "-" ? "-" : "+", lhs, rhs)
        }
        return lhs
    }

    private mutating func parseMultiplicative() throws -> Expression {
        var lhs = try parseUnary()
        while true {
            if isSymbol("*") || isSymbol("/") {
                let op = advance().text
                let rhs = try parseUnary()
                lhs = .binary(op, lhs, rhs)
            } else if startsImplicitFactor {
                // `2pi`, `3(4 + 1)`, `(1 + 2)sin(x)`
                let rhs = try parseUnary()
                lhs = .binary("*", lhs, rhs)
            } else {
                return lhs
            }
        }
    }

    private var startsImplicitFactor: Bool {
        switch current.kind {
        case .number, .identifier:
            return true
        case .symbol(let symbol):
            return symbol == "(" || symbol == "√" || symbol == "∛"
        case .end:
            return false
        }
    }

    private mutating func parseUnary() throws -> Expression {
        if isSymbol("-") {
            advance()
            return .unary("-", try parseUnary())
        }
        if isSymbol("+") {
            advance()
            return try parseUnary()
        }
        return try parsePower()
    }

    private mutating func parsePower() throws -> Expression {
        let base = try parsePostfix()
        if match("^") {
            let exponent = try parseUnary()
            return .binary("^", base, exponent)
        }
        return base
    }

    private mutating func parsePostfix() throws -> Expression {
        var expression = try parsePrimary()
        while true {
            if match("!") {
                expression = .call("factorial", [expression])
            } else if match("%") {
                expression = .percent(expression)
            } else {
                return expression
            }
        }
    }

    private mutating func parsePrimary() throws -> Expression {
        switch current.kind {
        case .number(let value):
            advance()
            return .number(value)

        case .identifier(let name):
            advance()
            if match("(") {
                var arguments: [Expression] = []
                if !isSymbol(")") {
                    arguments.append(try parseExpression())
                    while match(",") {
                        arguments.append(try parseExpression())
                    }
                }
                guard match(")") else { throw MathError.expectedClosingParenthesis }
                return .call(name, arguments)
            }
            return .variable(name)

        case .symbol("("):
            advance()
            let inner = try parseExpression()
            guard match(")") else { throw MathError.expectedClosingParenthesis }
            return inner

        case .symbol("|"):
            advance()
            let inner = try parseExpression()
            guard match("|") else { throw MathError.expectedClosingParenthesis }
            return .call("abs", [inner])

        case .symbol("√"):
            advance()
            return .call("sqrt", [try parsePostfix()])

        case .symbol("∛"):
            advance()
            return .call("cbrt", [try parsePostfix()])

        case .symbol(let symbol):
            throw MathError.unexpectedToken(symbol)

        case .end:
            throw MathError.unexpectedEnd
        }
    }
}

/// Names that may not be assigned to, because the engine gives them meaning.
enum Reserved {
    static let names: Set<String> = {
        var names = MathConstants.values.keys.reduce(into: Set<String>()) { $0.insert($1) }
        names.insert("ans")
        names.insert("infinity")
        names.formUnion(MathFunctions.names)
        names.formUnion(["-", "+", "*", "/", "^"])
        return names
    }()
}
