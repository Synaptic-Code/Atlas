import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var model: CalculatorModel
    @FocusState private var expressionFocused: Bool

    var body: some View {
        ZStack {
            AuroraBackdrop()

            HStack(alignment: .top, spacing: 16) {
                mainColumn

                if model.showAIPanel {
                    AIPanelView(model: model)
                        .frame(width: 360)
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else if model.showSidebar {
                    SidebarView(model: model, focus: $expressionFocused)
                        .frame(width: 292)
                        .frame(maxHeight: .infinity)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .padding(.top, 10)
        }
        .frame(minWidth: 1060, minHeight: 760)
        .background(WindowConfigurator())
        .sheet(isPresented: $model.showsReference) {
            ReferenceView()
        }
        .onAppear {
            expressionFocused = model.mode.editsExpression
        }
        .onChange(of: model.mode) { _, newMode in
            expressionFocused = newMode.editsExpression
        }
        .onChange(of: model.showsReference) { _, isShowing in
            if !isShowing, model.mode.editsExpression {
                expressionFocused = true
            }
        }
        .animation(.snappy(duration: 0.28), value: model.showSidebar)
        .animation(.snappy(duration: 0.28), value: model.showAIPanel)
        .animation(.snappy(duration: 0.26), value: model.mode)
    }

    private var mainColumn: some View {
        VStack(spacing: 14) {
            HeaderView(model: model, focus: $expressionFocused)

            if model.mode == .calculus {
                CalculusView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
            } else if model.mode == .algebra {
                AlgebraView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
            } else {
                DisplayView(model: model, focus: $expressionFocused)
                KeypadView(model: model, focus: $expressionFocused)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Small AppKit hook for the window chrome that SwiftUI doesn't expose yet.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.styleMask.insert(.fullSizeContentView)
            window.minSize = NSSize(width: 1060, height: 760)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
