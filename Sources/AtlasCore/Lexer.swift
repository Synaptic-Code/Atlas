import Foundation

public struct Token: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case number(Double)
        case identifier(String)
        case symbol(String)
        case end
    }

    public let kind: Kind
    public let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// Turns a human-typed expression into a flat list of tokens.
///
/// The lexer is deliberately forgiving: it accepts the symbols a Mac keyboard produces
/// (`*`, `-`) as well as the typographic ones a calculator UI likes to show (`×`, `−`,
/// `÷`, `√`, `π`). Numbers may be written `12`, `12.5`, `.5` or `1.2e-3`.
public enum Lexer {
    private static let aliases: [Character: String] = [
        "×": "*", "✕": "*", "·": "*", "⋅": "*", "∙": "*",
        "÷": "/", "∕": "/",
        "−": "-", "–": "-", "—": "-",
        "π": "pi", "τ": "tau", "φ": "phi", "ϕ": "phi",
        "∞": "infinity",
        "，": ",", "（": "(", "）": ")"
    ]

    public static func tokenize(_ source: String) throws -> [Token] {
        var characters: [Character] = []
        characters.reserveCapacity(source.count)
        for character in source {
            if let replacement = aliases[character] {
                characters.append(contentsOf: replacement)
            } else {
                characters.append(character)
            }
        }

        var tokens: [Token] = []
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character.isWhitespace {
                index += 1
                continue
            }

            if isDigit(character) || (character == "." && index + 1 < characters.count && isDigit(characters[index + 1])) {
                let start = index
                while index < characters.count, isDigit(characters[index]) {
                    index += 1
                }
                if index < characters.count, characters[index] == "." {
                    index += 1
                    while index < characters.count, isDigit(characters[index]) {
                        index += 1
                    }
                }
                // Only treat `e` as an exponent when digits actually follow, so `2e` still
                // reads as two times Euler's number.
                if index < characters.count, characters[index] == "e" || characters[index] == "E" {
                    var lookahead = index + 1
                    if lookahead < characters.count, characters[lookahead] == "+" || characters[lookahead] == "-" {
                        lookahead += 1
                    }
                    if lookahead < characters.count, isDigit(characters[lookahead]) {
                        lookahead += 1
                        while lookahead < characters.count, isDigit(characters[lookahead]) {
                            lookahead += 1
                        }
                        index = lookahead
                    }
                }
                let text = String(characters[start..<index])
                guard let value = Double(text) else {
                    throw MathError.unexpectedToken(text)
                }
                tokens.append(Token(kind: .number(value), text: text))
                continue
            }

            if isIdentifierStart(character) {
                let start = index
                index += 1
                while index < characters.count, isIdentifierPart(characters[index]) {
                    index += 1
                }
                let text = String(characters[start..<index])
                tokens.append(Token(kind: .identifier(text.lowercased()), text: text))
                continue
            }

            if character == "*", index + 1 < characters.count, characters[index + 1] == "*" {
                tokens.append(Token(kind: .symbol("^"), text: "**"))
                index += 2
                continue
            }

            if "+-*/^(),!%=|√∛".contains(character) {
                tokens.append(Token(kind: .symbol(String(character)), text: String(character)))
                index += 1
                continue
            }

            throw MathError.unexpectedCharacter(character)
        }

        tokens.append(Token(kind: .end, text: ""))
        return tokens
    }

    private static func isDigit(_ character: Character) -> Bool {
        character >= "0" && character <= "9"
    }

    private static func isIdentifierStart(_ character: Character) -> Bool {
        character.isLetter || character == "_"
    }

    private static func isIdentifierPart(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
