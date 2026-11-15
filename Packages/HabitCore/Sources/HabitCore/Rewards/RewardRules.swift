import Foundation

/// What the owner must reach to unlock a self-made reward.
public enum RewardCondition: Equatable, Sendable {
    case level(Int)
    case streak(Int)            // best streak
    case totalTasks(Int)
    case perfectDays(Int)       // complete days
    case achievement(String)
    case points(Int)            // costs this many points when claimed

    public var cost: Int {
        if case .points(let n) = self { return n }
        return 0
    }
}

public enum RewardState: String, Sendable {
    case locked, unlocked, claimed
}

public struct RewardContext: Equatable, Sendable {
    public var level: Int
    public var bestStreak: Int
    public var totalTasks: Int
    public var perfectDays: Int
    public var unlockedAchievements: Set<String>
    public var pointsBalance: Int

    public init(level: Int = 1, bestStreak: Int = 0, totalTasks: Int = 0, perfectDays: Int = 0,
                unlockedAchievements: Set<String> = [], pointsBalance: Int = 0) {
        self.level = level
        self.bestStreak = bestStreak
        self.totalTasks = totalTasks
        self.perfectDays = perfectDays
        self.unlockedAchievements = unlockedAchievements
        self.pointsBalance = pointsBalance
    }
}

public enum RewardEvaluator {
    public static func progress(of condition: RewardCondition, context: RewardContext) -> AchievementProgress {
        switch condition {
        case .level(let n): return AchievementProgress(current: min(context.level, n), target: n)
        case .streak(let n): return AchievementProgress(current: min(context.bestStreak, n), target: n)
        case .totalTasks(let n): return AchievementProgress(current: min(context.totalTasks, n), target: n)
        case .perfectDays(let n): return AchievementProgress(current: min(context.perfectDays, n), target: n)
        case .achievement(let id):
            return AchievementProgress(current: context.unlockedAchievements.contains(id) ? 1 : 0, target: 1)
        case .points(let n): return AchievementProgress(current: min(max(context.pointsBalance, 0), n), target: n)
        }
    }

    public static func state(of condition: RewardCondition, claimed: Bool, context: RewardContext) -> RewardState {
        if claimed { return .claimed }
        return progress(of: condition, context: context).isMet ? .unlocked : .locked
    }
}
