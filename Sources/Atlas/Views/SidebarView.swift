import AtlasCore
import SwiftUI

struct SidebarView: View {
    @Bindable var model: CalculatorModel
    var focus: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 14) {
            historyCard
            variablesCard
                .frame(maxHeight: 240)
        }
    }

    // MARK: - History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("History")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                if !model.history.isEmpty {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            model.clearHistory()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Clear history")
                }
            }
            .padding(.horizontal, 2)

            if model.history.isEmpty {
                VStack {
                    Spacer(minLength: 0)
                    emptyState(
                        symbol: "sum",
                        title: "No calculations yet",
                        message: "Press = or Return and every answer lands here."
                    )
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(model.history) { entry in
                            HistoryRowView(
                                entry: entry,
                                use: {
                                    model.use(entry: entry)
                                    focus.wrappedValue = true
                                },
                                insertResult: {
                                    model.insertResult(of: entry)
                                    focus.wrappedValue = true
                                },
                                copy: { model.copy(entry.display) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.automatic)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassEffect(.regular, in: Theme.cardShape(26))
    }

    // MARK: - Variables

    private var variablesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "x.squareroot")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Variables")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(model.userVariables.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)

            if model.userVariables.isEmpty {
                VStack {
                    Spacer(minLength: 0)
                    emptyState(
                        symbol: "character.cursor.ibeam",
                        title: "Nothing defined",
                        message: "Type x = 5 above to create a variable."
                    )
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(model.userVariables, id: \.name) { variable in
                            VariableRowView(
                                name: variable.name,
                                value: variable.value,
                                insert: {
                                    model.insertVariable(named: variable.name)
                                    focus.wrappedValue = true
                                },
                                copy: { model.copy(variable.name) },
                                delete: {
                                    withAnimation(.snappy(duration: 0.2)) {
                                        model.deleteVariable(named: variable.name)
                                    }
                                }
                            )
                        }
                    }
                }
                .scrollIndicators(.automatic)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassEffect(.regular, in: Theme.cardShape(26))
    }

    private func emptyState(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

private struct HistoryRowView: View {
    let entry: HistoryEntry
    let use: () -> Void
    let insertResult: () -> Void
    let copy: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: use) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.expression)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 4) {
                    if let name = entry.assignedVariable {
                        Text("\(name) =")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.mint)
                    }
                    Text(entry.display)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            hovering ? Color.primary.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Use Expression", action: use)
            Button("Insert Result", action: insertResult)
            Divider()
            Button("Copy Result", action: copy)
        }
        .help("Reuse this calculation")
    }
}

private struct VariableRowView: View {
    let name: String
    let value: Double
    let insert: () -> Void
    let copy: () -> Void
    let delete: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: insert) {
            HStack(spacing: 8) {
                Text(name)
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                Text("=")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text(NumberText.string(for: value))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            hovering ? Color.primary.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Insert Name", action: insert)
            Button("Copy Name", action: copy)
            Divider()
            Button("Delete Variable", role: .destructive, action: delete)
        }
        .help("Insert this variable")
    }
}
