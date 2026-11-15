import Foundation
import HabitCore
import SwiftData

/// An achievement the owner has unlocked. Kept once earned: undoing a task later does not take it back.
@Model
final class AchievementUnlockRecord {
    @Attribute(.unique) var achievementID: String
    var unlockedAt: Date

    init(achievementID: String, unlockedAt: Date = Date()) {
        self.achievementID = achievementID
        self.unlockedAt = unlockedAt
    }
}

/// A shop item the owner bought. Spent points are derived from these.
@Model
final class PurchaseRecord {
    @Attribute(.unique) var itemID: String
    var price: Int
    var purchasedAt: Date

    init(itemID: String, price: Int, purchasedAt: Date = Date()) {
        self.itemID = itemID
        self.price = price
        self.purchasedAt = purchasedAt
    }
}

enum RewardKind: String, CaseIterable, Identifiable {
    case level, streak, tasks, days, achievement, points

    var id: String { rawValue }

    var label: String {
        switch self {
        case .level: return String(localized: "الوصول لمستوى")
        case .streak: return String(localized: "سلسلة أيام")
        case .tasks: return String(localized: "عدد المهام المنجزة")
        case .days: return String(localized: "عدد الأيام المكتملة")
        case .achievement: return String(localized: "فتح إنجاز")
        case .points: return String(localized: "دفع نقاط")
        }
    }

    var defaultTarget: Int {
        switch self {
        case .level: return 5
        case .streak: return 7
        case .tasks: return 50
        case .days: return 10
        case .achievement: return 1
        case .points: return 50
        }
    }

    var step: Int {
        switch self {
        case .level, .streak, .days, .achievement: return 1
        case .tasks: return 10
        case .points: return 5
        }
    }
}

/// A reward the owner defined for themselves ("جوائزي").
@Model
final class RewardRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String
    var kindRaw: String
    var target: Int
    var achievementID: String
    var createdAt: Date
    var claimedAt: Date?
    /// Points paid when it was claimed (only for "pay points" rewards).
    var claimedCost: Int

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        kind: RewardKind,
        target: Int,
        achievementID: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.kindRaw = kind.rawValue
        self.target = target
        self.achievementID = achievementID
        self.createdAt = createdAt
        self.claimedAt = nil
        self.claimedCost = 0
    }
}

extension RewardRecord {
    var kind: RewardKind {
        get { RewardKind(rawValue: kindRaw) ?? .level }
        set { kindRaw = newValue.rawValue }
    }

    var isClaimed: Bool { claimedAt != nil }

    var condition: RewardCondition {
        switch kind {
        case .level: return .level(target)
        case .streak: return .streak(target)
        case .tasks: return .totalTasks(target)
        case .days: return .perfectDays(target)
        case .achievement: return .achievement(achievementID)
        case .points: return .points(target)
        }
    }
}
