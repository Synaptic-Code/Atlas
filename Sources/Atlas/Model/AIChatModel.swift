import Foundation
import Observation

// MARK: - Messages

struct AIChatMessage: Identifiable, Codable, Hashable, Sendable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var text: String
    let date: Date

    init(id: UUID = UUID(), role: Role, text: String, date: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
    }
}

// MARK: - Errors

enum AIError: LocalizedError {
    case missingKey
    case missingConfiguration(String)
    case invalidURL
    case http(Int, String)
    case malformedResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Add an API key in Settings to start chatting."
        case .missingConfiguration(let detail):
            return detail
        case .invalidURL:
            return "That base URL isn’t valid. Check it in Settings."
        case .http(let status, let message):
            let detail = message.isEmpty ? "" : " \(message)"
            switch status {
            case 401, 403:
                return "The provider rejected the API key (\(status)).\(detail)"
            case 404:
                return "The endpoint wasn’t found (404). Check the base URL and model.\(detail)"
            case 429:
                return "Rate limited by the provider. Try again in a moment.\(detail)"
            default:
                return "The provider returned \(status).\(detail)"
            }
        case .malformedResponse(let detail):
            return "Unexpected response from the provider. \(detail)"
        }
    }
}

// MARK: - Client

/// Stateless HTTP client for OpenAI-style and Anthropic chat completions.
struct AIChatClient: Sendable {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 75
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    func reply(config: AIRequestConfig, system: String, messages: [AIChatMessage]) async throws -> String {
        let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if config.requiresKey && key.isEmpty {
            throw AIError.missingKey
        }

        let usable = messages.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !usable.isEmpty else {
            throw AIError.missingConfiguration("There’s nothing to send yet.")
        }

        let request = try makeRequest(
            config: config,
            system: system,
            messages: usable,
            maxTokens: 1800
        )
        let (data, response) = try await Self.session.data(for: request)
        try Self.validate(response: response, data: data)
        return try Self.parse(data: data, format: config.format)
    }

    /// A one-token round trip used by the “Test connection” button in Settings.
    func probe(config: AIRequestConfig) async throws -> String {
        let request = try makeRequest(
            config: config,
            system: "You are a connectivity probe. Answer with the single word OK.",
            messages: [AIChatMessage(role: .user, text: "Say OK.")],
            maxTokens: 24
        )
        let (data, response) = try await Self.session.data(for: request)
        try Self.validate(response: response, data: data)
        return try Self.parse(data: data, format: config.format)
    }

    // MARK: Request

    private struct Payload: Encodable {
        let role: String
        let content: String
    }

    private func makeRequest(
        config: AIRequestConfig,
        system: String,
        messages: [AIChatMessage],
        maxTokens: Int
    ) throws -> URLRequest {
        let model = config.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            throw AIError.missingConfiguration("Set a model name in Settings.")
        }

        var request = URLRequest(url: try endpoint(for: config))
        request.httpMethod = "POST"
        request.timeoutInterval = 75
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()

        switch config.format {
        case .openAI:
            let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            }
            var payload: [Payload] = []
            let instructions = system.trimmingCharacters(in: .whitespacesAndNewlines)
            if !instructions.isEmpty {
                payload.append(Payload(role: "system", content: instructions))
            }
            payload.append(contentsOf: messages.map { Payload(role: $0.role.rawValue, content: $0.text) })

            struct Body: Encodable {
                let model: String
                let messages: [Payload]
                let temperature: Double
            }
            request.httpBody = try encoder.encode(
                Body(model: model, messages: payload, temperature: config.temperature)
            )

        case .anthropic:
            let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                request.setValue(key, forHTTPHeaderField: "x-api-key")
            }
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            struct Body: Encodable {
                let model: String
                let max_tokens: Int
                let system: String?
                let messages: [Payload]
                let temperature: Double
            }
            let instructions = system.trimmingCharacters(in: .whitespacesAndNewlines)
            request.httpBody = try encoder.encode(
                Body(
                    model: model,
                    max_tokens: maxTokens,
                    system: instructions.isEmpty ? nil : instructions,
                    messages: messages.map { Payload(role: $0.role.rawValue, content: $0.text) },
                    temperature: config.temperature
                )
            )
        }

        return request
    }

    private func endpoint(for config: AIRequestConfig) throws -> URL {
        var base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else {
            throw AIError.missingConfiguration("Set a base URL in Settings.")
        }
        while base.hasSuffix("/") { base.removeLast() }

        let path: String
        switch config.format {
        case .openAI:
            path = base.hasSuffix("/chat/completions") ? "" : "/chat/completions"
        case .anthropic:
            if base.hasSuffix("/messages") {
                path = ""
            } else if base.hasSuffix("/v1") {
                path = "/messages"
            } else {
                path = "/v1/messages"
            }
        }

        guard let url = URL(string: base + path), url.scheme != nil, url.host != nil else {
            throw AIError.invalidURL
        }
        return url
    }

    // MARK: Response

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIError.malformedResponse("No HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AIError.http(http.statusCode, apiErrorMessage(from: data))
        }
    }

    private static func parse(data: Data, format: AIProvider.WireFormat) throws -> String {
        switch format {
        case .openAI:
            struct Response: Decodable {
                struct Choice: Decodable {
                    struct Message: Decodable { let content: String? }
                    let message: Message
                }
                let choices: [Choice]
            }
            guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
                  let content = decoded.choices.first?.message.content,
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw AIError.malformedResponse(Self.snippet(data))
            }
            return content

        case .anthropic:
            struct Response: Decodable {
                struct Block: Decodable {
                    let type: String
                    let text: String?
                }
                let content: [Block]
            }
            guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
                throw AIError.malformedResponse(Self.snippet(data))
            }
            let text = decoded.content
                .compactMap { $0.type == "text" ? $0.text : nil }
                .joined(separator: "\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIError.malformedResponse(Self.snippet(data))
            }
            return text
        }
    }

    private static func apiErrorMessage(from data: Data) -> String {
        struct Envelope: Decodable {
            struct Detail: Decodable { let message: String? }
            let error: Detail?
            let message: String?
        }
        guard let decoded = try? JSONDecoder().decode(Envelope.self, from: data) else {
            return snippet(data)
        }
        return String((decoded.error?.message ?? decoded.message ?? "").prefix(300))
    }

    private static func snippet(_ data: Data) -> String {
        let text = String(data: data, encoding: .utf8) ?? ""
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? "" : String(collapsed.prefix(220))
    }
}

// MARK: - Conversation model

@MainActor
@Observable
final class AIChatModel {
    private static let storageKey = "atlas.ai.chat.v1"
    private static let maximumMessages = 120
    private static let maximumRequestMessages = 24

    var settings = AISettings()

    var messages: [AIChatMessage] {
        didSet { save() }
    }

    var draft = ""
    var isResponding = false
    var errorText: String?

    @ObservationIgnored private var task: Task<Void, Never>?

    init() {
        messages = Self.load()
    }

    // MARK: - Derived state

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }

    var isReady: Bool { settings.isConfigured }

    var subtitle: String {
        if isResponding { return "Thinking…" }
        guard settings.isConfigured else { return "Not connected" }
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.isEmpty ? settings.provider.title : model
    }

    // MARK: - Actions

    /// Sends the current draft together with a snapshot of the calculator state.
    func send(context: String) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding else { return }

        guard settings.isConfigured else {
            errorText = settings.hasKey || settings.provider == .compatible
                ? "Finish the AI configuration in Settings."
                : AIError.missingKey.localizedDescription
            return
        }

        append(AIChatMessage(role: .user, text: text))
        draft = ""
        errorText = nil
        start(context: context)
    }

    /// Re-sends the conversation after a failure, without duplicating the prompt.
    func retry(context: String) {
        guard !isResponding, messages.contains(where: { $0.role == .user }) else { return }
        errorText = nil
        start(context: context)
    }

    func stop() {
        task?.cancel()
        task = nil
        isResponding = false
    }

    func clear() {
        stop()
        errorText = nil
        messages = []
    }

    func reset() {
        clear()
        settings.reset()
    }

    // MARK: - Networking

    private func start(context: String) {
        let config = settings.requestConfig
        let system = systemPrompt(context: context)
        let history = Array(
            messages
                .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .suffix(Self.maximumRequestMessages)
        )

        isResponding = true
        errorText = nil

        task = Task { [weak self] in
            do {
                let reply = try await AIChatClient().reply(
                    config: config,
                    system: system,
                    messages: history
                )
                guard !Task.isCancelled else { return }
                self?.append(AIChatMessage(role: .assistant, text: reply))
            } catch is CancellationError {
                // The user stopped the request; nothing to report.
            } catch {
                guard !Task.isCancelled else { return }
                self?.errorText = error.localizedDescription
            }
            self?.isResponding = false
            self?.task = nil
        }
    }

    private func systemPrompt(context: String) -> String {
        var prompt = settings.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if prompt.isEmpty {
            prompt = AISettings.defaultSystemPrompt
        }

        guard settings.includeCalculatorContext else { return prompt }
        let context = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !context.isEmpty else { return prompt }
        return prompt + "\n\nCurrent state of the calculator:\n" + context
    }

    private func append(_ message: AIChatMessage) {
        messages.append(message)
        if messages.count > Self.maximumMessages {
            messages.removeFirst(messages.count - Self.maximumMessages)
        }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func load() -> [AIChatMessage] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([AIChatMessage].self, from: data)
        else { return [] }
        return decoded
    }
}
