import AtlasCore
import SwiftUI

struct AlgebraView: View {
    @Bindable var model: CalculatorModel
    @FocusState private var equationFocused: Bool

    private let examples: [(label: String, latex: String)] = [
        ("x² − 5x + 6", "x^{2} - 5x + 6 = 0"),
        ("(x + 1)(x − 2)", "(x + 1)(x - 2) = 0"),
        ("2x² + 3x − 5", "2x^{2} + 3x - 5 = 0"),
        ("x² + 1", "x^{2} + 1 = 0")
    ]

    var body: some View {
        @Bindable var algebra = model.algebra

        VStack(spacing: 14) {
            kindBar(algebra)
            inputCard(algebra)
            resultCard(algebra)
            plotCard(algebra)
        }
        .onAppear {
            algebra.solve(with: model.engine)
            DispatchQueue.main.async {
                equationFocused = true
            }
        }
        .task(id: algebra.input) {
            do {
                try await Task.sleep(for: .milliseconds(220))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            algebra.solve(with: model.engine)
        }
    }

    // MARK: - Kind picker

    private func kindBar(_ algebra: AlgebraModel) -> some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(AlgebraModel.Kind.allCases) { kind in
                    let selected = algebra.kind == kind
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            algebra.select(kind)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(kind.glyph)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            Text(kind.title)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .contentShape(Theme.keyShape(12))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        selected
                            ? .regular.tint(Theme.accent.opacity(0.32)).interactive()
                            : .identity,
                        in: Theme.keyShape(12)
                    )
                }
            }
            .padding(5)
            .glassEffect(.regular, in: Theme.keyShape(16))
        }
    }

    // MARK: - Input

    private func inputCard(_ algebra: AlgebraModel) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Text("Equation")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("LATEX")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .glassEffect(.regular.tint(Theme.violet.opacity(0.22)), in: Capsule())
            }

            HStack(spacing: 10) {
                TextField(
                    "x^{2} - 5x + 6 = 0",
                    text: Binding(
                        get: { algebra.input },
                        set: { algebra.input = $0 }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .focused($equationFocused)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .onSubmit { algebra.solve(with: model.engine) }

                Button {
                    algebra.solve(with: model.engine)
                } label: {
                    Label("Solve", systemImage: "equal.circle.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)
                .help("Solve (⌘↩)")
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(algebra.prettyInput.isEmpty ? " " : algebra.prettyInput)
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .contentTransition(.opacity)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.snappy(duration: 0.2), value: algebra.prettyInput)

            HStack(spacing: 6) {
                Text("Try")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)

                ForEach(examples, id: \.latex) { example in
                    Button {
                        algebra.useExample(example.latex)
                    } label: {
                        Text(example.label)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Capsule())
                }

                Spacer(minLength: 0)
            }

            Text("LaTeX is accepted — try x^{2}, \\frac{1}{2}, \\sqrt{5}, or \\times.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: Theme.cardShape(24))
    }

    // MARK: - Result

    @ViewBuilder
    private func resultCard(_ algebra: AlgebraModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let outcome = algebra.outcome {
                HStack(spacing: 6) {
                    Circle()
                        .fill(outcome.highlightColor)
                        .frame(width: 6, height: 6)
                    Text(outcome.detail)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if outcome.error == nil {
                        GlassIconButton(
                            symbol: "doc.on.doc",
                            help: "Copy the solution"
                        ) {
                            algebra.copySummary()
                        }
                    }
                }

                Text(outcome.headline)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(2)
                    .minimumScaleFactor(0.45)
                    .contentTransition(.numericText())

                if let error = outcome.error {
                    Text(error)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.coral)
                        .lineLimit(3)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        resultRow("Standard", value: outcome.standardForm)

                        resultRow(
                            "Factored",
                            value: outcome.factoredForm ?? "—",
                            note: outcome.factoredForm == nil ? outcome.factoredNote : nil
                        )

                        if !outcome.rootLines.isEmpty {
                            resultRow("Roots", value: outcome.rootLines.joined(separator: "     "))
                        }

                        if let vertex = outcome.vertexText, let form = outcome.vertexForm {
                            resultRow("Vertex", value: "\(vertex)   ·   \(form)")
                        }

                        if let discriminant = outcome.discriminantText {
                            resultRow("Δ", value: discriminant)
                        }
                    }

                    if !outcome.notes.isEmpty {
                        Text(outcome.notes.prefix(2).joined(separator: "   "))
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                            .padding(.top, 1)
                    }
                }
            } else {
                Text("Choose an equation, type it in LaTeX, and Atlas will find its roots.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 146, alignment: .topLeading)
        .glassEffect(.regular, in: Theme.cardShape(24))
        .animation(.snappy(duration: 0.25), value: algebra.outcome?.headline)
    }

    private func resultRow(_ label: String, value: String, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.tertiary)
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)

                if let note {
                    Text(note)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Plot

    @ViewBuilder
    private func plotCard(_ algebra: AlgebraModel) -> some View {
        Group {
            if let outcome = algebra.outcome,
               outcome.error == nil,
               let sample = outcome.sample {
                FunctionPlot(
                    sample: sample,
                    domain: outcome.domain,
                    markers: outcome.markers,
                    accent: outcome.highlightColor
                )
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("The graph appears here")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.03), in: Theme.cardShape(16))
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 180)
        .glassEffect(.regular, in: Theme.cardShape(26))
    }
}
