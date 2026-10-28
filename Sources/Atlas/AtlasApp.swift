import AppKit
import SwiftUI

@main
struct AtlasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = CalculatorModel()

    var body: some Scene {
        WindowGroup("Atlas") {
            ContentView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1120, height: 840)
        .commands {
            CommandMenu("Calculator") {
                Button("Evaluate") {
                    switch model.mode {
                    case .calculus:
                        model.calculus.run(with: model.engine)
                    case .algebra:
                        model.algebra.solve(with: model.engine)
                    case .basic, .scientific:
                        model.evaluate()
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])

                Button("Clear") {
                    model.clear()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])

                Button("Copy Result") {
                    model.copyResult()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Divider()

                Button("Degrees / Radians") {
                    model.toggleAngleMode()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Basic") { model.mode = .basic }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("Scientific") { model.mode = .scientific }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("Calculus") { model.mode = .calculus }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("Algebra") { model.mode = .algebra }
                    .keyboardShortcut("4", modifiers: [.command])

                Divider()

                Button("AI Tutor") {
                    withAnimation(.snappy(duration: 0.28)) {
                        model.toggleAIPanel()
                    }
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("History Sidebar") {
                    withAnimation(.snappy(duration: 0.28)) {
                        model.toggleSidebar()
                    }
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Reference…") {
                    model.showsReference = true
                }
                .keyboardShortcut("/", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(model: model)
                .frame(
                    minWidth: 640, idealWidth: 640, maxWidth: .infinity,
                    minHeight: 620, idealHeight: 720, maxHeight: .infinity
                )
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
