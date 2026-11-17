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
    static func ask(system: String?, messages: [AIMessage], preferring: AIProvider? = nil) async throws -> (text: String, used: AIKeyEntry) {
        let keys = AIKeyStore.load().fallbackOrder(preferring: preferring)
        return try await AIChat.complete(keys: keys, system: system, messages: messages) { _, request in
            try await send(request)
        }
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
