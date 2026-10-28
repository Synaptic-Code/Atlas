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
                    if model.mode == .calculus {
                        model.calculus.run(with: model.engine)
                    } else {
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

                Divider()

                Button("History Sidebar") {
                    withAnimation(.snappy(duration: 0.28)) {
                        model.showSidebar.toggle()
                    }
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Reference…") {
                    model.showsReference = true
                }
                .keyboardShortcut("/", modifiers: [.command])
            }
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
