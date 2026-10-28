import Foundation

/// Every failure the engine can report, phrased so it can be shown directly to a person.
public enum MathError: Error, Equatable, Sendable {
    case emptyExpression
    case unexpectedCharacter(Character)
    case unexpectedToken(String)
    case unexpectedEnd
    case expectedClosingParenthesis
    case unknownIdentifier(String)
    case unknownFunction(String)
    case wrongArgumentCount(function: String, expected: String, got: Int)
    case reservedName(String)
    case divisionByZero
    case sqrtOfNegativeReal(Double)
    case domainError(String)
    case overflow
    case limitDoesNotExist
    case noRootsFound
    case didNotConverge
}

extension MathError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyExpression:
            return "Nothing to calculate yet."
        case .unexpectedCharacter(let character):
            return "“\(character)” doesn’t belong here."
        case .unexpectedToken(let token):
            return "Unexpected “\(token)”."
        case .unexpectedEnd:
            return "The expression ends too early."
        case .expectedClosingParenthesis:
            return "A closing parenthesis is missing."
        case .unknownIdentifier(let name):
            return "I don’t know “\(name)”."
        case .unknownFunction(let name):
            return "There’s no function called “\(name)”."
        case .wrongArgumentCount(let function, let expected, let got):
            return "\(function)() expects \(expected) argument(s), but got \(got)."
        case .reservedName(let name):
            return "“\(name)” is reserved and can’t be redefined."
        case .divisionByZero:
            return "Division by zero is undefined."
        case .sqrtOfNegativeReal(let value):
            return "Cannot take the square root of a negative real number: \(value)."
        case .domainError(let reason):
            return reason
        case .overflow:
            return "The result is too large to represent."
        case .limitDoesNotExist:
            return "That limit doesn’t exist."
        case .noRootsFound:
            return "No roots were found in that range."
        case .didNotConverge:
            return "The calculation didn’t converge. Try a tighter range."
        }
    }
}
