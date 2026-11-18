import XCTest
@testable import HabitCore

final class NutritionLookupTests: XCTestCase {
    private func parse(_ text: String) -> NutritionResult? {
        if case .success(let result) = NutritionLookup.parse(text) { return result }
        return nil
    }

    func testParsesFencedReplyAndRoundsNumbers() {
        let reply = """
        ```json
        {"items":[{"name":"بيضة مسلوقة","grams":50,"kcal":77.55,"protein":6.29,"carbs":0.56,"fat":5.3}],
         "sources":["https://fdc.nal.usda.gov/x","not a url"]}
        ```
        """
        let result = parse(reply)
        XCTAssertEqual(result?.items.count, 1)
        XCTAssertEqual(result?.items.first?.kcal, 77.6)
        XCTAssertEqual(result?.items.first?.protein, 6.3)
        XCTAssertEqual(result?.sources, ["https://fdc.nal.usda.gov/x"])
    }

    func testAcceptsNumbersAsStringsAndCaloriesAlias() {
        let result = parse(#"{"items":[{"name":"رز","calories":"200","protein":"4","carbs":"44","fat":"0.4"}]}"#)
        XCTAssertEqual(result?.items.first?.kcal, 200)
        XCTAssertEqual(result?.items.first?.carbs, 44)
    }

    func testMissingCaloriesAreDerivedFromMacros() {
        let result = parse(#"{"items":[{"name":"x","protein":10,"carbs":20,"fat":5}]}"#)
        XCTAssertEqual(result?.items.first?.kcal, 165)
    }

    func testRejectsNamelessNegativeAndAbsurdItems() {
        let result = parse(#"{"items":[{"name":"","kcal":100},{"name":"bad","kcal":-5,"protein":-1},{"name":"huge","kcal":99999,"protein":1000},{"name":"ok","kcal":50,"protein":1,"carbs":10,"fat":0}]}"#)
        XCTAssertEqual(result?.items.map(\.name), ["ok"])
    }

    func testBadReplies() {
        XCTAssertEqual(NutritionLookup.parse("hello"), .failure(.noJSON))
        XCTAssertEqual(NutritionLookup.parse("{ nope }"), .failure(.badJSON))
        XCTAssertEqual(NutritionLookup.parse(#"{"items":[]}"#), .failure(.empty))
    }

    func testRowFollowsColumnNames() {
        let item = NutritionItem(name: "x", grams: 100, kcal: 200, protein: 10, carbs: 30, fat: 5)
        XCTAssertEqual(NutritionLookup.row(for: item, columns: ["الدهون", "السعرات", "البروتين"]).values, [5, 200, 10])
        XCTAssertEqual(NutritionLookup.row(for: item, columns: ["كارب", "الكمية", "ملاحظة"]).values, [30, 100, nil])
        // No recognisable names: calories, protein, carbs, fat in order.
        XCTAssertEqual(NutritionLookup.row(for: item, columns: ["أ", "ب", "ج", "د", "هـ"]).values, [200, 10, 30, 5, nil])
    }

    func testCacheKeyIgnoresCaseSpacesAndDiacritics() {
        XCTAssertEqual(NutritionCache.key("  بَيضة   مسلوقة "), NutritionCache.key("بيضة مسلوقة"))
        XCTAssertEqual(NutritionCache.key("Egg  BOILED"), "egg boiled")
    }

    func testCacheStoresAndEvictsOldest() {
        var cache = NutritionCache()
        let result = NutritionResult(items: [NutritionItem(name: "a", kcal: 1, protein: 0, carbs: 0, fat: 0)], sources: [])
        for index in 0..<(NutritionCache.limit + 5) { cache.store(result, for: "food \(index)") }
        XCTAssertEqual(cache.entries.count, NutritionCache.limit)
        XCTAssertNil(cache.result(for: "food 0"))
        XCTAssertNotNil(cache.result(for: "food \(NutritionCache.limit + 4)"))
    }

    func testSearchRequestsPerProvider() throws {
        func body(_ r: AIHTTPRequest) -> [String: Any] { (try? JSONSerialization.jsonObject(with: r.body) as? [String: Any]) ?? [:] }
        let message = [AIMessage(role: .user, text: "x")]
        let google = AIChat.request(provider: .google, key: "k", system: nil, messages: message, webSearch: true)
        XCTAssertNotNil(body(google)["tools"])
        let openai = AIChat.request(provider: .openai, key: "k", system: nil, messages: message, webSearch: true)
        XCTAssertEqual(body(openai)["model"] as? String, "gpt-5-search-api")
        XCTAssertNotNil(body(openai)["web_search_options"])
        XCTAssertNil(body(openai)["max_tokens"])
        let qwen = AIChat.request(provider: .qwen, key: "k", system: nil, messages: message, webSearch: true)
        XCTAssertEqual(body(qwen)["enable_search"] as? Bool, true)
        let deepseek = AIChat.request(provider: .deepseek, key: "k", system: nil, messages: message, webSearch: true)
        XCTAssertNil(body(deepseek)["enable_search"])
        XCTAssertNil(body(AIChat.request(provider: .google, key: "k", system: nil, messages: message))["tools"])
    }

    func testSourcesAndSearchCapableOrdering() throws {
        let google = #"{"candidates":[{"groundingMetadata":{"groundingChunks":[{"web":{"uri":"https://a.com/x"}},{"web":{"uri":"https://a.com/x"}},{"web":{"uri":"https://b.com"}}]}}]}"#.data(using: .utf8)!
        XCTAssertEqual(AIChat.sources(provider: .google, data: google), ["https://a.com/x", "https://b.com"])
        let openai = #"{"choices":[{"message":{"annotations":[{"type":"url_citation","url_citation":{"url":"https://c.com"}}]}}]}"#.data(using: .utf8)!
        XCTAssertEqual(AIChat.sources(provider: .openai, data: openai), ["https://c.com"])
        var book = AIKeyBook()
        book.add(provider: .deepseek, key: "k1k1k1k1k1k1k1k1")
        book.add(provider: .google, key: "k2k2k2k2k2k2k2k2")
        book.add(provider: .kimi, key: "k3k3k3k3k3k3k3k3")
        XCTAssertEqual(book.searchCapableFirst().map(\.provider), [.google, .deepseek, .kimi])
    }

    func testFallbackReportsWhetherItSearched() async throws {
        let kimi = AIKeyEntry(provider: .kimi, key: "k1k1k1k1k1k1k1k1")
        let ok = #"{"choices":[{"message":{"content":"x"}}]}"#.data(using: .utf8)!
        let result = try await AIChat.complete(keys: [kimi], system: nil, messages: [], webSearch: true) { _, _ in ok }
        XCTAssertFalse(result.searched)
    }

    func testBuilderResolvesNutritionMeals() {
        let json = #"{"name":"x","tabs":[{"name":"a","blocks":[{"type":"container","title":"الفطور","children":[{"type":"sets","title":"الأطعمة","columns":["السعرات"]}]},{"type":"nutrition","title":"ابحث","meals":["الفطور","غير موجود"]},{"type":"nutrition","title":"بلا وجبات","meals":["؟"]}]}]}"#
        guard case .success(let page) = AIPageBuilder.page(from: json) else { return XCTFail("should build") }
        let blocks = page.tabs[0].blocks
        XCTAssertEqual(blocks.map(\.kind), [.container, .nutrition])
        XCTAssertEqual(blocks[1].sourceIDs, [blocks[0].id])
    }
}
