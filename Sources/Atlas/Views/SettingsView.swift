import AtlasCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: CalculatorModel

    @State private var revealKey = false
    @State private var probe: ProbeState = .idle
    @State private var confirmsReset = false

    private enum ProbeState: Equatable {
        case idle
        case running
        case success(String)
        case failure(String)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                calculatorCard
                aiCard(model.aiChat.settings)
                aboutCard
            }
            .padding(.bottom, 4)
        }
        .scrollIndicators(.automatic)
        .confirmationDialog("Reset Atlas?", isPresented: $confirmsReset) {
            Button("Reset Everything", role: .destructive) {
                model.resetEverything()
            }
        } message: {
            Text("Clears history, variables and the AI conversation, and removes the API key from the Keychain.")
        }
    }

    // MARK: - Calculator

    private var calculatorCard: some View {
        card(title: "Calculator", symbol: "plus.forwardslash.minus") {
            VStack(spacing: 12) {
                row("Angle mode") {
                    Picker("Angle mode", selection: angleBinding) {
                        Text("Degrees").tag(AngleMode.degrees)
                        Text("Radians").tag(AngleMode.radians)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 180)
                }

                Divider().opacity(0.35)

                row("History sidebar") {
                    Toggle("History sidebar", isOn: sidebarBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                row("AI tutor panel") {
                    Toggle("AI tutor panel", isOn: aiPanelBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                Divider().opacity(0.35)

                row("History") {
                    HStack(spacing: 8) {
                        Text("\(model.history.count) entries")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Button("Clear") {
                            withAnimation(.snappy(duration: 0.2)) {
                                model.clearHistory()
                            }
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .disabled(model.history.isEmpty)
                    }
                }

                row("Variables") {
                    HStack(spacing: 8) {
                        Text("\(model.userVariables.count) defined")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Button("Clear") {
                            withAnimation(.snappy(duration: 0.2)) {
                                model.clearVariables()
                            }
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .disabled(model.userVariables.isEmpty)
                    }
                }

                Divider().opacity(0.35)

                HStack {
                    Text("Reset everything, including preferences.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset Atlas…", role: .destructive) {
                        confirmsReset = true
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - AI

    private func aiCard(_ settings: AISettings) -> some View {
        card(title: "AI Tutor", symbol: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                row("Provider") {
                    Picker("Provider", selection: binding(\.provider)) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 260)
                    .onChange(of: settings.provider) { _, _ in
                        probe = .idle
                    }
                }

                labelled("Model") {
                    HStack(spacing: 6) {
                        field(
                            settings.provider.defaultModel.isEmpty ? "model id" : settings.provider.defaultModel,
                            text: binding(\.model)
                        )
                        if !settings.provider.suggestedModels.isEmpty {
                            Menu {
                                ForEach(settings.provider.suggestedModels, id: \.self) { suggestion in
                                    Button(suggestion) { settings.model = suggestion }
                                }
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 26, height: 26)
                                    .contentShape(Circle())
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .frame(width: 26)
                            .help("Suggested models")
                        }
                    }
                }

                labelled("Base URL") {
                    field("https://api.openai.com/v1", text: binding(\.baseURL))
                }

                labelled("API key") {
                    HStack(spacing: 6) {
                        Group {
                            if revealKey {
                                field(settings.provider.keyPlaceholder, text: binding(\.apiKey))
                            } else {
                                SecureField(settings.provider.keyPlaceholder, text: binding(\.apiKey))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12.5, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        Color.primary.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    )
                            }
                        }

                        Button {
                            revealKey.toggle()
                        } label: {
                            Image(systemName: revealKey ? "eye.slash" : "eye")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 26, height: 26)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(revealKey ? "Hide the key" : "Show the key")

                        if settings.hasKey {
                            Button {
                                settings.apiKey = ""
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 26, height: 26)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Remove the stored key")
                        }
                    }

                    HStack(spacing: 5) {
                        Image(systemName: settings.hasKey ? "checkmark.seal.fill" : "key")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(settings.hasKey ? Theme.mint : Color.secondary)
                        Text(settings.hasKey ? "Stored in the macOS Keychain" : settings.provider.setupHint)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }

                labelled("Instructions") {
                    TextEditor(text: binding(\.systemPrompt))
                        .font(.system(size: 11.5, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(height: 84)
                        .background(
                            Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                }

                row("Send calculator context") {
                    Toggle("Send calculator context", isOn: binding(\.includeCalculatorContext))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                row("Creativity") {
                    HStack(spacing: 10) {
                        Slider(value: binding(\.temperature), in: 0...1, step: 0.05)
                            .frame(width: 150)
                        Text(String(format: "%.2f", settings.temperature))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)
                    }
                }

                Divider().opacity(0.35)

                HStack(spacing: 10) {
                    Button {
                        runProbe(settings)
                    } label: {
                        Label(
                            probe == .running ? "Testing…" : "Test Connection",
                            systemImage: "bolt.horizontal.circle"
                        )
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(probe == .running || !settings.isConfigured)

                    probeLabel

                    Spacer(minLength: 0)

                    Button("Clear Conversation") {
                        model.aiChat.clear()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(model.aiChat.messages.isEmpty)
                }

                if !settings.isConfigured {
                    Text("Atlas talks to the provider directly from your Mac. The key never leaves this device, and requests are only sent when you ask a question.")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var probeLabel: some View {
        switch probe {
        case .idle:
            EmptyView()
        case .running:
            ProgressView()
                .controlSize(.small)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mint)
                .lineLimit(1)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.coral)
                .lineLimit(2)
                .frame(maxWidth: 330, alignment: .leading)
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        card(title: "About Atlas", symbol: "info.circle") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Atlas \(version)")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    Text("Mathematics · Golden Gate")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(model.history.count) calculations")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Text("A dependency-free numerical engine — arithmetic, trigonometry, statistics, calculus and symbolic algebra — with a SwiftUI front end.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
    }

    // MARK: - Bindings

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<AISettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.aiChat.settings[keyPath: keyPath] },
            set: { model.aiChat.settings[keyPath: keyPath] = $0 }
        )
    }

    private var angleBinding: Binding<AngleMode> {
        Binding(get: { model.angleMode }, set: { model.angleMode = $0 })
    }

    private var sidebarBinding: Binding<Bool> {
        Binding(
            get: { model.showSidebar },
            set: { newValue in
                withAnimation(.snappy(duration: 0.28)) {
                    model.showSidebar = newValue
                    if newValue { model.showAIPanel = false }
                }
            }
        )
    }

    private var aiPanelBinding: Binding<Bool> {
        Binding(
            get: { model.showAIPanel },
            set: { newValue in
                withAnimation(.snappy(duration: 0.28)) {
                    model.showAIPanel = newValue
                    if newValue { model.showSidebar = false }
                }
            }
        )
    }

    // MARK: - Helpers

    private func runProbe(_ settings: AISettings) {
        guard probe != .running else { return }
        probe = .running
        Task {
            do {
                let reply = try await settings.testConnection()
                probe = .success(reply)
            } catch {
                probe = .failure(error.localizedDescription)
            }
        }
    }

    private func card<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                Spacer()
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: Theme.cardShape(24))
    }

    private func row<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            content()
        }
    }

    private func labelled<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.tertiary)
            content()
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 12.5, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
    }
}
