import AppKit
import AtlasCore
import Observation
import SwiftUI

struct HistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let expression: String
    let value: Double
    let assignedVariable: String?
    let date: Date

    init(
        id: UUID = UUID(),
        expression: String,
        value: Double,
        assignedVariable: String? = nil,
        date: Date = .now
    ) {
        self.id = id
        self.expression = expression
        self.value = value
        self.assignedVariable = assignedVariable
        self.date = date
    }

    var display: String { NumberText.string(for: value) }
}

enum EvaluationState {
    case empty
    case value(Double, assigned: String?)
    case failure(String)

    var value: Double? {
        if case .value(let value, _) = self { return value }
        return nil
    }
}

@MainActor
@Observable
final class CalculatorModel {
    enum Mode: String, CaseIterable, Identifiable, Codable {
        case basic
        case scientific
        case calculus
        case algebra

        var id: String { rawValue }

        var title: String {
            switch self {
            case .basic: return "Basic"
            case .scientific: return "Scientific"
            case .calculus: return "Calculus"
            case .algebra: return "Algebra"
            }
        }

        var symbol: String {
            switch self {
            case .basic: return "plus.forwardslash.minus"
            case .scientific: return "function"
            case .calculus: return "chart.xyaxis.line"
            case .algebra: return "x.squareroot"
            }
        }

        /// Modes that edit the main expression field.
        var editsExpression: Bool {
            self == .basic || self == .scientific
        }

        /// Older builds stored a `settings` mode. Treat anything unrecognised as Basic
        /// instead of failing to decode the whole persisted state.
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Mode(rawValue: raw) ?? .basic
        }
    }

    var mode: Mode = .basic {
        didSet { save() }
    }

    var expression: String = ""
    var selection: TextSelection?
    var justEvaluated = false

    var engine: CalculatorEngine = CalculatorEngine() {
        didSet { save() }
    }

    var history: [HistoryEntry] = [] {
        didSet { save() }
    }

    var showSidebar = true {
        didSet { save() }
    }

    var showAIPanel = false {
        didSet { save() }
    }

    var showsReference = false
    var calculus = CalculusModel()
    var algebra = AlgebraModel()
    var aiChat = AIChatModel()

    private static let storageKey = "atlas.state.v1"
    private static let maximumHistory = 80
    private var isLoading = true

    init() {
        load()
        isLoading = false
    }

    // MARK: - Derived state

    var answer: Double { engine.variables["ans"] ?? 0 }

    var angleMode: AngleMode {
        get { engine.angleMode }
        set { engine.angleMode = newValue }
    }

    var userVariables: [(name: String, value: Double)] { engine.userVariables }

    /// Evaluated on demand so the display can preview the current expression live.
    var evaluation: EvaluationState {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        do {
            let tokens = try Lexer.tokenize(trimmed)
            let (parsed, assignedVariable) = try ExpressionParser.parse(tokens: tokens)
            let value = try engine.value(of: parsed)
            return .value(value, assigned: assignedVariable)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    var exactFraction: String? {
        guard case .value(let value, _) = evaluation else { return nil }
        return NumberText.fraction(for: value)
    }

    /// A compact description of the calculator that the AI tutor can use as context.
    var aiContext: String {
        var lines: [String] = [
            "Angle mode: \(angleMode == .degrees ? "degrees" : "radians")."
        ]

        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            lines.append("Expression in the input field: \(trimmed)")
            switch evaluation {
            case .value(let value, _):
                lines.append("Current result: \(NumberText.expressionString(value))")
            case .failure(let message):
                lines.append("The expression can’t currently be evaluated: \(message)")
            case .empty:
                break
            }
        }

        if !userVariables.isEmpty {
            let list = userVariables.prefix(8)
                .map { "\($0.name) = \(NumberText.expressionString($0.value))" }
                .joined(separator: ", ")
            lines.append("Variables: \(list)")
        }

        if let last = history.first {
            lines.append("Last calculation: \(last.expression) = \(last.display)")
        }

        return lines.joined(separator: "\n")
    }

    /// True while the expression still ends mid-thought, e.g. `2 +` or `sin(`.
    var isIncompleteExpression: Bool {
        guard let last = expression.trimmingCharacters(in: .whitespacesAndNewlines).last else {
            return false
        }
        return "+−-×÷*/^%(,=".contains(last)
    }

    // MARK: - Editing

    func insert(_ text: String) {
        guard !text.isEmpty else { return }

        if justEvaluated {
            // After "=", an operator continues from the answer; anything else starts fresh.
            if Self.continuationPrefixes.contains(where: { text.hasPrefix($0) }) {
                expression = NumberText.expressionString(answer) + text
            } else {
                expression = text
            }
            justEvaluated = false
            selection = TextSelection(insertionPoint: expression.endIndex)
            return
        }

        let offsets = selectedOffsets
        if let offsets {
            let lower = clampedIndex(at: offsets.lower)
            let upper = clampedIndex(at: offsets.upper)
            expression.replaceSubrange(lower..<upper, with: text)
            let caretOffset = offsets.lower + text.count
            selection = TextSelection(insertionPoint: clampedIndex(at: caretOffset))
        } else {
            expression += text
            selection = TextSelection(insertionPoint: expression.endIndex)
        }
    }

    func backspace() {
        justEvaluated = false

        if let offsets = selectedOffsets {
            if offsets.lower < offsets.upper {
                let lower = clampedIndex(at: offsets.lower)
                let upper = clampedIndex(at: offsets.upper)
                expression.removeSubrange(lower..<upper)
                selection = TextSelection(insertionPoint: clampedIndex(at: offsets.lower))
            } else if offsets.lower > 0 {
                let boundary = clampedIndex(at: offsets.lower)
                let previous = expression.index(before: boundary)
                expression.removeSubrange(previous..<boundary)
                selection = TextSelection(insertionPoint: clampedIndex(at: offsets.lower - 1))
            } else {
                selection = TextSelection(insertionPoint: expression.startIndex)
            }
            return
        }

        if !expression.isEmpty {
            expression.removeLast()
        }
        selection = TextSelection(insertionPoint: expression.endIndex)
    }

    func clear() {
        expression = ""
        selection = TextSelection(insertionPoint: expression.startIndex)
        justEvaluated = false
    }

    /// Negates the current expression, or writes a minus sign when the caret sits after
    /// an operator (where wrapping the whole expression would be wrong).
    func negate() {
        justEvaluated = false
        let trimmed = expression.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            expression = "−"
        } else if let last = trimmed.last, "+−×÷*/^%(".contains(last) {
            expression = trimmed + "−"
        } else if trimmed.hasPrefix("−(") && trimmed.hasSuffix(")") {
            expression = String(trimmed.dropFirst(2).dropLast())
        } else {
            expression = "−(" + trimmed + ")"
        }

        selection = TextSelection(insertionPoint: expression.endIndex)
    }

    @discardableResult
    func evaluate() -> Bool {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        do {
            let result = try engine.evaluate(trimmed)
            let entry = HistoryEntry(
                expression: trimmed,
                value: result.value,
                assignedVariable: result.assignedVariable
            )
            history.insert(entry, at: 0)
            if history.count > Self.maximumHistory {
                history.removeLast(history.count - Self.maximumHistory)
            }
            justEvaluated = true
            selection = TextSelection(insertionPoint: expression.endIndex)
            return true
        } catch {
            justEvaluated = false
            return false
        }
    }

    func toggleAngleMode() {
        angleMode = angleMode == .degrees ? .radians : .degrees
    }

    func toggleSidebar() {
        showSidebar.toggle()
        if showSidebar { showAIPanel = false }
    }

    func toggleAIPanel() {
        showAIPanel.toggle()
        if showAIPanel { showSidebar = false }
    }

    func clearVariables() {
        for variable in engine.userVariables {
            engine.removeVariable(named: variable.name)
        }
    }

    func resetEverything() {
        history.removeAll()
        clearVariables()
        engine.setAnswer(0)
        expression = ""
        selection = nil
        justEvaluated = false
        angleMode = .degrees
        mode = .basic
        showSidebar = true
        showAIPanel = false
        aiChat.reset()
    }

    func use(entry: HistoryEntry) {
        justEvaluated = false
        expression = entry.expression
        selection = TextSelection(insertionPoint: expression.endIndex)
    }

    func insertResult(of entry: HistoryEntry) {
        justEvaluated = false
        insert(NumberText.expressionString(entry.value))
    }

    func insertVariable(named name: String) {
        justEvaluated = false
        insert(name)
    }

    func deleteVariable(named name: String) {
        engine.removeVariable(named: name)
    }

    func clearHistory() {
        history.removeAll()
    }

    func copyResult() {
        guard case .value(let value, _) = evaluation else { return }
        copy(NumberText.expressionString(value))
    }

    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Selection helpers

    private var selectedOffsets: (lower: Int, upper: Int)? {
        guard let selection else { return nil }
        switch selection.indices {
        case .selection(let range):
            let lower = expression.distance(from: expression.startIndex, to: range.lowerBound)
            let upper = expression.distance(from: expression.startIndex, to: range.upperBound)
            guard lower >= 0, upper >= lower, upper <= expression.count else { return nil }
            return (lower, upper)
        case .multiSelection(let ranges):
            guard let first = ranges.ranges.first else { return nil }
            let lower = expression.distance(from: expression.startIndex, to: first.lowerBound)
            let upper = expression.distance(from: expression.startIndex, to: first.upperBound)
            guard lower >= 0, upper >= lower, upper <= expression.count else { return nil }
            return (lower, upper)
        @unknown default:
            return nil
        }
    }

    private func clampedIndex(at offset: Int) -> String.Index {
        let clamped = min(max(0, offset), expression.count)
        return expression.index(expression.startIndex, offsetBy: clamped)
    }

    private static let continuationPrefixes = [
        "+", "−", "-", "×", "*", "÷", "/", "^", "%", "!", ")", "]", "²", "³"
    ]

    // MARK: - Persistence

    private struct PersistedState: Codable {
        var history: [HistoryEntry] = []
        var variables: [String: Double] = [:]
        var angleMode: AngleMode = .degrees
        var mode: Mode?
        var showSidebar: Bool = true
        var showAIPanel: Bool?
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan"
        )
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan"
        )
        return decoder
    }

    private func save() {
        guard !isLoading else { return }
        let state = PersistedState(
            history: Array(history.prefix(Self.maximumHistory)),
            variables: engine.variables.filter { $0.key != "ans" },
            angleMode: engine.angleMode,
            mode: mode,
            showSidebar: showSidebar,
            showAIPanel: showAIPanel
        )
        guard let data = try? Self.encoder.encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let state = try? Self.decoder.decode(PersistedState.self, from: data)
        else { return }

        history = state.history
        engine = CalculatorEngine(variables: state.variables, angleMode: state.angleMode)
        mode = state.mode ?? .basic
        showSidebar = state.showSidebar
        showAIPanel = state.showAIPanel ?? false
    }
}
