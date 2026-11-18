import Foundation

/// One food and its totals for the quantity the user typed.
public struct NutritionItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var grams: Double?
    public var kcal: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double

    public init(id: UUID = UUID(), name: String, grams: Double? = nil, kcal: Double, protein: Double, carbs: Double, fat: Double) {
        self.id = id; self.name = name; self.grams = grams
        self.kcal = kcal; self.protein = protein; self.carbs = carbs; self.fat = fat
    }
}

public struct NutritionResult: Codable, Equatable, Sendable {
    public var items: [NutritionItem]
    /// Page addresses the numbers came from (may be empty).
    public var sources: [String]
}

/// Asks an AI for the calories and macros of foods and turns the answer into checked numbers. Pure and unit-tested.
public enum NutritionLookup {
    public enum LookupError: Error, Equatable, Sendable { case noJSON, badJSON, empty }

    public static let maxItems = 12

    public static func systemPrompt(searching: Bool) -> String {
        let how = searching
            ? "Search the web for each food and use reputable values (USDA FoodData Central, product labels, official brand pages, national food tables)."
            : "Use your best knowledge; the values are estimates."
        return """
        You are a nutrition lookup. The user lists foods (Arabic or English) with quantities. \(how)
        Reply with ONE JSON object only, no explanation, no markdown fences:
        {"items":[{"name": string, "grams": number, "kcal": number, "protein": number, "carbs": number, "fat": number}], "sources":[urls]}
        Rules: one item per food, named in the user's language, with the quantity in the name when it helps (e.g. "رز مطبوخ (كوب)"). Numbers are TOTALS for the quantity the user wrote (if none, one typical serving), not per 100 g. protein/carbs/fat are grams, kcal is calories. grams is the estimated weight of that quantity. Round to one decimal. Never leave a number out; estimate if unsure. "sources" lists the pages you relied on, or [] if none.
        """
    }

    private struct Raw: Decodable {
        var items: [RawItem]?
        var sources: [String]?
    }

    private struct RawItem: Decodable {
        var name: String?
        var grams: Double?
        var kcal: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?

        enum CodingKeys: String, CodingKey { case name, grams, kcal, calories, protein, carbs, fat }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            func number(_ key: CodingKeys) -> Double? {
                if let n = try? c.decode(Double.self, forKey: key) { return n }
                if let text = try? c.decode(String.self, forKey: key) { return Double(text.trimmingCharacters(in: .whitespaces)) }
                return nil
            }
            name = try? c.decode(String.self, forKey: .name)
            grams = number(.grams)
            kcal = number(.kcal) ?? number(.calories)
            protein = number(.protein)
            carbs = number(.carbs)
            fat = number(.fat)
        }
    }

    public static func parse(_ reply: String) -> Result<NutritionResult, LookupError> {
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}"), start < end,
              let data = String(reply[start...end]).data(using: .utf8) else { return .failure(.noJSON) }
        guard let raw = try? JSONDecoder().decode(Raw.self, from: data) else { return .failure(.badJSON) }

        func clamp(_ value: Double?, max: Double) -> Double? {
            guard let value, value.isFinite, value >= 0, value <= max else { return nil }
            return (value * 10).rounded() / 10
        }

        var items: [NutritionItem] = []
        for item in (raw.items ?? []).prefix(maxItems) {
            let name = (item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let protein = clamp(item.protein, max: 500), carbs = clamp(item.carbs, max: 1000), fat = clamp(item.fat, max: 500)
            var kcal = clamp(item.kcal, max: 6000)
            // A missing calorie figure can be derived from the macros.
            if kcal == nil || kcal == 0, protein != nil || carbs != nil || fat != nil {
                kcal = ((protein ?? 0) * 4 + (carbs ?? 0) * 4 + (fat ?? 0) * 9).rounded()
            }
            guard let kcal, protein != nil || carbs != nil || fat != nil || kcal > 0 else { continue }
            items.append(NutritionItem(
                name: String(name.prefix(80)), grams: clamp(item.grams, max: 5000),
                kcal: kcal, protein: protein ?? 0, carbs: carbs ?? 0, fat: fat ?? 0
            ))
        }
        guard !items.isEmpty else { return .failure(.empty) }
        let sources = (raw.sources ?? []).filter { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
        return .success(NutritionResult(items: items, sources: Array(sources.prefix(5))))
    }

    // MARK: Putting numbers into a sets table

    private static func matches(_ column: String, any words: [String]) -> Bool {
        let name = column.lowercased()
        return words.contains { name.contains($0) }
    }

    /// One sets-table row for a food, matching the table's column names (سعرات, بروتين, كارب, دهون, جرام…).
    /// A table without recognisable names is filled as calories, protein, carbs, fat in that order.
    public static func row(for item: NutritionItem, columns: [String]) -> SetRow {
        func value(for column: String) -> Double? {
            if matches(column, any: ["سعر", "kcal", "cal", "طاقة"]) { return item.kcal }
            if matches(column, any: ["بروتين", "protein"]) { return item.protein }
            if matches(column, any: ["كارب", "كربو", "carb"]) { return item.carbs }
            if matches(column, any: ["دهون", "دهن", "fat"]) { return item.fat }
            if matches(column, any: ["جرام", "غرام", "جم", "gram", "الكمية"]) { return item.grams }
            return nil
        }
        let named = columns.map(value(for:))
        if named.contains(where: { $0 != nil }) { return SetRow(values: named) }
        let order = [item.kcal, item.protein, item.carbs, item.fat]
        return SetRow(values: (0..<max(columns.count, 1)).map { $0 < order.count ? order[$0] : nil })
    }
}

/// Remembers recent lookups so repeating a food doesn't ask the AI again. Oldest entries are dropped first.
public struct NutritionCache: Codable, Equatable, Sendable {
    public private(set) var order: [String] = []
    public private(set) var entries: [String: NutritionResult] = [:]
    public static let limit = 200

    public init() {}

    /// Same food, same key: ignores case, extra spaces and Arabic diacritics/kashida.
    public static func key(_ text: String) -> String {
        let removable = CharacterSet(charactersIn: "\u{0640}\u{064B}\u{064C}\u{064D}\u{064E}\u{064F}\u{0650}\u{0651}\u{0652}")
        let cleaned = text.unicodeScalars.filter { !removable.contains($0) }.map(String.init).joined()
        return cleaned.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    public func result(for text: String) -> NutritionResult? { entries[Self.key(text)] }

    public mutating func store(_ result: NutritionResult, for text: String) {
        let key = Self.key(text)
        guard !key.isEmpty else { return }
        order.removeAll { $0 == key }
        order.append(key)
        entries[key] = result
        while order.count > Self.limit {
            let oldest = order.removeFirst()
            entries[oldest] = nil
        }
    }
}
