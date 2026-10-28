import SwiftUI

struct GlassIconButton: View {
    let symbol: String
    var help: String = ""
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(active ? Theme.accent.opacity(0.30) : nil).interactive(),
            in: Circle()
        )
        .help(help)
    }
}

struct HeaderView: View {
    @Bindable var model: CalculatorModel
    var focus: FocusState<Bool>.Binding

    var body: some View {
        ViewThatFits(in: .horizontal) {
            content(compact: false)
            content(compact: true)
        }
        .frame(height: 38)
    }

    private func content(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 10) {
            brand(compact: compact)

            Spacer(minLength: 8)

            Picker("Mode", selection: $model.mode) {
                ForEach(CalculatorModel.Mode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(compact ? .small : .regular)
            .frame(width: compact ? 248 : 310)

            Button {
                model.toggleAngleMode()
                focus.wrappedValue = model.mode.editsExpression
            } label: {
                Text(model.angleMode.label)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .frame(width: 34, height: 30)
                    .contentTransition(.numericText())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Theme.accent.opacity(0.25)).interactive(), in: Capsule())
            .help("Switch between degrees and radians")

            GlassIconButton(symbol: "book.closed", help: "Function reference") {
                model.showsReference = true
            }

            GlassIconButton(
                symbol: "sparkles",
                help: "AI tutor (⌘K)",
                active: model.showAIPanel
            ) {
                withAnimation(.snappy(duration: 0.28)) {
                    model.toggleAIPanel()
                }
                focus.wrappedValue = model.mode.editsExpression
            }

            GlassIconButton(
                symbol: "sidebar.right",
                help: "Toggle history (⇧⌘H)",
                active: model.showSidebar
            ) {
                withAnimation(.snappy(duration: 0.28)) {
                    model.toggleSidebar()
                }
                focus.wrappedValue = model.mode.editsExpression
            }
        }
        .padding(.leading, 74)
        .padding(.trailing, 2)
    }

    private func brand(compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.gold, Theme.coral, Theme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)
                    .shadow(color: Theme.gold.opacity(0.35), radius: 10, y: 4)

                Image(systemName: "function")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Atlas")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                if !compact {
                    Text("Mathematics · Golden Gate")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize()
        }
    }
}
