import AtlasCore
import SwiftUI

struct DisplayView: View {
    @Bindable var model: CalculatorModel
    var focus: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            topRow
                .frame(height: 24)

            TextField(
                "",
                text: $model.expression,
                selection: $model.selection,
                prompt: Text("Type an expression, e.g. 2 + 3 × 4")
            )
            .textFieldStyle(.plain)
            .font(.system(size: 25, weight: .medium, design: .rounded))
            .multilineTextAlignment(.trailing)
            .focused(focus)
            .onSubmit {
                model.evaluate()
                focus.wrappedValue = true
            }
            .onChange(of: model.expression) { _, _ in
                model.justEvaluated = false
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.primary.opacity(0.14), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            resultRow

            footer
                .frame(height: 20)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: Theme.cardShape(30))
    }

    // MARK: - Pieces

    private var topRow: some View {
        HStack(spacing: 8) {
            if case .value(let value, let assigned) = model.evaluation, let assigned {
                Text("\(assigned) ← \(NumberText.string(for: value))")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .glassEffect(.regular.tint(Theme.mint.opacity(0.28)), in: Capsule())
            }

            Spacer()

            if model.answer != 0 || !model.history.isEmpty {
                ansChip
            }
        }
    }

    private var ansChip: some View {
        Button {
            model.insertVariable(named: "ans")
            focus.wrappedValue = true
        } label: {
            HStack(spacing: 5) {
                Text("ans")
                    .foregroundStyle(.secondary)
                Text(NumberText.string(for: model.answer))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .help("Insert the previous answer")
    }

    private var resultRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("=")
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)

            resultContent
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .trailing)
    }

    @ViewBuilder
    private var resultContent: some View {
        switch model.evaluation {
        case .empty:
            Text("0")
                .font(.system(size: 58, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)

        case .value(let value, _):
            Text(NumberText.string(for: value))
                .font(.system(size: 58, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.justEvaluated ? Color.primary : Color.secondary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.22), value: value)

        case .failure(let message):
            if model.isIncompleteExpression {
                Text("…")
                    .font(.system(size: 44, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            } else {
                Text(message)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.coral)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: 420, alignment: .trailing)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let fraction = model.exactFraction {
                Text(fraction)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .glassEffect(.regular.tint(Theme.violet.opacity(0.20)), in: Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Spacer()

            Text(model.angleMode == .degrees ? "degrees" : "radians")
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .animation(.snappy(duration: 0.2), value: model.exactFraction)
        .lineLimit(1)
        .minimumScaleFactor(0.3)
    }
}
