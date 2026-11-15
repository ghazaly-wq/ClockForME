import Foundation

/// Everything the achievement rules look at. All derived from history except `unlocked`.
public struct AchievementStats: Equatable, Sendable {
    public var completedTasks: Int
    public var completeDays: Int
    public var currentStreak: Int
    public var bestStreak: Int
    public var longestCompleteRun: Int
    public var comebacks: Int
    /// Level from task/day/streak XP only (achievement bonuses excluded, to avoid a loop).
    public var baseLevel: Int

    public init(completedTasks: Int = 0, completeDays: Int = 0, currentStreak: Int = 0, bestStreak: Int = 0,
                longestCompleteRun: Int = 0, comebacks: Int = 0, baseLevel: Int = 1) {
        self.completedTasks = completedTasks
        self.completeDays = completeDays
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.longestCompleteRun = longestCompleteRun
        self.comebacks = comebacks
        self.baseLevel = baseLevel
    }
}

public enum AchievementCondition: Equatable, Sendable {
    case streak(Int)        // best streak reached
    case tasks(Int)         // total tasks completed
    case completeDays(Int)  // total complete days
    case completeRun(Int)   // consecutive complete days
    case level(Int)         // base level
    case comeback           // came back after being away
}

public struct AchievementDef: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let symbol: String
    public let condition: AchievementCondition
    public let xp: Int
    public let points: Int
    /// Hidden ones show "؟؟؟" until unlocked.
    public let hidden: Bool

    public init(id: String, name: String, detail: String, symbol: String, condition: AchievementCondition,
                xp: Int, points: Int, hidden: Bool = false) {
        self.id = id
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.condition = condition
        self.xp = xp
        self.points = points
        self.hidden = hidden
    }
}

public enum AchievementCatalog {
    public static let all: [AchievementDef] = [
        AchievementDef(id: "tasks.1", name: "البداية", detail: "أكمل أول مهمة", symbol: "flag.fill", condition: .tasks(1), xp: 10, points: 1),
        AchievementDef(id: "tasks.10", name: "عشر خطوات", detail: "أكمل 10 مهام", symbol: "figure.walk", condition: .tasks(10), xp: 20, points: 2),
        AchievementDef(id: "tasks.100", name: "مئة إنجاز", detail: "أكمل 100 مهمة", symbol: "checkmark.seal.fill", condition: .tasks(100), xp: 60, points: 6),
        AchievementDef(id: "tasks.500", name: "عامل مجتهد", detail: "أكمل 500 مهمة", symbol: "hammer.fill", condition: .tasks(500), xp: 150, points: 15),
        AchievementDef(id: "tasks.1000", name: "الألف", detail: "أكمل 1000 مهمة", symbol: "crown.fill", condition: .tasks(1000), xp: 300, points: 30),

        AchievementDef(id: "days.1", name: "يوم مكتمل", detail: "أنجز كل مهام يوم كامل", symbol: "sun.max.fill", condition: .completeDays(1), xp: 15, points: 2),
        AchievementDef(id: "days.10", name: "عشرة أيام كاملة", detail: "أكمل 10 أيام", symbol: "calendar.badge.checkmark", condition: .completeDays(10), xp: 50, points: 5),
        AchievementDef(id: "days.50", name: "خمسون يوماً", detail: "أكمل 50 يوماً", symbol: "calendar", condition: .completeDays(50), xp: 120, points: 12),
        AchievementDef(id: "days.100", name: "مئة يوم", detail: "أكمل 100 يوم", symbol: "star.circle.fill", condition: .completeDays(100), xp: 250, points: 25),

        AchievementDef(id: "streak.3", name: "شرارة", detail: "سلسلة 3 أيام", symbol: "flame", condition: .streak(3), xp: 15, points: 2),
        AchievementDef(id: "streak.7", name: "أسبوع متواصل", detail: "سلسلة 7 أيام", symbol: "flame.fill", condition: .streak(7), xp: 25, points: 3),
        AchievementDef(id: "streak.30", name: "شهر من الالتزام", detail: "سلسلة 30 يوماً", symbol: "bolt.fill", condition: .streak(30), xp: 75, points: 8),
        AchievementDef(id: "streak.100", name: "المئة", detail: "سلسلة 100 يوم", symbol: "trophy.fill", condition: .streak(100), xp: 200, points: 20),
        AchievementDef(id: "streak.365", name: "سنة كاملة", detail: "سلسلة 365 يوماً", symbol: "medal.fill", condition: .streak(365), xp: 500, points: 50),

        AchievementDef(id: "run.7", name: "أسبوع مثالي", detail: "7 أيام مكتملة متتالية", symbol: "checkmark.circle.fill", condition: .completeRun(7), xp: 60, points: 6),

        AchievementDef(id: "level.5", name: "مثابر", detail: "اصل إلى المستوى 5", symbol: "5.circle.fill", condition: .level(5), xp: 40, points: 4),
        AchievementDef(id: "level.10", name: "منضبط", detail: "اصل إلى المستوى 10", symbol: "10.circle.fill", condition: .level(10), xp: 100, points: 10),
        AchievementDef(id: "level.25", name: "متقن", detail: "اصل إلى المستوى 25", symbol: "25.circle.fill", condition: .level(25), xp: 250, points: 25),
        AchievementDef(id: "level.50", name: "أسطورة", detail: "اصل إلى المستوى 50", symbol: "50.circle.fill", condition: .level(50), xp: 600, points: 60),

        AchievementDef(id: "hidden.comeback", name: "العودة", detail: "أكمل يوماً بعد غياب 3 أيام أو أكثر", symbol: "arrow.uturn.up.circle.fill", condition: .comeback, xp: 40, points: 4, hidden: true),
        AchievementDef(id: "hidden.run30", name: "شهر لا ينكسر", detail: "30 يوماً مكتملاً متتالياً", symbol: "infinity.circle.fill", condition: .completeRun(30), xp: 150, points: 15, hidden: true)
    ]

    public static func definition(id: String) -> AchievementDef? {
        all.first { $0.id == id }
    }
}

public struct AchievementProgress: Equatable, Sendable {
    public let current: Int
    public let target: Int
    public var isMet: Bool { current >= target }
    public var fraction: Double { target == 0 ? 1 : min(1, Double(current) / Double(target)) }
}

public enum AchievementEvaluator {
    public static func progress(of def: AchievementDef, stats: AchievementStats) -> AchievementProgress {
        switch def.condition {
        case .streak(let n): return AchievementProgress(current: min(stats.bestStreak, n), target: n)
        case .tasks(let n): return AchievementProgress(current: min(stats.completedTasks, n), target: n)
        case .completeDays(let n): return AchievementProgress(current: min(stats.completeDays, n), target: n)
        case .completeRun(let n): return AchievementProgress(current: min(stats.longestCompleteRun, n), target: n)
        case .level(let n): return AchievementProgress(current: min(stats.baseLevel, n), target: n)
        case .comeback: return AchievementProgress(current: min(stats.comebacks, 1), target: 1)
        }
    }

    /// Achievements met now that are not yet recorded as unlocked.
    public static func newlyUnlocked(stats: AchievementStats, alreadyUnlocked: Set<String>) -> [AchievementDef] {
        AchievementCatalog.all.filter { !alreadyUnlocked.contains($0.id) && progress(of: $0, stats: stats).isMet }
    }

    /// XP and points granted by the unlocked achievements (unknown ids are ignored).
    public static func bonus(unlocked: Set<String>) -> (xp: Int, points: Int) {
        var xp = 0, points = 0
        for id in unlocked {
            if let def = AchievementCatalog.definition(id: id) { xp += def.xp; points += def.points }
        }
        return (xp, points)
    }
}
