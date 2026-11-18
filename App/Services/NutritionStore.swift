import Foundation
import HabitCore

/// Looks foods up with the user's AI keys (searching the web when a key allows it) and remembers recent answers.
enum NutritionStore {
    private static let cacheKey = "nutritionCache.v1"

    private static func loadCache() -> NutritionCache {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(NutritionCache.self, from: data) else { return NutritionCache() }
        return cache
    }

    private static func saveCache(_ cache: NutritionCache) {
        if let data = try? JSONEncoder().encode(cache) { UserDefaults.standard.set(data, forKey: cacheKey) }
    }

    struct Answer {
        var result: NutritionResult
        var searched: Bool
        var fromCache: Bool
    }

    static func lookup(_ text: String) async throws -> Answer {
        let cache = loadCache()
        if let hit = cache.result(for: text) {
            return Answer(result: hit, searched: !hit.sources.isEmpty, fromCache: true)
        }
        // Ask with a search-capable key first; the prompt tells the model whether it may search.
        let keys = AIKeyStore.load()
        let canSearch = keys.entries.contains { AIChat.supportsSearch($0.provider) }
        let reply = try await AIClient.askWithSearch(
            system: NutritionLookup.systemPrompt(searching: canSearch),
            messages: [AIMessage(role: .user, text: text)]
        )
        switch NutritionLookup.parse(reply.text) {
        case .success(var result):
            // Prefer the provider's own citations over the ones the model typed.
            if !reply.sources.isEmpty { result.sources = Array(reply.sources.prefix(5)) }
            var updated = cache
            updated.store(result, for: text)
            saveCache(updated)
            return Answer(result: result, searched: reply.searched, fromCache: false)
        case .failure:
            throw AIChatError.badResponse
        }
    }
}
