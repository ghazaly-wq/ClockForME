import XCTest
@testable import HabitCore

final class AIChatTests: XCTestCase {
    private func json(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func testOpenAIStyleRequestHasBearerSystemAndMessages() {
        let request = AIChat.request(
            provider: .deepseek, key: "sk-abc", system: "be brief",
            messages: [AIMessage(role: .user, text: "hi")]
        )
        XCTAssertEqual(request.headers["Authorization"], "Bearer sk-abc")
        XCTAssertEqual(request.url.host, "api.deepseek.com")
        let body = json(request.body)
        XCTAssertEqual(body["model"] as? String, "deepseek-chat")
        let messages = body["messages"] as? [[String: String]]
        XCTAssertEqual(messages?.first, ["role": "system", "content": "be brief"])
        XCTAssertEqual(messages?.last, ["role": "user", "content": "hi"])
    }

    func testGoogleRequestUsesHeaderKeyAndSystemInstruction() {
        let request = AIChat.request(
            provider: .google, key: "AQ.key", system: "sys",
            messages: [AIMessage(role: .user, text: "q"), AIMessage(role: .assistant, text: "a")]
        )
        XCTAssertEqual(request.headers["x-goog-api-key"], "AQ.key")
        XCTAssertFalse(request.url.absoluteString.contains("AQ.key"))
        let body = json(request.body)
        let contents = body["contents"] as? [[String: Any]]
        XCTAssertEqual(contents?.map { $0["role"] as? String }, ["user", "model"])
        XCTAssertNotNil(body["systemInstruction"])
    }

    func testNoSystemMeansNoSystemMessage() {
        let request = AIChat.request(provider: .openai, key: "k", system: nil, messages: [AIMessage(role: .user, text: "x")])
        let messages = json(request.body)["messages"] as? [[String: String]]
        XCTAssertEqual(messages?.count, 1)
    }

    func testReplyParsing() {
        let openai = #"{"choices":[{"message":{"content":"hello"}}]}"#.data(using: .utf8)!
        XCTAssertEqual(AIChat.reply(provider: .openai, data: openai), "hello")
        let google = #"{"candidates":[{"content":{"parts":[{"text":"a"},{"text":"b"}]}}]}"#.data(using: .utf8)!
        XCTAssertEqual(AIChat.reply(provider: .google, data: google), "ab")
        XCTAssertNil(AIChat.reply(provider: .openai, data: #"{"choices":[]}"#.data(using: .utf8)!))
        XCTAssertNil(AIChat.reply(provider: .openai, data: Data("nope".utf8)))
    }

    func testErrorMessage() {
        let body = #"{"error":{"message":"Invalid key"}}"#.data(using: .utf8)!
        XCTAssertEqual(AIChat.errorMessage(status: 401, data: body), "Invalid key")
        XCTAssertEqual(AIChat.errorMessage(status: 500, data: Data()), "HTTP 500")
    }

    func testFallbackSkipsFailingKeyAndReturnsNextReply() async throws {
        let first = AIKeyEntry(provider: .openai, key: "k1k1k1k1k1k1k1k1")
        let second = AIKeyEntry(provider: .deepseek, key: "k2k2k2k2k2k2k2k2")
        let ok = #"{"choices":[{"message":{"content":"done"}}]}"#.data(using: .utf8)!
        let result = try await AIChat.complete(keys: [first, second], system: nil, messages: [AIMessage(role: .user, text: "x")]) { entry, _ in
            if entry.id == first.id { throw AIChatError.http(status: 429, message: "quota") }
            return ok
        }
        XCTAssertEqual(result.text, "done")
        XCTAssertEqual(result.used.id, second.id)
    }

    func testAllFailedListsEveryReasonAndNoKeysThrows() async {
        let a = AIKeyEntry(provider: .openai, key: "k1k1k1k1k1k1k1k1")
        let b = AIKeyEntry(provider: .kimi, key: "k2k2k2k2k2k2k2k2")
        do {
            _ = try await AIChat.complete(keys: [a, b], system: nil, messages: []) { _, _ in throw AIChatError.http(status: 401, message: "") }
            XCTFail("should throw")
        } catch let AIChatError.allFailed(reasons) {
            XCTAssertEqual(reasons.count, 2)
        } catch { XCTFail("wrong error") }
        do {
            _ = try await AIChat.complete(keys: [], system: nil, messages: []) { _, _ in Data() }
            XCTFail("should throw")
        } catch { XCTAssertEqual(error as? AIChatError, .noKeys) }
    }
}
