import Foundation

public struct AIMessage: Equatable, Sendable {
    public enum Role: String, Sendable { case user, assistant }
    public var role: Role
    public var text: String
    public init(role: Role, text: String) { self.role = role; self.text = text }
}

/// A ready-to-send HTTP request, kept free of URLSession so it can be unit-tested.
public struct AIHTTPRequest: Equatable, Sendable {
    public var url: URL
    public var headers: [String: String]
    public var body: Data
}

public enum AIChatError: Error, Equatable, Sendable {
    case badResponse
    case http(status: Int, message: String)
    case network
    case noKeys
    /// Every saved key was tried and none worked; `failures` is one short reason per key, in order.
    case allFailed([String])
}

/// How to talk to each provider. OpenAI, Kimi, DeepSeek and Qwen speak the OpenAI "chat completions" shape;
/// Google Gemini has its own.
public enum AIChat {
    /// Default model per provider (stable aliases). Kept in one place so it's easy to change.
    public static func model(for provider: AIProvider) -> String {
        switch provider {
        case .google: "gemini-2.5-flash"
        case .openai: "gpt-4o-mini"
        case .kimi: "moonshot-v1-8k"
        case .qwen: "qwen-plus"
        case .deepseek: "deepseek-chat"
        }
    }

    static func chatURL(for provider: AIProvider) -> URL {
        let text: String
        switch provider {
        case .google: text = "https://generativelanguage.googleapis.com/v1beta/models/\(model(for: .google)):generateContent"
        case .openai: text = "https://api.openai.com/v1/chat/completions"
        case .kimi: text = "https://api.moonshot.ai/v1/chat/completions"
        case .qwen: text = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions"
        case .deepseek: text = "https://api.deepseek.com/chat/completions"
        }
        return URL(string: text)!
    }

    public static func request(
        provider: AIProvider, key: String, system: String?, messages: [AIMessage], maxTokens: Int = 2000
    ) -> AIHTTPRequest {
        var headers = ["Content-Type": "application/json"]
        let body: [String: Any]
        switch provider {
        case .google:
            headers["x-goog-api-key"] = key
            var payload: [String: Any] = [
                "contents": messages.map { message in
                    ["role": message.role == .user ? "user" : "model", "parts": [["text": message.text]]]
                },
                // Gemini 2.5 counts its hidden "thinking" against the output limit, which cuts long answers short.
                "generationConfig": ["maxOutputTokens": maxTokens, "thinkingConfig": ["thinkingBudget": 0]]
            ]
            if let system, !system.isEmpty { payload["systemInstruction"] = ["parts": [["text": system]]] }
            body = payload
        case .openai, .kimi, .qwen, .deepseek:
            headers["Authorization"] = "Bearer \(key)"
            var list: [[String: String]] = []
            if let system, !system.isEmpty { list.append(["role": "system", "content": system]) }
            list += messages.map { ["role": $0.role.rawValue, "content": $0.text] }
            body = ["model": model(for: provider), "messages": list, "max_tokens": maxTokens]
        }
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
        return AIHTTPRequest(url: chatURL(for: provider), headers: headers, body: data)
    }

    /// The assistant's text from a successful response body.
    public static func reply(provider: AIProvider, data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let text: String?
        switch provider {
        case .google:
            let parts = ((root["candidates"] as? [[String: Any]])?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]]
            text = parts?.compactMap { $0["text"] as? String }.joined()
        case .openai, .kimi, .qwen, .deepseek:
            text = (((root["choices"] as? [[String: Any]])?.first?["message"]) as? [String: Any])?["content"] as? String
        }
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    /// Short readable reason from an error body (`{"error":{"message":...}}`), falling back to the status code.
    public static func errorMessage(status: Int, data: Data) -> String {
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let error = root["error"]
            if let dict = error as? [String: Any], let message = dict["message"] as? String { return String(message.prefix(160)) }
            if let message = error as? String { return String(message.prefix(160)) }
        }
        return "HTTP \(status)"
    }

    /// Arabic explanation of a failure, for the UI.
    public static func arabicReason(_ error: AIChatError) -> String {
        switch error {
        case .network: return "ما فيه اتصال بالإنترنت أو المزوّد ما رد."
        case .badResponse: return "رد المزوّد غير مفهوم."
        case .noKeys: return "ما أضفت أي مفتاح. أضف مفتاح من الإعدادات أول."
        case .http(let status, _):
            switch status {
            case 400: return "المزوّد رفض الطلب (400). غالباً اسم الموديل أو الطلب نفسه."
            case 401, 403: return "المفتاح غلط أو ما عنده صلاحية."
            case 402: return "الرصيد خلص."
            case 404: return "الموديل أو العنوان غير موجود عند المزوّد."
            case 429: return "وصلت حد الاستخدام أو خلص الرصيد."
            case 500...599: return "المزوّد فيه مشكلة مؤقتة."
            default: return "المزوّد رد بخطأ (\(status))."
            }
        case .allFailed(let reasons): return reasons.joined(separator: "\n")
        }
    }

    /// Tries each key in order and returns the first reply. `send` performs one request and may throw `AIChatError`.
    public static func complete(
        keys: [AIKeyEntry],
        system: String?,
        messages: [AIMessage],
        maxTokens: Int = 2000,
        send: (AIKeyEntry, AIHTTPRequest) async throws -> Data
    ) async throws -> (text: String, used: AIKeyEntry) {
        guard !keys.isEmpty else { throw AIChatError.noKeys }
        var failures: [String] = []
        for entry in keys {
            let request = request(provider: entry.provider, key: entry.key, system: system, messages: messages, maxTokens: maxTokens)
            do {
                let data = try await send(entry, request)
                if let text = reply(provider: entry.provider, data: data) { return (text, entry) }
                failures.append("\(entry.provider.displayName): \(arabicReason(.badResponse))")
            } catch let error as AIChatError {
                failures.append("\(entry.provider.displayName): \(arabicReason(error))")
            } catch {
                failures.append("\(entry.provider.displayName): \(arabicReason(.network))")
            }
        }
        throw AIChatError.allFailed(failures)
    }
}
