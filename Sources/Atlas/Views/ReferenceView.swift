import SwiftUI

struct ReferenceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private struct Item: Identifiable {
        let id = UUID()
        let token: String
        let description: String
    }

    private struct Section: Identifiable {
        let id = UUID()
        let title: String
        let symbol: String
        let items: [Item]
    }

    private var sections: [Section] {
        [
            Section(title: "Basics", symbol: "textformat.abc", items: [
                Item(token: "2 + 3 × 4", description: "Normal precedence: × ÷ bind tighter than + −."),
                Item(token: "2(3 + 4)", description: "Implicit multiplication — also 3x, 2π, (1+2)(3+4)."),
                Item(token: "2^10", description: "Power, right-associative: 2^3^2 = 512."),
                Item(token: "5!", description: "Factorial. Non-integers use the gamma function."),
                Item(token: "50%", description: "Percent. 200 + 10% = 220, 200 × 10% = 20."),
                Item(token: "|−7|", description: "Absolute value bars."),
                Item(token: "√(81)", description: "Square root. Also ∛(27) for cube roots."),
                Item(token: "x = 5", description: "Define a variable, then use it anywhere."),
                Item(token: "ans", description: "The previous answer.")
            ]),
            Section(title: "Trigonometry", symbol: "angle", items: [
                Item(token: "sin(x) cos(x) tan(x)", description: "Respects the DEG / RAD switch in the header."),
                Item(token: "asin · acos · atan", description: "Inverse functions, returned in the current angle mode."),
                Item(token: "sinh · cosh · tanh", description: "Hyperbolic functions, plus asinh, acosh, atanh."),
                Item(token: "sec · csc · cot", description: "Reciprocal trigonometric functions."),
                Item(token: "atan2(y, x)", description: "Two-argument arctangent.")
            ]),
            Section(title: "Logs and powers", symbol: "function", items: [
                Item(token: "ln(x)", description: "Natural logarithm."),
                Item(token: "log(x)", description: "Base-10 logarithm on a calculator."),
                Item(token: "log(x, b)", description: "Logarithm of x in base b."),
                Item(token: "log2(x)", description: "Base-2 logarithm."),
                Item(token: "exp(x) · exp2(x)", description: "eˣ and 2ˣ."),
                Item(token: "sqrt · cbrt · root(n, x)", description: "Square, cube and n-th roots."),
                Item(token: "hypot(a, b)", description: "√(a² + b²) without overflow.")
            ]),
            Section(title: "Rounding and sign", symbol: "ruler", items: [
                Item(token: "abs(x)", description: "Absolute value."),
                Item(token: "sign(x)", description: "−1, 0 or 1."),
                Item(token: "floor · ceil · trunc", description: "Nearest integers in each direction."),
                Item(token: "round(x) · round(x, 2)", description: "Round to an integer or to decimal places."),
                Item(token: "frac(x)", description: "Fractional part."),
                Item(token: "clamp(x, lo, hi)", description: "Constrain a value to a range.")
            ]),
            Section(title: "Combinatorics and number theory", symbol: "square.grid.3x3", items: [
                Item(token: "factorial(n)", description: "Same as n!."),
                Item(token: "ncr(n, r) · npr(n, r)", description: "Combinations and permutations."),
                Item(token: "gcd(a, b) · lcm(a, b)", description: "Greatest common divisor, least common multiple."),
                Item(token: "mod(a, b)", description: "Remainder with truncation."),
                Item(token: "gamma(x) · lgamma(x)", description: "Gamma and log-gamma functions.")
            ]),
            Section(title: "Collections", symbol: "list.number", items: [
                Item(token: "min · max", description: "Smallest or largest of any number of arguments."),
                Item(token: "sum · prod", description: "Add or multiply all arguments."),
                Item(token: "mean · median", description: "Average and middle value."),
                Item(token: "stdev · variance", description: "Sample standard deviation and variance."),
                Item(token: "rand() · rand(a, b)", description: "Random number in [0, 1) or in a range.")
            ]),
            Section(title: "Constants", symbol: "e", items: [
                Item(token: "pi · π", description: "3.14159265358979…"),
                Item(token: "e", description: "2.71828182845905…"),
                Item(token: "tau · τ", description: "2π."),
                Item(token: "phi · φ", description: "The golden ratio, (1 + √5) / 2."),
                Item(token: "inf · infinity", description: "Infinity, usable as a calculus bound.")
            ]),
            Section(title: "Calculus", symbol: "chart.xyaxis.line", items: [
                Item(token: "Derivative", description: "First to fourth order, using Ridders' extrapolation."),
                Item(token: "Integral", description: "Adaptive Simpson; bounds may be ±∞."),
                Item(token: "Limit", description: "Two-sided or one-sided, including limits at infinity."),
                Item(token: "Roots", description: "Every real zero in a search range."),
                Item(token: "Sum · Product", description: "Σ and Π over integer ranges."),
                Item(token: "d/dx x² at x = 3", description: "Gives 6 — the tangent line is drawn on the graph.")
            ])
        ]
    }

    private var filteredSections: [Section] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return sections }
        return sections.compactMap { section in
            let items = section.items.filter {
                $0.token.lowercased().contains(needle) || $0.description.lowercased().contains(needle)
            }
            guard !items.isEmpty else { return nil }
            return Section(title: section.title, symbol: section.symbol, items: items)
        }
    }

    var body: some View {
        ZStack {
            AuroraBackdrop()

            VStack(spacing: 14) {
                header
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(filteredSections) { section in
                            sectionCard(section)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.automatic)
            }
            .padding(18)
        }
        .frame(width: 700, height: 640)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Reference")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text("Everything Atlas can evaluate")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 190)
                .background(
                    Color.primary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            Button("Done") { dismiss() }
                .buttonStyle(.glass)
                .keyboardShortcut(.escape, modifiers: [])
        }
    }

    private func sectionCard(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: section.symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(section.title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(section.items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(item.token)
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 195, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(item.description)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: Theme.cardShape(22))
    }
}
