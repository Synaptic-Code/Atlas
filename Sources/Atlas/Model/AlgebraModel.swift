import AppKit
import AtlasCore
import Observation
import SwiftUI

struct AlgebraOutcome {
    var headline: String
    var detail: String
    var standardForm: String
    var factoredForm: String?
    var factoredNote: String?
    var rootLines: [String] = []
    var discriminantText: String?
    var vertexText: String?
    var vertexForm: String?
    var notes: [String] = []
    var error: String?
    var sample: ((Double) -> Double)?
    var domain: ClosedRange<Double> = -5...5
    var markers: [PlotMarker] = []
    var highlightColor: Color = Theme.accent
    var solution: AlgebraSolution?
}

@MainActor
@Observable
final class AlgebraModel {
    enum Kind: String, CaseIterable, Identifiable {
        case auto
        case linear
        case quadratic
        case cubic

        var id: String { rawValue }

        var title: String {
            switch self {
            case .auto: return "Auto"
            case .linear: return "Linear"
            case .quadratic: return "Quadratic"
            case .cubic: return "Cubic"
            }
        }

        var glyph: String {
            switch self {
            case .auto: return "≡"
            case .linear: return "x"
            case .quadratic: return "x²"
            case .cubic: return "x³"
            }
        }

        var template: String? {
            switch self {
            case .auto:
                return nil
            case .linear:
                return "2x + 3 = 0"
            case .quadratic:
                return "x^{2} - 5x + 6 = 0"
            case .cubic:
                return "x^{3} - 6x^{2} + 11x - 6 = 0"
            }
        }
    }

    var kind: Kind = .quadratic
    var input: String = Kind.quadratic.template ?? ""
    var outcome: AlgebraOutcome?
    var isSolving = false

    private static let templates = Kind.allCases.compactMap(\.template)

    var prettyInput: String {
        LaTeX.pretty(input.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func select(_ newKind: Kind) {
        let wasTemplate = Self.templates.contains(input)
        kind = newKind
        if let template = newKind.template, input.isEmpty || wasTemplate {
            input = template
        }
    }

    func useExample(_ example: String) {
        input = example
        if let matching = Kind.allCases.first(where: { $0.template == example }) {
            kind = matching
        } else {
            kind = .auto
        }
    }

    func solve(with engine: CalculatorEngine) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            outcome = nil
            return
        }

        isSolving = true
        defer { isSolving = false }

        do {
            let solution = try AlgebraSolver.solve(trimmed, engine: engine)
            outcome = makeOutcome(from: solution)
        } catch {
            outcome = AlgebraOutcome(
                headline: "—",
                detail: "Couldn’t solve this yet",
                standardForm: LaTeX.pretty(trimmed),
                factoredForm: nil,
                factoredNote: nil,
                error: error.localizedDescription,
                domain: -5...5,
                highlightColor: Theme.coral
            )
        }
    }

    func copySummary() {
        guard let outcome else { return }

        var lines: [String] = [outcome.headline, outcome.standardForm]
        if let factored = outcome.factoredForm {
            lines.append("Factored: \(factored)")
        }
        if let vertex = outcome.vertexForm {
            lines.append("Vertex form: \(vertex)")
        }
        if let discriminant = outcome.discriminantText {
            lines.append("Discriminant: \(discriminant)")
        }
        lines.append(contentsOf: outcome.rootLines)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
    }

    // MARK: - Outcome

    private func makeOutcome(from solution: AlgebraSolution) -> AlgebraOutcome {
        let realRoots = solution.roots.filter(\.isReal).map(\.real)
        let imaginaryRoots = solution.roots.filter { !$0.isReal }

        var markers: [PlotMarker] = []
        var anchors: [Double] = []

        for root in realRoots {
            markers.append(.dot(x: root, label: ""))
            anchors.append(root)
        }

        if let vertex = solution.vertex {
            anchors.append(vertex.x)
            let overlapsRoot = realRoots.contains { abs($0 - vertex.x) < 1e-7 }
            if !overlapsRoot {
                markers.append(.dot(x: vertex.x, label: "vertex"))
            }
        }

        let domain: ClosedRange<Double>
        if let low = anchors.min(), let high = anchors.max() {
            let span = high - low
            let padding = max(3, span * 0.8)
            domain = (low - padding)...(high + padding)
        } else if let vertex = solution.vertex {
            domain = (vertex.x - 4)...(vertex.x + 4)
        } else {
            domain = -5...5
        }

        let color: Color
        if !imaginaryRoots.isEmpty {
            color = Theme.violet
        } else if solution.degree == 2 {
            color = Theme.accent
        } else {
            color = Theme.mint
        }

        var detailParts: [String] = []
        detailParts.append(degreeLabel(for: solution.degree))
        detailParts.append(rootDescription(real: realRoots.count, complex: imaginaryRoots.count))
        if let discriminant = solution.discriminantText {
            detailParts.append("Δ = \(discriminant)")
        }

        return AlgebraOutcome(
            headline: solution.rootSummary,
            detail: detailParts.joined(separator: " · "),
            standardForm: solution.standardForm,
            factoredForm: solution.factoredForm.map { $0 + " = 0" },
            factoredNote: solution.factoredNote,
            rootLines: solution.rootLines,
            discriminantText: solution.discriminantText,
            vertexText: solution.vertex?.exactText,
            vertexForm: solution.vertexForm,
            notes: solution.notes,
            sample: { solution.value(at: $0) },
            domain: domain,
            markers: markers,
            highlightColor: color,
            solution: solution
        )
    }

    private func degreeLabel(for degree: Int) -> String {
        switch degree {
        case 0: return "Constant"
        case 1: return "Linear"
        case 2: return "Quadratic"
        case 3: return "Cubic"
        case 4: return "Quartic"
        default: return "Degree \(degree)"
        }
    }

    private func rootDescription(real: Int, complex: Int) -> String {
        let realPart: String
        switch real {
        case 0: realPart = "no real roots"
        case 1: realPart = "1 real root"
        default: realPart = "\(real) real roots"
        }

        guard complex > 0 else { return realPart }
        let complexPart = complex == 2 ? "complex pair" : "\(complex) complex roots"
        return real == 0 ? complexPart : "\(realPart) + \(complexPart)"
    }
}
