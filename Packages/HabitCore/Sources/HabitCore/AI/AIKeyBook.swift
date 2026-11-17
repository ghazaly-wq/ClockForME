import Foundation

/// The AI services the user can bring their own API key for.
public enum AIProvider: String, Codable, CaseIterable, Sendable {
    case google, openai, kimi, qwen, deepseek

    public var displayName: String {
        switch self {
        case .google: "Google AI (Gemini)"
        case .openai: "ChatGPT (OpenAI)"
        case .kimi: "Kimi (Moonshot)"
        case .qwen: "Qwen (Alibaba)"
        case .deepseek: "DeepSeek"
        }
    }

    /// The page where the user creates a key.
    public var keyPageURL: String {
        switch self {
        case .google: "https://aistudio.google.com/apikey"
        case .openai: "https://platform.openai.com/api-keys"
        case .kimi: "https://platform.moonshot.ai/console/api-keys"
        case .qwen: "https://modelstudio.console.alibabacloud.com/?tab=model#/api-key"
        case .deepseek: "https://platform.deepseek.com/api_keys"
        }
    }
}

public struct AIKeyEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var provider: AIProvider
    public var key: String

    public init(id: UUID = UUID(), provider: AIProvider, key: String) {
        self.id = id
        self.provider = provider
        self.key = key
    }
}

/// The user's saved keys, in fallback order: the app tries the first key, and if it fails (quota, invalid, network)
/// moves on to the next one. Pure value logic; where the list is stored is the app's business.
public struct AIKeyBook: Codable, Equatable, Sendable {
    public private(set) var entries: [AIKeyEntry]

    public init(entries: [AIKeyEntry] = []) { self.entries = entries }

    public enum KeyProblem: Equatable, Sendable { case empty, hasSpaces, tooShort, duplicate }

    /// Cleans text pasted into the key field (surrounding whitespace/newlines, a leading "Bearer ").
    public static func cleaned(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("bearer ") { text = String(text.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
        return text
    }

    /// Why `raw` can't be saved, or nil when it's fine.
    public func problem(with raw: String) -> KeyProblem? {
        let key = Self.cleaned(raw)
        if key.isEmpty { return .empty }
        if key.contains(where: \.isWhitespace) { return .hasSpaces }
        if key.count < 16 { return .tooShort }
        if entries.contains(where: { $0.key == key }) { return .duplicate }
        return nil
    }

    /// Adds a key at the end of the fallback order. Returns false (and changes nothing) when it has a problem.
    @discardableResult
    public mutating func add(provider: AIProvider, key raw: String) -> Bool {
        guard problem(with: raw) == nil else { return false }
        entries.append(AIKeyEntry(provider: provider, key: Self.cleaned(raw)))
        return true
    }

    public mutating func remove(id: UUID) { entries.removeAll { $0.id == id } }

    public mutating func move(from source: IndexSet, to destination: Int) {
        let moving = source.sorted().map { entries[$0] }
        let before = source.filter { $0 < destination }.count
        for index in source.sorted(by: >) { entries.remove(at: index) }
        entries.insert(contentsOf: moving, at: destination - before)
    }

    /// Keys to try, in order. With a preferred provider, its keys go first (their relative order kept).
    public func fallbackOrder(preferring provider: AIProvider? = nil) -> [AIKeyEntry] {
        guard let provider else { return entries }
        return entries.filter { $0.provider == provider } + entries.filter { $0.provider != provider }
    }

    /// "AIza…x7Qk" style display so a key is recognisable without being readable.
    public static func masked(_ key: String) -> String {
        guard key.count > 10 else { return String(repeating: "•", count: key.count) }
        return "\(key.prefix(4))••••\(key.suffix(4))"
    }
}
