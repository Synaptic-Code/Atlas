import AtlasCore
import Observation
import SwiftUI

enum PlotMarker: Equatable {
    case dot(x: Double, label: String)
    case vertical(x: Double)
    case tangent(x: Double, slope: Double)
}

struct CalculusOutcome {
    var detail: String
    var headline: String
    var notes: [String] = []
    var error: String?
    var sample: ((Double) -> Double)?
    var domain: ClosedRange<Double> = -5...5
    var markers: [PlotMarker] = []
    var shade: ClosedRange<Double>?
    var highlightColor: Color = Theme.accent
}

@MainActor
@Observable
final class CalculusModel {
    enum Operation: String, CaseIterable, Identifiable {
        case derivative
        case integral
        case limit
        case roots
        case summation
        case product

        var id: String { rawValue }

        var title: String {
            switch self {
            case .derivative: return "Derivative"
            case .integral: return "Integral"
            case .limit: return "Limit"
            case .roots: return "Roots"
            case .summation: return "Sum"
            case .product: return "Product"
            }
        }

        var glyph: String {
            switch self {
            case .derivative: return "d/dx"
            case .integral: return "∫"
            case .limit: return "lim"
            case .roots: return "x₀"
            case .summation: return "Σ"
            case .product: return "Π"
            }
        }

        var needsPoint: Bool {
            self == .derivative || self == .limit
        }

        var needsBounds: Bool {
            self == .integral || self == .roots || self == .summation || self == .product
        }
    }

    var operation: Operation = .derivative
    var functionText = "x^2"
    var variable = "x"
    var pointText = "2"
    var lowerText = "0"
    var upperText = "1"
    var order = 1
    var direction: LimitDirection = .both

    var outcome: CalculusOutcome?
    var isComputing = false

    var sanitizedVariable: String {
        let trimmed = variable.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let valid = trimmed.filter { $0.isLetter || $0 == "_" }
        return valid.isEmpty ? "x" : String(valid.prefix(6))
    }

    func run(with engine: CalculatorEngine) {
        isComputing = true
        defer { isComputing = false }

        let variableName = sanitizedVariable
        let fallbackSample = (try? engine.calculus(for: functionText, variable: variableName))?.sample

        do {
            guard !functionText.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw MathError.emptyExpression
            }
            let calculus = try engine.calculus(for: functionText, variable: variableName)
            let variableLabel = variableName

            switch operation {
            case .derivative:
                let point = try number(from: pointText, engine: engine, label: "the point")
                let value = try calculus.derivative(at: point, order: order)
                let slope = order == 1 ? value : (try calculus.derivative(at: point))
                var markers: [PlotMarker] = [.vertical(x: point), .tangent(x: point, slope: slope)]
                if value.isFinite {
                    markers.append(.dot(x: point, label: NumberText.string(for: value)))
                }
                outcome = CalculusOutcome(
                    detail: derivativeDetail(point: point, variable: variableLabel),
                    headline: NumberText.string(for: value),
                    sample: calculus.sample,
                    domain: Self.centeredDomain(around: point),
                    markers: markers,
                    highlightColor: Theme.gold
                )

            case .integral:
                let lower = try number(from: lowerText, engine: engine, label: "the lower bound")
                let upper = try number(from: upperText, engine: engine, label: "the upper bound")
                let value = try calculus.integral(from: lower, to: upper)

                var domain = Self.domain(from: lower, to: upper)
                var shade: ClosedRange<Double>?
                if lower.isFinite, upper.isFinite {
                    let low = min(lower, upper)
                    let high = max(lower, upper)
                    shade = low...high
                    domain = Self.paddedDomain(low...high)
                }

                outcome = CalculusOutcome(
                    detail: "∫ \(variableLabel) from \(NumberText.string(for: lower)) to \(NumberText.string(for: upper))",
                    headline: NumberText.string(for: value),
                    sample: calculus.sample,
                    domain: domain,
                    markers: lower.isFinite && upper.isFinite ? [.vertical(x: lower), .vertical(x: upper)] : [],
                    shade: shade,
                    highlightColor: Theme.accent
                )

            case .limit:
                let point = try number(from: pointText, engine: engine, label: "the approach point")
                let value = try calculus.limit(at: point, direction: direction)
                var markers: [PlotMarker] = [.vertical(x: point)]

                let domain: ClosedRange<Double>
                if point.isFinite {
                    domain = Self.centeredDomain(around: point)
                    if value.isFinite {
                        markers.append(.dot(x: point, label: NumberText.string(for: value)))
                    }
                } else if point > 0 {
                    domain = 0...20
                } else {
                    domain = -20...0
                }

                var notes: [String] = []
                if direction == .left { notes.append("Approached from the left.") }
                if direction == .right { notes.append("Approached from the right.") }

                outcome = CalculusOutcome(
                    detail: "lim \(variableLabel) → \(NumberText.string(for: point))",
                    headline: value.isInfinite ? (value > 0 ? "∞" : "−∞") : NumberText.string(for: value),
                    notes: notes,
                    sample: calculus.sample,
                    domain: domain,
                    markers: markers,
                    highlightColor: Theme.violet
                )

            case .roots:
                let lower = try number(from: lowerText, engine: engine, label: "the lower bound")
                let upper = try number(from: upperText, engine: engine, label: "the upper bound")
                let range = min(lower, upper)...max(lower, upper)
                let roots = try calculus.roots(in: range)

                outcome = CalculusOutcome(
                    detail: "Zeros of f(\(variableLabel)) in [\(NumberText.string(for: range.lowerBound)), \(NumberText.string(for: range.upperBound))]",
                    headline: roots.count == 1
                        ? "\(variableLabel) = \(NumberText.string(for: roots[0]))"
                        : "\(roots.count) roots",
                    notes: roots.map { "\(variableLabel) ≈ \(NumberText.string(for: $0))" },
                    sample: calculus.sample,
                    domain: range,
                    markers: roots.map { .dot(x: $0, label: "") },
                    highlightColor: Theme.mint
                )

            case .summation:
                let lower = try number(from: lowerText, engine: engine, label: "the start index")
                let upper = try number(from: upperText, engine: engine, label: "the end index")
                let value = try calculus.summation(from: lower, to: upper)

                outcome = CalculusOutcome(
                    detail: "Σ from \(variableLabel) = \(NumberText.string(for: lower)) to \(NumberText.string(for: upper))",
                    headline: NumberText.string(for: value),
                    sample: calculus.sample,
                    domain: (lower - 1)...(max(upper, lower) + 1),
                    markers: Self.integerMarkers(from: lower, to: upper),
                    highlightColor: Theme.coral
                )

            case .product:
                let lower = try number(from: lowerText, engine: engine, label: "the start index")
                let upper = try number(from: upperText, engine: engine, label: "the end index")
                let value = try calculus.product(from: lower, to: upper)

                outcome = CalculusOutcome(
                    detail: "Π from \(variableLabel) = \(NumberText.string(for: lower)) to \(NumberText.string(for: upper))",
                    headline: NumberText.string(for: value),
                    sample: calculus.sample,
                    domain: (lower - 1)...(max(upper, lower) + 1),
                    markers: Self.integerMarkers(from: lower, to: upper),
                    highlightColor: Theme.gold
                )
            }
        } catch {
            outcome = CalculusOutcome(
                detail: operation.title,
                headline: "—",
                error: error.localizedDescription,
                sample: fallbackSample,
                domain: outcome?.domain ?? -5...5,
                highlightColor: Theme.coral
            )
        }
    }

    // MARK: - Helpers

    private func number(from text: String, engine: CalculatorEngine, label: String) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MathError.domainError("Enter \(label).")
        }
        return try engine.preview(trimmed)
    }

    private func derivativeDetail(point: Double, variable: String) -> String {
        let marks: [String] = ["′", "″", "‴", "⁗"]
        let mark = marks[min(max(order, 1), marks.count) - 1]
        let pointText = NumberText.string(for: point)
        if order == 1 {
            return "d/d\(variable) at \(variable) = \(pointText)"
        }
        return "f\(mark)(\(variable)) at \(variable) = \(pointText)"
    }

    private static func centeredDomain(around point: Double) -> ClosedRange<Double> {
        guard point.isFinite else { return -5...5 }
        let span = max(2.5, abs(point) * 1.6)
        return (point - span)...(point + span)
    }

    private static func paddedDomain(_ range: ClosedRange<Double>) -> ClosedRange<Double> {
        let width = range.upperBound - range.lowerBound
        let pad = max(width * 0.25, 0.5)
        return (range.lowerBound - pad)...(range.upperBound + pad)
    }

    private static func domain(from lower: Double, to upper: Double) -> ClosedRange<Double> {
        guard lower.isFinite, upper.isFinite, lower != upper else { return -10...10 }
        return paddedDomain(min(lower, upper)...max(lower, upper))
    }

    private static func integerMarkers(from lower: Double, to upper: Double) -> [PlotMarker] {
        guard lower.isFinite, upper.isFinite, abs(lower) < 1e7, abs(upper) < 1e7 else { return [] }
        let start = Int(lower.rounded())
        let end = Int(max(upper, lower).rounded())
        guard end >= start, end - start <= 120 else { return [] }
        return (start...end).map { .dot(x: Double($0), label: "") }
    }
}
