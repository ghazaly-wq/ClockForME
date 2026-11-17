import Foundation
import HabitCore
import Security

/// Keeps the user's AI keys in the iOS Keychain (this device only, never in backups or iCloud), as one JSON item.
enum AIKeyStore {
    private static let service = "com.ghazaly.habits.ai"
    private static let account = "keybook"

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> AIKeyBook {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let book = try? JSONDecoder().decode(AIKeyBook.self, from: data) else { return AIKeyBook() }
        return book
    }

    /// Returns false when the Keychain refused the write.
    @discardableResult
    static func save(_ book: AIKeyBook) -> Bool {
        guard let data = try? JSONEncoder().encode(book) else { return false }
        SecItemDelete(baseQuery as CFDictionary)
        guard !book.entries.isEmpty else { return true }
        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
}
