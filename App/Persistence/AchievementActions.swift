import Foundation
import HabitCore
import SwiftData

extension Notification.Name {
    /// Posted when something outside tasks (custom pages) may have earned an achievement.
    static let achievementsNeedSync = Notification.Name("achievementsNeedSync")
}

@MainActor
enum AchievementActions {
    struct SyncResult {
        var unlocked: [AchievementDef] = []
        var newLevel: ProgressSummary?
    }

    /// Unlocks every achievement that is met but not yet recorded, and reports what changed.
    static func sync(
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        context: ModelContext,
        now: Date,
        dayStartHour: Int
    ) -> SyncResult {
        let extras = ProgressExtras.load(context: context)
        let before = ProgressSnapshot.make(
            tasks: tasks, completions: completions, now: now, dayStartHour: dayStartHour, extras: extras
        )
        let newly = AchievementEvaluator.newlyUnlocked(stats: before.achievementStats, alreadyUnlocked: extras.unlockedIDs)
        guard !newly.isEmpty else { return SyncResult() }

        for def in newly {
            context.insert(AchievementUnlockRecord(achievementID: def.id, unlockedAt: now))
        }
        try? context.save()

        let after = ProgressSnapshot.make(
            tasks: tasks, completions: completions, now: now, dayStartHour: dayStartHour,
            extras: ProgressExtras.load(context: context)
        )
        return SyncResult(
            unlocked: newly,
            newLevel: after.summary.level > before.summary.level ? after.summary : nil
        )
    }

    /// Same as `sync`, reading tasks and completions from the store (used when the app opens).
    static func syncFromStore(context: ModelContext, now: Date, dayStartHour: Int) -> SyncResult {
        let tasks = (try? context.fetch(FetchDescriptor<TaskRecord>())) ?? []
        let completions = (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? []
        return sync(tasks: tasks, completions: completions, context: context, now: now, dayStartHour: dayStartHour)
    }

    /// Claims an unlocked reward; for "pay points" rewards this spends the points.
    @discardableResult
    static func claim(_ reward: RewardRecord, snapshot: ProgressSnapshot, context: ModelContext, now: Date) -> Bool {
        guard RewardEvaluator.state(of: reward.condition, claimed: reward.isClaimed, context: snapshot.rewardContext) == .unlocked
        else { return false }
        reward.claimedAt = now
        reward.claimedCost = reward.condition.cost
        try? context.save()
        return true
    }

    @discardableResult
    static func buy(
        _ item: ShopItem,
        owned: Set<String>,
        snapshot: ProgressSnapshot,
        context: ModelContext,
        now: Date
    ) -> Bool {
        let availability = ShopCatalog.availability(
            of: item, owned: owned, level: snapshot.summary.level, pointsBalance: snapshot.summary.points
        )
        guard availability == .purchasable else { return false }
        context.insert(PurchaseRecord(itemID: item.id, price: item.price, purchasedAt: now))
        try? context.save()
        return true
    }
}
