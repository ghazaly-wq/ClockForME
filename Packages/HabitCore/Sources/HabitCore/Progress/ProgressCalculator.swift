import Foundation

public struct StreakMilestone: Equatable, Sendable {
    public let days: Int
    public let xp: Int
    public let points: Int

    public init(days: Int, xp: Int, points: Int) {
        self.days = days
        self.xp = xp
        self.points = points
    }
}

/// Tunable constants for XP and points.
public enum ProgressRules {
    public static let xpPerTask = 10
    public static let pointsPerTask = 1
    public static let xpPerCompleteDay = 20
    public static let pointsPerCompleteDay = 3
    public static let milestones: [StreakMilestone] = [
        StreakMilestone(days: 7, xp: 50, points: 5),
        StreakMilestone(days: 14, xp: 100, points: 10),
        StreakMilestone(days: 30, xp: 200, points: 20),
        StreakMilestone(days: 60, xp: 300, points: 30),
        StreakMilestone(days: 100, xp: 500, points: 50),
        StreakMilestone(days: 200, xp: 800, points: 80),
        StreakMilestone(days: 365, xp: 1500, points: 150)
    ]
}

public enum LevelTitle: String, Codable, CaseIterable, Sendable {
    case beginner       // مبتدئ   1–4
    case persistent     // مثابر   5–9
    case disciplined    // منضبط   10–19
    case master         // متقن    20–34
    case roleModel      // قدوة    35–49
    case legend         // أسطورة  50+

    public static func title(forLevel level: Int) -> LevelTitle {
        switch level {
        case ..<5: return .beginner
        case 5..<10: return .persistent
        case 10..<20: return .disciplined
        case 20..<35: return .master
        case 35..<50: return .roleModel
        default: return .legend
        }
    }
}

public struct ProgressSummary: Equatable, Sendable {
    public let totalXP: Int
    public let points: Int
    public let level: Int
    public let xpIntoLevel: Int
    public let xpForNextLevel: Int
    public let title: LevelTitle

    public var levelFraction: Double {
        xpForNextLevel == 0 ? 0 : Double(xpIntoLevel) / Double(xpForNextLevel)
    }
}

public enum ProgressCalculator {
    /// XP needed to go from `level` to `level + 1`: 100 + 25 × (level − 1).
    public static func xpRequired(fromLevel level: Int) -> Int {
        100 + 25 * (max(level, 1) - 1)
    }

    public static func summary(totalXP: Int, points: Int) -> ProgressSummary {
        var level = 1
        var remaining = max(0, totalXP)
        while remaining >= xpRequired(fromLevel: level) {
            remaining -= xpRequired(fromLevel: level)
            level += 1
        }
        return ProgressSummary(
            totalXP: max(0, totalXP),
            points: max(0, points),
            level: level,
            xpIntoLevel: remaining,
            xpForNextLevel: xpRequired(fromLevel: level),
            title: LevelTitle.title(forLevel: level)
        )
    }

    /// Everything is derived from history, so un-completing a task or editing the past
    /// automatically revokes what it gave (no farming).
    public static func summary(
        completedTasks: Int,
        completeDays: Int,
        bestStreak: Int,
        spentPoints: Int = 0
    ) -> ProgressSummary {
        let reached = ProgressRules.milestones.filter { $0.days <= bestStreak }
        let xp = completedTasks * ProgressRules.xpPerTask
            + completeDays * ProgressRules.xpPerCompleteDay
            + reached.reduce(0) { $0 + $1.xp }
        let earnedPoints = completedTasks * ProgressRules.pointsPerTask
            + completeDays * ProgressRules.pointsPerCompleteDay
            + reached.reduce(0) { $0 + $1.points }
        return summary(totalXP: xp, points: earnedPoints - spentPoints)
    }
}
