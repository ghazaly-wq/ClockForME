import Foundation
import HabitCore

/// Sends AI requests with the user's saved keys, falling back to the next key when one fails.
enum AIClient {
    /// One HTTP round trip; maps failures to `AIChatError`.
    static func send(_ request: AIHTTPRequest) async throws -> Data {
        var urlRequest = URLRequest(url: request.url, timeoutInterval: 60)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = request.body
        for (name, value) in request.headers { urlRequest.setValue(value, forHTTPHeaderField: name) }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: urlRequest) } catch { throw AIChatError.network }
        guard let http = response as? HTTPURLResponse else { throw AIChatError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw AIChatError.http(status: http.statusCode, message: AIChat.errorMessage(status: http.statusCode, data: data))
        }
        return data
    }

    /// Asks with every saved key in fallback order (optionally preferring one provider).
    static func ask(system: String?, messages: [AIMessage], maxTokens: Int = 2000, preferring: AIProvider? = nil) async throws -> (text: String, used: AIKeyEntry) {
        let keys = AIKeyStore.load().fallbackOrder(preferring: preferring)
        let result = try await AIChat.complete(keys: keys, system: system, messages: messages, maxTokens: maxTokens) { _, request in
            try await send(request)
        }
        return (result.text, result.used)
    }

    /// Like `ask`, but keys that can search the web are tried first and asked to search.
    static func askWithSearch(system: String?, messages: [AIMessage], maxTokens: Int = 4000) async throws -> (text: String, searched: Bool, sources: [String]) {
        let keys = AIKeyStore.load().searchCapableFirst()
        let result = try await AIChat.complete(keys: keys, system: system, messages: messages, maxTokens: maxTokens, webSearch: true) { _, request in
            try await send(request)
        }
        return (result.text, result.searched, result.sources)
    }

    /// Checks one key with a tiny request. Returns nil when it works, otherwise an Arabic reason.
    static func test(_ entry: AIKeyEntry) async -> String? {
        do {
            _ = try await AIChat.complete(keys: [entry], system: nil, messages: [AIMessage(role: .user, text: "Reply with the word OK.")]) { _, request in
                try await send(request)
            }
            return nil
        } catch let error as AIChatError {
            return AIChat.arabicReason(error)
        } catch {
            return AIChat.arabicReason(.network)
        }
    }
}
