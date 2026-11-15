import Foundation

public enum ShopCategory: String, CaseIterable, Sendable {
    case theme      // accent colors
    case frame      // level-card frame
    case effect     // celebration effect
    case liveStyle  // Live Activity / widget progress bar style
    case appIcon    // alternate home-screen icon
}

public struct ShopItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let category: ShopCategory
    public let name: String
    public let price: Int
    public let requiredLevel: Int

    public init(id: String, category: ShopCategory, name: String, price: Int, requiredLevel: Int = 1) {
        self.id = id
        self.category = category
        self.name = name
        self.price = price
        self.requiredLevel = requiredLevel
    }

    public var isFree: Bool { price == 0 }
}

/// Cosmetic only: nothing here can touch streak rules or give XP.
public enum ShopCatalog {
    public static let defaultTheme = "theme.default"
    public static let defaultFrame = "frame.none"
    public static let defaultEffect = "effect.confetti"
    public static let defaultLiveStyle = "live.default"
    public static let defaultIcon = "icon.default"

    public static let all: [ShopItem] = [
        ShopItem(id: "theme.default", category: .theme, name: "الافتراضي", price: 0),
        ShopItem(id: "theme.ocean", category: .theme, name: "محيط", price: 30),
        ShopItem(id: "theme.violet", category: .theme, name: "بنفسجي", price: 30),
        ShopItem(id: "theme.sunset", category: .theme, name: "غروب", price: 40, requiredLevel: 3),
        ShopItem(id: "theme.rose", category: .theme, name: "وردي", price: 40, requiredLevel: 3),
        ShopItem(id: "theme.graphite", category: .theme, name: "رمادي فحمي", price: 50, requiredLevel: 5),
        ShopItem(id: "theme.teal", category: .theme, name: "فيروزي", price: 40, requiredLevel: 4),
        ShopItem(id: "theme.indigo", category: .theme, name: "نيلي", price: 50, requiredLevel: 6),
        ShopItem(id: "theme.crimson", category: .theme, name: "قرمزي", price: 60, requiredLevel: 8),
        ShopItem(id: "theme.gold", category: .theme, name: "ذهبي", price: 90, requiredLevel: 12),

        ShopItem(id: "frame.none", category: .frame, name: "بدون إطار", price: 0),
        ShopItem(id: "frame.silver", category: .frame, name: "إطار فضي", price: 40, requiredLevel: 3),
        ShopItem(id: "frame.gold", category: .frame, name: "إطار ذهبي", price: 80, requiredLevel: 10),
        ShopItem(id: "frame.double", category: .frame, name: "إطار مزدوج", price: 120, requiredLevel: 20),
        ShopItem(id: "frame.dashed", category: .frame, name: "إطار منقّط", price: 50, requiredLevel: 6),
        ShopItem(id: "frame.glow", category: .frame, name: "إطار متوهّج", price: 100, requiredLevel: 15),
        ShopItem(id: "frame.rainbow", category: .frame, name: "إطار قوس قزح", price: 150, requiredLevel: 25),

        ShopItem(id: "effect.confetti", category: .effect, name: "قصاصات ملونة", price: 0),
        ShopItem(id: "effect.gold", category: .effect, name: "مطر ذهبي", price: 50, requiredLevel: 5),
        ShopItem(id: "effect.stars", category: .effect, name: "نجوم", price: 60, requiredLevel: 8),
        ShopItem(id: "effect.hearts", category: .effect, name: "قلوب", price: 60, requiredLevel: 6),
        ShopItem(id: "effect.bubbles", category: .effect, name: "فقاعات", price: 70, requiredLevel: 10),
        ShopItem(id: "effect.flames", category: .effect, name: "شرارات نار", price: 90, requiredLevel: 15),

        ShopItem(id: "live.default", category: .liveStyle, name: "شرائح مستديرة", price: 0),
        ShopItem(id: "live.blocks", category: .liveStyle, name: "مربعات", price: 40, requiredLevel: 3),
        ShopItem(id: "live.dots", category: .liveStyle, name: "دوائر", price: 50, requiredLevel: 5),
        ShopItem(id: "live.thin", category: .liveStyle, name: "خطوط رفيعة", price: 40, requiredLevel: 4),
        ShopItem(id: "live.stars", category: .liveStyle, name: "نجوم", price: 70, requiredLevel: 10),

        ShopItem(id: "icon.default", category: .appIcon, name: "الأخضر الأصلي", price: 0),
        ShopItem(id: "icon.night", category: .appIcon, name: "ليلي", price: 40, requiredLevel: 2),
        ShopItem(id: "icon.ocean", category: .appIcon, name: "محيط", price: 40, requiredLevel: 3),
        ShopItem(id: "icon.violet", category: .appIcon, name: "بنفسجي", price: 40, requiredLevel: 3),
        ShopItem(id: "icon.sunset", category: .appIcon, name: "غروب", price: 50, requiredLevel: 4),
        ShopItem(id: "icon.rose", category: .appIcon, name: "وردي", price: 50, requiredLevel: 4),
        ShopItem(id: "icon.graphite", category: .appIcon, name: "رمادي فحمي", price: 60, requiredLevel: 6),
        ShopItem(id: "icon.teal", category: .appIcon, name: "فيروزي", price: 50, requiredLevel: 5),
        ShopItem(id: "icon.indigo", category: .appIcon, name: "نيلي", price: 60, requiredLevel: 7),
        ShopItem(id: "icon.crimson", category: .appIcon, name: "قرمزي", price: 70, requiredLevel: 9),
        ShopItem(id: "icon.gold", category: .appIcon, name: "ذهبي", price: 100, requiredLevel: 12)
    ]

    public static func item(id: String) -> ShopItem? { all.first { $0.id == id } }

    public static func items(in category: ShopCategory) -> [ShopItem] { all.filter { $0.category == category } }

    public static func defaultID(for category: ShopCategory) -> String {
        switch category {
        case .theme: return defaultTheme
        case .frame: return defaultFrame
        case .effect: return defaultEffect
        case .liveStyle: return defaultLiveStyle
        case .appIcon: return defaultIcon
        }
    }

    public enum Availability: Equatable, Sendable {
        case owned
        case levelTooLow(required: Int)
        case notEnoughPoints(missing: Int)
        case purchasable
    }

    public static func availability(of item: ShopItem, owned: Set<String>, level: Int, pointsBalance: Int) -> Availability {
        if item.isFree || owned.contains(item.id) { return .owned }
        if level < item.requiredLevel { return .levelTooLow(required: item.requiredLevel) }
        if pointsBalance < item.price { return .notEnoughPoints(missing: item.price - pointsBalance) }
        return .purchasable
    }
}
