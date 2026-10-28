import AtlasCore
import SwiftUI

struct CalculusView: View {
    @Bindable var model: CalculatorModel

    var body: some View {
        @Bindable var calculus = model.calculus

        VStack(spacing: 14) {
            operationBar(calculus)
            inputsCard(calculus)
            resultCard(calculus)
            plotCard(calculus)
        }
        .onAppear {
            calculus.run(with: model.engine)
        }
        .onChange(of: calculus.operation) { _, _ in
            calculus.run(with: model.engine)
        }
    }

    // MARK: - Operation picker

    private func operationBar(_ calculus: CalculusModel) -> some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(CalculusModel.Operation.allCases) { operation in
                    let selected = calculus.operation == operation
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            calculus.operation = operation
                        }
                    } label: {
                        VStack(spacing: 1) {
                            Text(operation.glyph)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text(operation.title)
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
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

    // MARK: - Inputs

    private func inputsCard(_ calculus: CalculusModel) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                Text("f(\(calculus.sanitizedVariable))")
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)

                TextField("x^2", text: Binding(
                    get: { calculus.functionText },
                    set: { calculus.functionText = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .onSubmit { calculus.run(with: model.engine) }

                HStack(spacing: 5) {
                    Text("in")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("x", text: Binding(
                        get: { calculus.variable },
                        set: { calculus.variable = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 30)
                    .padding(.vertical, 6)
                    .background(
                        Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                    .onSubmit { calculus.run(with: model.engine) }
                }
            }

            HStack(alignment: .center, spacing: 12) {
                parameterFields(calculus)
                Spacer(minLength: 8)
                calculateButton(calculus)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: Theme.cardShape(24))
    }

    @ViewBuilder
    private func parameterFields(_ calculus: CalculusModel) -> some View {
        switch calculus.operation {
        case .derivative:
            numberField("at", text: binding(calculus, \.pointText))
            orderMenu(calculus)

        case .integral:
            numberField("from", text: binding(calculus, \.lowerText))
            numberField("to", text: binding(calculus, \.upperText))

        case .limit:
            numberField("x →", text: binding(calculus, \.pointText))
            directionMenu(calculus)

        case .roots, .summation, .product:
            numberField(calculus.operation == .roots ? "in" : "from", text: binding(calculus, \.lowerText))
            numberField("to", text: binding(calculus, \.upperText))
        }
    }

    private func numberField(_ label: String, text: Binding<String>, width: CGFloat = 64) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: width)
                .padding(.vertical, 6)
                .background(
                    Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .onSubmit { model.calculus.run(with: model.engine) }
        }
    }

    private func orderMenu(_ calculus: CalculusModel) -> some View {
        Picker("Order", selection: Binding(
            get: { calculus.order },
            set: { calculus.order = $0 }
        )) {
            ForEach(1...4, id: \.self) { order in
                Text("order \(order)").tag(order)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 110)
    }

    private func directionMenu(_ calculus: CalculusModel) -> some View {
        Picker("Side", selection: Binding(
            get: { calculus.direction },
            set: { calculus.direction = $0 }
        )) {
            ForEach(LimitDirection.allCases, id: \.self) { direction in
                Text(direction.label).tag(direction)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 130)
    }

    private func calculateButton(_ calculus: CalculusModel) -> some View {
        Button {
            calculus.run(with: model.engine)
        } label: {
            Label("Calculate", systemImage: "sparkles")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.accent)
        .help("Compute (⌘↩)")
    }

    private func binding(
        _ calculus: CalculusModel,
        _ keyPath: ReferenceWritableKeyPath<CalculusModel, String>
    ) -> Binding<String> {
        Binding(
            get: { calculus[keyPath: keyPath] },
            set: { calculus[keyPath: keyPath] = $0 }
        )
    }

    // MARK: - Result

    @ViewBuilder
    private func resultCard(_ calculus: CalculusModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let outcome = calculus.outcome {
                HStack(spacing: 6) {
                    Circle()
                        .fill(outcome.highlightColor)
                        .frame(width: 6, height: 6)
                    Text(outcome.detail)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(outcome.headline)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .contentTransition(.numericText())

                if let error = outcome.error {
                    Text(error)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.coral)
                        .lineLimit(2)
                } else if !outcome.notes.isEmpty {
                    Text(noteSummary(outcome.notes))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } else {
                Text("Choose an operation and press Calculate.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .glassEffect(.regular, in: Theme.cardShape(24))
        .animation(.snappy(duration: 0.25), value: calculus.outcome?.headline)
    }

    private func noteSummary(_ notes: [String]) -> String {
        let shown = notes.prefix(6).joined(separator: "   ")
        if notes.count > 6 {
            return shown + "   … \(notes.count - 6) more"
        }
        return shown
    }

    // MARK: - Plot

    @ViewBuilder
    private func plotCard(_ calculus: CalculusModel) -> some View {
        Group {
            if let outcome = calculus.outcome, let sample = outcome.sample {
                FunctionPlot(
                    sample: sample,
                    domain: outcome.domain,
                    markers: outcome.markers,
                    shade: outcome.shade,
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
        .frame(minHeight: 190)
        .glassEffect(.regular, in: Theme.cardShape(26))
    }
}
