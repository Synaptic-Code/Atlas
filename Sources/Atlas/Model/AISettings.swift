import Foundation
import Observation
import Security

/// The chat provider Atlas talks to. `compatible` covers any OpenAI-compatible
/// endpoint (OpenRouter, Groq, a local Ollama server, …).
enum AIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case openAI
    case anthropic
    case compatible

    enum WireFormat: Sendable {
        case openAI
        case anthropic
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .compatible: return "Compatible"
        }
    }

    var wireFormat: WireFormat {
        self == .anthropic ? .anthropic : .openAI
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .compatible: return "http://localhost:11434/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .anthropic: return "claude-sonnet-4-5"
        case .compatible: return ""
        }
    }

    var suggestedModels: [String] {
        switch self {
        case .openAI:
            return ["gpt-4o-mini", "gpt-4o", "o4-mini"]
        case .anthropic:
            return ["claude-sonnet-4-5", "claude-opus-4-1", "claude-3-5-haiku-latest"]
        case .compatible:
            return ["llama3.2", "qwen2.5", "mistral"]
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openAI: return "sk-…"
        case .anthropic: return "sk-ant-…"
        case .compatible: return "optional for local models"
        }
    }

    var setupHint: String {
        switch self {
        case .openAI:
            return "Create a key at platform.openai.com"
        case .anthropic:
            return "Create a key at console.anthropic.com"
        case .compatible:
            return "Any OpenAI-compatible endpoint: OpenRouter, Groq, Ollama, LM Studio…"
        }
    }
}

/// An immutable snapshot of everything a request needs, so the networking code
/// can run off the main actor.
struct AIRequestConfig: Sendable {
    var format: AIProvider.WireFormat
    var baseURL: String
    var model: String
    var apiKey: String
    var temperature: Double
    /// Local and self-hosted endpoints often need no key at all.
    var requiresKey: Bool
}

/// User-facing AI preferences. The API key lives in the macOS Keychain; the
/// rest is small enough to sit in `UserDefaults` alongside the calculator state.
@MainActor
@Observable
final class AISettings {
    static let defaultSystemPrompt = """
    You are Atlas, a maths tutor built into a desktop calculator. Solve the \
    problem the user asks about, showing the reasoning in clear numbered steps \
    before the final answer. Keep prose short and precise. Write mathematics \
    in plain text with Unicode symbols (√, π, ≤, ×, ÷) and put the final \
    answer on its own line. If the question is ambiguous, state the \
    interpretation you chose. If it isn't a maths question, say so briefly and \
    steer back to mathematics.
    """

    private static let storageKey = "atlas.ai.settings.v1"
    private static let keychainAccount = "ai-api-key"

    var provider: AIProvider = .openAI {
        didSet {
            guard provider != oldValue else { return }
            if baseURL.trimmingCharacters(in: .whitespacesAndNewlines) == oldValue.defaultBaseURL {
                baseURL = provider.defaultBaseURL
            }
            if model.trimmingCharacters(in: .whitespacesAndNewlines) == oldValue.defaultModel {
                model = provider.defaultModel
            }
            save()
        }
    }

    var baseURL: String = AIProvider.openAI.defaultBaseURL { didSet { save() } }
    var model: String = AIProvider.openAI.defaultModel { didSet { save() } }
    var systemPrompt: String = AISettings.defaultSystemPrompt { didSet { save() } }
    var temperature: Double = 0.2 { didSet { save() } }
    var includeCalculatorContext = true { didSet { save() } }

    var apiKey: String = "" {
        didSet {
            guard apiKey != oldValue else { return }
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            KeychainStore.set(trimmed.isEmpty ? nil : trimmed, account: Self.keychainAccount)
        }
    }

    init() {
        let key = KeychainStore.string(account: Self.keychainAccount) ?? ""
        apiKey = key
        load()
    }

    // MARK: - Derived state

    var isConfigured: Bool {
        (hasKey || provider == .compatible)
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var requestConfig: AIRequestConfig {
        AIRequestConfig(
            format: provider.wireFormat,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            temperature: temperature,
            requiresKey: provider != .compatible
        )
    }

    // MARK: - Actions

    /// Sends a tiny prompt so the user can confirm their key, URL and model work.
    func testConnection() async throws -> String {
        guard hasKey || provider == .compatible else {
            throw AIError.missingKey
        }
        let reply = try await AIChatClient().probe(config: requestConfig)
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Connected" : String(trimmed.prefix(60))
    }

    func reset() {
        provider = .openAI
        baseURL = AIProvider.openAI.defaultBaseURL
        model = AIProvider.openAI.defaultModel
        systemPrompt = Self.defaultSystemPrompt
        temperature = 0.2
        includeCalculatorContext = true
        apiKey = ""
        save()
    }

    // MARK: - Persistence

    private struct Stored: Codable {
        var provider: AIProvider?
        var baseURL: String?
        var model: String?
        var systemPrompt: String?
        var temperature: Double?
        var includeCalculatorContext: Bool?
    }

    private func save() {
        let stored = Stored(
            provider: provider,
            baseURL: baseURL,
            model: model,
            systemPrompt: systemPrompt,
            temperature: temperature,
            includeCalculatorContext: includeCalculatorContext
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let stored = try? JSONDecoder().decode(Stored.self, from: data)
        else { return }

        if let provider = stored.provider { self.provider = provider }
        if let baseURL = stored.baseURL, !baseURL.isEmpty { self.baseURL = baseURL }
        if let model = stored.model { self.model = model }
        if let systemPrompt = stored.systemPrompt, !systemPrompt.isEmpty {
            self.systemPrompt = systemPrompt
        }
        if let temperature = stored.temperature { self.temperature = temperature }
        if let includeContext = stored.includeCalculatorContext {
            includeCalculatorContext = includeContext
        }
    }
}

/// Minimal generic-password wrapper around the Keychain.
enum KeychainStore {
    private static let service = "com.atlas.calculator.atlas"

    static func string(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String?, account: String) {
        guard let value, let data = value.data(using: .utf8) else {
            delete(account: account)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insertion = query
            insertion[kSecValueData as String] = data
            SecItemAdd(insertion as CFDictionary, nil)
        }
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
