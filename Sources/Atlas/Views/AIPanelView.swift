import SwiftUI

struct AIPanelView: View {
    @Bindable var model: CalculatorModel
    @Environment(\.openSettings) private var openSettings
    @FocusState private var composerFocused: Bool

    private let suggestions = [
        "Solve 2x² − 5x + 3 = 0",
        "Explain the chain rule with an example",
        "Integrate x·eˣ from 0 to 1",
        "Why does 0.999… equal 1?"
    ]

    var body: some View {
        VStack(spacing: 14) {
            header(model.aiChat)
            conversation(model.aiChat)
            composer(model.aiChat)
        }
    }

    // MARK: - Header

    private func header(_ chat: AIChatModel) -> some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.violet, Theme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: Theme.violet.opacity(0.35), radius: 8, y: 3)

                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("AI Tutor")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(chat.subtitle)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 6)

            GlassIconButton(symbol: "square.and.pencil", help: "New conversation") {
                withAnimation(.snappy(duration: 0.22)) { chat.clear() }
            }

            GlassIconButton(symbol: "gearshape", help: "AI settings (⌘,)") {
                openSettings()
            }

            GlassIconButton(symbol: "xmark", help: "Close the AI tutor") {
                withAnimation(.snappy(duration: 0.28)) { model.toggleAIPanel() }
            }
        }
        .padding(.leading, 2)
        .frame(height: 38)
    }

    // MARK: - Conversation

    private func conversation(_ chat: AIChatModel) -> some View {
        VStack(spacing: 10) {
            if chat.messages.isEmpty {
                emptyState(chat)
            } else {
                messageList(chat)
            }

            if let error = chat.errorText {
                errorBanner(error, chat: chat)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassEffect(.regular, in: Theme.cardShape(26))
    }

    private func messageList(_ chat: AIChatModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(chat.messages) { message in
                        bubble(message)
                            .id(message.id)
                    }

                    if chat.isResponding {
                        typingIndicator
                            .id("typing")
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.automatic)
            .onAppear { scrollToBottom(proxy) }
            .onChange(of: chat.messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: chat.isResponding) { _, _ in scrollToBottom(proxy) }
        }
    }

    @ViewBuilder
    private func bubble(_ message: AIChatMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 26)
                Text(message.text)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .textSelection(.enabled)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .foregroundStyle(.primary)
                    .glassEffect(
                        .regular.tint(Theme.accent.opacity(0.28)),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .contextMenu {
                        Button("Copy") { copy(message.text) }
                        Button("Send to Calculator") { model.expression = message.text }
                    }
            }

        case .assistant:
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Theme.violet)
                    .frame(width: 20, height: 20)
                    .background(Theme.violet.opacity(0.16), in: Circle())

                Text(rendered(message.text))
                    .font(.system(size: 12.5, design: .rounded))
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contextMenu {
                        Button("Copy") { copy(message.text) }
                        Button("Insert into Calculator") { model.expression = message.text }
                    }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Theme.violet)
                .symbolEffect(.pulse, options: .repeating)
            Text("Working through it…")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            ProgressView()
                .controlSize(.mini)
        }
        .padding(.vertical, 4)
    }

    private func emptyState(_ chat: AIChatModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Theme.violet)
                    Text("Ask about any problem")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    Text("Atlas explains each step, and can see the expression you’re working on.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !chat.isReady {
                    notConfiguredCard(chat)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            chat.draft = suggestion
                            chat.send(context: model.aiContext)
                            composerFocused = true
                        } label: {
                            HStack(spacing: 6) {
                                Text(suggestion)
                                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .disabled(!chat.isReady || chat.isResponding)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.automatic)
    }

    private func notConfiguredCard(_ chat: AIChatModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "key")
                    .font(.system(size: 10, weight: .semibold))
                Text("API key needed")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(Theme.gold)

            Text("Add a key for OpenAI, Anthropic or any compatible endpoint in Settings. It stays in the macOS Keychain.")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open Settings") {
                openSettings()
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
            .controlSize(.small)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.gold.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func errorBanner(_ message: String, chat: AIChatModel) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(message)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.coral)

            HStack(spacing: 8) {
                Button("Retry") {
                    chat.retry(context: model.aiContext)
                }
                .buttonStyle(.glass)
                .controlSize(.small)

                Button("Settings") {
                    openSettings()
                }
                .buttonStyle(.glass)
                .controlSize(.small)

                Spacer()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.coral.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    // MARK: - Composer

    private func composer(_ chat: AIChatModel) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField(
                    "Ask a maths question…",
                    text: draftBinding(chat),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .lineLimit(1...5)
                .focused($composerFocused)
                .onSubmit { send(chat) }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

                Button {
                    if chat.isResponding {
                        chat.stop()
                    } else {
                        send(chat)
                    }
                } label: {
                    Image(systemName: chat.isResponding ? "stop.fill" : "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(
                    .regular
                        .tint(chat.isResponding ? Theme.coral.opacity(0.35) : Theme.accent.opacity(0.45))
                        .interactive(),
                    in: Circle()
                )
                .help(chat.isResponding ? "Stop" : "Send (Return)")
            }

            HStack(spacing: 6) {
                Image(systemName: "lock")
                    .font(.system(size: 8.5, weight: .semibold))
                Text("Sent directly to \(model.aiChat.settings.provider.title). Answers may need checking.")
                    .lineLimit(1)
                Spacer(minLength: 0)
                if !chat.draft.isEmpty {
                    Text("Return to send")
                }
            }
            .font(.system(size: 9.5, weight: .medium, design: .rounded))
            .foregroundStyle(.tertiary)
        }
        .padding(12)
        .glassEffect(.regular, in: Theme.cardShape(22))
    }

    // MARK: - Actions

    private func draftBinding(_ chat: AIChatModel) -> Binding<String> {
        Binding(get: { chat.draft }, set: { chat.draft = $0 })
    }

    private func send(_ chat: AIChatModel) {
        guard chat.canSend else { return }
        chat.send(context: model.aiContext)
        composerFocused = true
    }

    private func copy(_ text: String) {
        model.copy(text)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.snappy(duration: 0.22)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func rendered(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
