import SwiftUI

struct KeypadKey: Identifiable, Sendable {
    enum Action: Sendable {
        case insert(String)
        case clear
        case delete
        case evaluate
        case negate
    }

    enum Style: Sendable {
        case digit
        case operation
        case function
        case control
        case equals
    }

    let id: UUID
    let label: String
    var systemImage: String?
    let action: Action
    let style: Style

    init(label: String, systemImage: String? = nil, action: Action, style: Style) {
        self.id = UUID()
        self.label = label
        self.systemImage = systemImage
        self.action = action
        self.style = style
    }
}

extension KeypadKey.Style {
    var fontSize: CGFloat {
        switch self {
        case .digit: return 22
        case .operation: return 24
        case .function: return 13
        case .control: return 14
        case .equals: return 25
        }
    }

    var weight: Font.Weight {
        switch self {
        case .digit: return .medium
        case .operation: return .medium
        case .function: return .semibold
        case .control: return .semibold
        case .equals: return .bold
        }
    }

    var foreground: Color {
        switch self {
        case .digit, .operation, .equals: return .primary
        case .function: return .primary.opacity(0.85)
        case .control: return Theme.coral
        }
    }

    var glass: Glass {
        switch self {
        case .digit:
            return .regular.interactive()
        case .operation:
            return .regular.tint(Theme.accent.opacity(0.30)).interactive()
        case .function:
            return .regular.tint(Theme.violet.opacity(0.18)).interactive()
        case .control:
            return .regular.tint(Theme.coral.opacity(0.22)).interactive()
        case .equals:
            return .regular.tint(Theme.gold.opacity(0.55)).interactive()
        }
    }
}

enum Keypads {
    static let basic: [[KeypadKey]] = [
        [
            KeypadKey(label: "AC", action: .clear, style: .control),
            KeypadKey(label: "Delete", systemImage: "delete.left", action: .delete, style: .control),
            KeypadKey(label: "(", action: .insert("("), style: .function),
            KeypadKey(label: ")", action: .insert(")"), style: .function)
        ],
        [
            KeypadKey(label: "7", action: .insert("7"), style: .digit),
            KeypadKey(label: "8", action: .insert("8"), style: .digit),
            KeypadKey(label: "9", action: .insert("9"), style: .digit),
            KeypadKey(label: "÷", action: .insert("÷"), style: .operation)
        ],
        [
            KeypadKey(label: "4", action: .insert("4"), style: .digit),
            KeypadKey(label: "5", action: .insert("5"), style: .digit),
            KeypadKey(label: "6", action: .insert("6"), style: .digit),
            KeypadKey(label: "×", action: .insert("×"), style: .operation)
        ],
        [
            KeypadKey(label: "1", action: .insert("1"), style: .digit),
            KeypadKey(label: "2", action: .insert("2"), style: .digit),
            KeypadKey(label: "3", action: .insert("3"), style: .digit),
            KeypadKey(label: "−", action: .insert("−"), style: .operation)
        ],
        [
            KeypadKey(label: "±", action: .negate, style: .function),
            KeypadKey(label: "0", action: .insert("0"), style: .digit),
            KeypadKey(label: ".", action: .insert("."), style: .digit),
            KeypadKey(label: "+", action: .insert("+"), style: .operation)
        ],
        [
            KeypadKey(label: "%", action: .insert("%"), style: .function),
            KeypadKey(label: "ans", action: .insert("ans"), style: .function),
            KeypadKey(label: "x²", action: .insert("^2"), style: .function),
            KeypadKey(label: "=", action: .evaluate, style: .equals)
        ]
    ]

    static let scientificPad: [[KeypadKey]] = [
        [
            KeypadKey(label: "sin", action: .insert("sin("), style: .function),
            KeypadKey(label: "cos", action: .insert("cos("), style: .function),
            KeypadKey(label: "tan", action: .insert("tan("), style: .function),
            KeypadKey(label: "ln", action: .insert("ln("), style: .function),
            KeypadKey(label: "log", action: .insert("log("), style: .function)
        ],
        [
            KeypadKey(label: "√", action: .insert("√("), style: .function),
            KeypadKey(label: "x²", action: .insert("^2"), style: .function),
            KeypadKey(label: "xʸ", action: .insert("^"), style: .function),
            KeypadKey(label: "π", action: .insert("π"), style: .function),
            KeypadKey(label: "e", action: .insert("e"), style: .function)
        ],
        [
            KeypadKey(label: "(", action: .insert("("), style: .function),
            KeypadKey(label: ")", action: .insert(")"), style: .function),
            KeypadKey(label: "x!", action: .insert("!"), style: .function),
            KeypadKey(label: "1/x", action: .insert("1/("), style: .function),
            KeypadKey(label: "ans", action: .insert("ans"), style: .function)
        ]
    ]

    static let scientificNumbers: [[KeypadKey]] = [
        [
            KeypadKey(label: "AC", action: .clear, style: .control),
            KeypadKey(label: "Delete", systemImage: "delete.left", action: .delete, style: .control),
            KeypadKey(label: "%", action: .insert("%"), style: .function),
            KeypadKey(label: "÷", action: .insert("÷"), style: .operation)
        ],
        [
            KeypadKey(label: "7", action: .insert("7"), style: .digit),
            KeypadKey(label: "8", action: .insert("8"), style: .digit),
            KeypadKey(label: "9", action: .insert("9"), style: .digit),
            KeypadKey(label: "×", action: .insert("×"), style: .operation)
        ],
        [
            KeypadKey(label: "4", action: .insert("4"), style: .digit),
            KeypadKey(label: "5", action: .insert("5"), style: .digit),
            KeypadKey(label: "6", action: .insert("6"), style: .digit),
            KeypadKey(label: "−", action: .insert("−"), style: .operation)
        ],
        [
            KeypadKey(label: "1", action: .insert("1"), style: .digit),
            KeypadKey(label: "2", action: .insert("2"), style: .digit),
            KeypadKey(label: "3", action: .insert("3"), style: .digit),
            KeypadKey(label: "+", action: .insert("+"), style: .operation)
        ],
        [
            KeypadKey(label: "±", action: .negate, style: .function),
            KeypadKey(label: "0", action: .insert("0"), style: .digit),
            KeypadKey(label: ".", action: .insert("."), style: .digit),
            KeypadKey(label: "=", action: .evaluate, style: .equals)
        ]
    ]
}

struct CalcKeyView: View {
    let key: KeypadKey
    var fixedHeight: CGFloat?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label
                .font(.system(size: key.style.fontSize, weight: key.style.weight, design: .rounded))
                .foregroundStyle(key.style.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity)
                .frame(height: fixedHeight)
                .frame(maxHeight: fixedHeight == nil ? .infinity : nil)
                .contentShape(Theme.keyShape())
        }
        .buttonStyle(.plain)
        .glassEffect(key.style.glass, in: Theme.keyShape())
        .accessibilityLabel(key.label)
        .scaleEffect(hovering ? 1.025 : 1)
        .animation(.snappy(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var label: some View {
        if let systemImage = key.systemImage {
            Image(systemName: systemImage)
        } else {
            Text(key.label)
        }
    }
}

struct KeypadView: View {
    @Bindable var model: CalculatorModel
    var focus: FocusState<Bool>.Binding

    private var rows: [[KeypadKey]] {
        model.mode == .scientific ? Keypads.scientificNumbers : Keypads.basic
    }

    var body: some View {
        GlassEffectContainer(spacing: 3) {
            VStack(spacing: 9) {
                if model.mode == .scientific {
                    scientificPad
                }
                numberPad
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var scientificPad: some View {
        VStack(spacing: 8) {
            ForEach(Array(Keypads.scientificPad.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row) { key in
                        CalcKeyView(key: key, fixedHeight: 38) { press(key) }
                    }
                }
            }
        }
    }

    private var numberPad: some View {
        VStack(spacing: 9) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 9) {
                    ForEach(row) { key in
                        CalcKeyView(key: key, fixedHeight: nil) { press(key) }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func press(_ key: KeypadKey) {
        switch key.action {
        case .insert(let text):
            model.insert(text)
        case .clear:
            model.clear()
        case .delete:
            model.backspace()
        case .evaluate:
            model.evaluate()
        case .negate:
            model.negate()
        }
        focus.wrappedValue = true
    }
}
