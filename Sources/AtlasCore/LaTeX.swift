import Foundation

/// A forgiving LaTeX front end for the expression language.
///
/// People naturally type mathematics the way LaTeX writes it — `\frac{1}{2}x^{2}`,
/// `\sqrt{5}`, `\times` — so Atlas converts that to the plain syntax the lexer
/// already understands. The conversion is deliberately permissive: unknown
/// commands are reduced to their names rather than rejected outright.
public enum LaTeX {
    /// Converts LaTeX to the plain expression syntax used by the engine.
    public static func expression(from source: String) -> String {
        var converter = Converter(source: source, pretty: false)
        return converter.run()
    }

    /// Converts LaTeX to a compact, human-readable form with `×`, `√`, `π`, and
    /// Unicode superscripts. Useful for showing what the engine understood.
    public static func pretty(_ source: String) -> String {
        var converter = Converter(source: source, pretty: true)
        return converter.run()
    }

    /// Splits an equation such as `x^{2} - 1 = 0` into its two sides.
    public static func splitEquation(_ source: String) -> (left: String, right: String?) {
        let plain = expression(from: source)
        guard let equals = plain.firstIndex(of: "=") else {
            return (plain, nil)
        }

        let left = String(plain[..<equals]).trimmingCharacters(in: .whitespacesAndNewlines)
        let right = String(plain[plain.index(after: equals)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (left, right.isEmpty ? nil : right)
    }
}

// MARK: - Converter

private struct Converter {
    private let characters: [Character]
    private var index = 0
    private let pretty: Bool

    init(source: String, pretty: Bool) {
        var prepared = source
        for delimiter in ["\\[", "\\]", "\\(", "\\)", "$"] {
            prepared = prepared.replacingOccurrences(of: delimiter, with: "")
        }
        self.characters = Array(prepared)
        self.pretty = pretty
    }

    mutating func run() -> String {
        var output = ""

        while index < characters.count {
            let character = characters[index]
            switch character {
            case "\\":
                output += readCommand()
            case "^":
                output += readSuperscript()
            case "_":
                skipSubscript()
            case "{":
                output += "("
                index += 1
            case "}":
                output += ")"
                index += 1
            case "$", "&":
                index += 1
            case "~":
                output += " "
                index += 1
            case "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "⁰", "¹", "⁻":
                output += readUnicodeSuperscript()
            case "−":
                output += pretty ? "−" : "-"
                index += 1
            case "-":
                output += pretty ? "−" : "-"
                index += 1
            case "*":
                output += pretty ? "×" : "*"
                index += 1
            case "×", "✕":
                output += pretty ? "×" : "*"
                index += 1
            case "·", "⋅", "∙":
                output += pretty ? "·" : "*"
                index += 1
            case "÷", "∕":
                output += "/"
                index += 1
            default:
                output.append(character)
                index += 1
            }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Commands

    private mutating func readCommand() -> String {
        index += 1
        guard index < characters.count else { return "" }

        if !characters[index].isLetter {
            let symbol = characters[index]
            index += 1
            switch symbol {
            case ",", ";", ":", "!", " ":
                return " "
            case "\\":
                return ""
            case "{", "}":
                return symbol == "{" ? "(" : ")"
            default:
                return String(symbol)
            }
        }

        let start = index
        while index < characters.count, characters[index].isLetter {
            index += 1
        }
        let name = String(characters[start..<index]).lowercased()

        switch name {
        case "frac", "dfrac", "tfrac":
            return fraction()
        case "sqrt":
            return squareRoot()
        case "left", "right":
            return delimiter()
        case "text", "textrm", "mathrm", "operatorname", "mathbf", "mathit":
            skipSpaces()
            return group()
        case "times":
            return pretty ? "×" : "*"
        case "cdot", "ast":
            return pretty ? "·" : "*"
        case "div":
            return "÷"
        case "pm":
            return "±"
        case "mp":
            return "∓"
        case "pi":
            return pretty ? "π" : "pi"
        case "tau":
            return pretty ? "τ" : "tau"
        case "phi", "varphi":
            return pretty ? "φ" : "phi"
        case "infty":
            return pretty ? "∞" : "infinity"
        case "le", "leq":
            return "≤"
        case "ge", "geq":
            return "≥"
        case "ne", "neq":
            return "≠"
        case "approx":
            return "≈"
        case "to", "rightarrow":
            return "→"
        case "lvert", "rvert", "vert", "mid":
            return "|"
        case "quad", "qquad", "enspace":
            return " "
        case "degree":
            return "°"
        case "sin", "cos", "tan", "sec", "csc", "cot",
             "sinh", "cosh", "tanh", "sech", "csch", "coth",
             "arcsin", "arccos", "arctan", "asin", "acos", "atan",
             "ln", "log", "exp", "abs", "min", "max", "gcd", "lcm",
             "floor", "ceil", "round", "root", "cbrt":
            return name
        default:
            return name
        }
    }

    private mutating func fraction() -> String {
        skipSpaces()
        let numerator = group()
        skipSpaces()
        let denominator = group()

        if pretty {
            return wrap(numerator) + "/" + wrap(denominator)
        }
        return "(\(numerator))/(\(denominator))"
    }

    private mutating func squareRoot() -> String {
        skipSpaces()
        var rootIndex: String?
        if peek("[") {
            index += 1
            rootIndex = readUntilBracket()
        }

        skipSpaces()
        let radicand = group()

        if let rootIndex, !rootIndex.isEmpty {
            return "root(\(rootIndex), \(radicand))"
        }
        if pretty {
            return "√" + wrap(radicand)
        }
        return "sqrt(\(radicand))"
    }

    private mutating func delimiter() -> String {
        skipSpaces()
        guard index < characters.count else { return "" }

        if characters[index] == "\\" {
            index += 1
            guard index < characters.count else { return "" }
        }

        let symbol = characters[index]
        index += 1
        switch symbol {
        case "(", "[", "\\":
            return "("
        case ")", "]":
            return ")"
        case "|":
            return "|"
        case ".":
            return ""
        case "{":
            return "("
        case "}":
            return ")"
        default:
            return String(symbol)
        }
    }

    // MARK: Superscripts and subscripts

    private mutating func readSuperscript() -> String {
        index += 1
        skipSpaces()
        guard index < characters.count else { return "^" }

        if peek("{") {
            let raw = readBraceGroup()
            let content = LaTeX.expression(from: raw)
            return superscript(for: content)
        }

        var token = ""
        if peek("-") || peek("+") {
            token.append(characters[index])
            index += 1
        }
        while index < characters.count, characters[index].isNumber {
            token.append(characters[index])
            index += 1
        }
        if token.isEmpty || token == "-" || token == "+" {
            if index < characters.count {
                token.append(characters[index])
                index += 1
            }
        }
        return superscript(for: token)
    }

    private mutating func superscript(for content: String) -> String {
        if pretty, let unicode = Self.unicodeSuperscript(content) {
            return unicode
        }
        if Self.isSimple(content) {
            return "^" + content
        }
        return "^(\(content))"
    }

    private mutating func readUnicodeSuperscript() -> String {
        var digits = ""
        while index < characters.count {
            switch characters[index] {
            case "⁰": digits.append("0"); index += 1
            case "¹": digits.append("1"); index += 1
            case "²": digits.append("2"); index += 1
            case "³": digits.append("3"); index += 1
            case "⁴": digits.append("4"); index += 1
            case "⁵": digits.append("5"); index += 1
            case "⁶": digits.append("6"); index += 1
            case "⁷": digits.append("7"); index += 1
            case "⁸": digits.append("8"); index += 1
            case "⁹": digits.append("9"); index += 1
            case "⁻": digits.append("-"); index += 1
            default: return "^" + digits
            }
        }
        return "^" + digits
    }

    private mutating func skipSubscript() {
        index += 1
        skipSpaces()
        guard index < characters.count else { return }
        if peek("{") {
            _ = readBraceGroup()
        } else {
            index += 1
        }
    }

    // MARK: Group reading

    private mutating func group() -> String {
        skipSpaces()
        guard index < characters.count else { return "" }

        if peek("{") {
            let raw = readBraceGroup()
            return LaTeX.expression(from: raw)
        }

        let character = characters[index]
        index += 1
        return LaTeX.expression(from: String(character))
    }

    private mutating func readBraceGroup() -> String {
        guard peek("{") else { return "" }
        index += 1

        var depth = 1
        var raw = ""
        while index < characters.count {
            let character = characters[index]
            if character == "{" {
                depth += 1
                raw.append(character)
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    index += 1
                    return raw
                }
                raw.append(character)
            } else {
                raw.append(character)
            }
            index += 1
        }
        return raw
    }

    private mutating func readUntilBracket() -> String {
        var raw = ""
        while index < characters.count, characters[index] != "]" {
            raw.append(characters[index])
            index += 1
        }
        if index < characters.count { index += 1 }
        return LaTeX.expression(from: raw)
    }

    // MARK: Cursor helpers

    private mutating func skipSpaces() {
        while index < characters.count, characters[index].isWhitespace {
            index += 1
        }
    }

    private func peek(_ character: Character) -> Bool {
        index < characters.count && characters[index] == character
    }

    // MARK: Formatting helpers

    private func wrap(_ text: String) -> String {
        Self.isSimple(text) ? text : "(\(text))"
    }

    private static func isSimple(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        return text.allSatisfy { character in
            character.isLetter || character.isNumber || character == "." || character == "−"
        }
    }

    private static func unicodeSuperscript(_ text: String) -> String? {
        guard !text.isEmpty, text.count <= 4 else { return nil }
        var result = ""
        for character in text {
            switch character {
            case "0": result.append("⁰")
            case "1": result.append("¹")
            case "2": result.append("²")
            case "3": result.append("³")
            case "4": result.append("⁴")
            case "5": result.append("⁵")
            case "6": result.append("⁶")
            case "7": result.append("⁷")
            case "8": result.append("⁸")
            case "9": result.append("⁹")
            case "-": result.append("⁻")
            default: return nil
            }
        }
        return result
    }
}
