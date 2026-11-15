import Foundation
import HabitCore
import SwiftData

extension Calendar {
    /// Gregorian, week starts on Sunday, device time zone.
    static var app: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        calendar.timeZone = TimeZone.current
        return calendar
    }
}

/// The saved things that change XP and points on top of the history:
/// unlocked achievements (bonus) and what was spent (shop purchases, claimed point rewards).
struct ProgressExtras {
    var unlockedIDs: Set<String> = []
    var spentPoints = 0
    var pagesCreated = 0
    var pageSessions = 0

    static let zero = ProgressExtras()

    init(unlockedIDs: Set<String> = [], spentPoints: Int = 0) {
        self.unlockedIDs = unlockedIDs
        self.spentPoints = spentPoints
    }

    init(
        unlocks: [AchievementUnlockRecord], purchases: [PurchaseRecord], rewards: [RewardRecord],
        pages: [PageRecord] = [], sessions: [PageSessionRecord] = []
    ) {
        unlockedIDs = Set(unlocks.map(\.achievementID))
        spentPoints = purchases.reduce(0) { $0 + $1.price } + rewards.reduce(0) { $0 + $1.claimedCost }
        pagesCreated = pages.filter { !$0.isTemplate }.count
        pageSessions = sessions.filter(\.isFinished).count
    }

    @MainActor
    static func load(context: ModelContext) -> ProgressExtras {
        let unlocks = (try? context.fetch(FetchDescriptor<AchievementUnlockRecord>())) ?? []
        let purchases = (try? context.fetch(FetchDescriptor<PurchaseRecord>())) ?? []
        let rewards = (try? context.fetch(FetchDescriptor<RewardRecord>())) ?? []
        let pages = (try? context.fetch(FetchDescriptor<PageRecord>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<PageSessionRecord>())) ?? []
        return ProgressExtras(unlocks: unlocks, purchases: purchases, rewards: rewards, pages: pages, sessions: sessions)
    }
}

/// Everything the UI shows about progress, computed from stored tasks and completions
/// by the pure rules in HabitCore. Nothing here is saved, so it can never go stale.
struct ProgressSnapshot {
    let today: DayKey
    let todayMain: DayProgress
    let streak: StreakResult
    /// Level, XP and points including achievement bonuses and spending.
    let summary: ProgressSummary
    /// Level and XP from history only (what achievement rules look at).
    let baseSummary: ProgressSummary
    let history: HistoryStats
    let progressByDay: [DayKey: DayProgress]
    let completedTasks: Int
    let unlockedIDs: Set<String>
    let secondaryCompleted: Int
    let timing: AchievementTiming.Counts
    let pagesCreated: Int
    let pageSessions: Int

    var achievementStats: AchievementStats {
        AchievementStats(
            completedTasks: completedTasks,
            completeDays: streak.completeDays,
            currentStreak: streak.current,
            bestStreak: streak.best,
            longestCompleteRun: history.longestCompleteRun,
            comebacks: history.comebacks,
            baseLevel: baseSummary.level,
            secondaryTasks: secondaryCompleted,
            biggestCompleteDay: history.biggestCompleteDay,
            earlyBirdDays: timing.earlyBirdDays,
            nightFinisherDays: timing.nightFinisherDays,
            pagesCreated: pagesCreated,
            pageSessions: pageSessions
        )
    }

    var rewardContext: RewardContext {
        RewardContext(
            level: summary.level,
            bestStreak: streak.best,
            totalTasks: completedTasks,
            perfectDays: streak.completeDays,
            unlockedAchievements: unlockedIDs,
            pointsBalance: summary.points
        )
    }

    static func make(
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        now: Date,
        dayStartHour: Int,
        calendar: Calendar = .app,
        extras: ProgressExtras = .zero
    ) -> ProgressSnapshot {
        let today = DayKey(date: now, calendar: calendar, dayStartHour: dayStartHour)
        let specs = tasks.map(\.spec)

        var completedByDay: [DayKey: Set<UUID>] = [:]
        for completion in completions {
            completedByDay[completion.day, default: []].insert(completion.taskID)
        }

        var progressByDay: [DayKey: DayProgress] = [:]
        if let first = specs.map(\.startDay).min(), first <= today {
            var day = first
            while day <= today {
                let progress = DayProgress.compute(
                    day: day, specs: specs, completedIDs: completedByDay[day] ?? [], calendar: calendar
                )
                if progress.total > 0 { progressByDay[day] = progress }
                guard let next = day.adding(days: 1, calendar: calendar) else { break }
                day = next
            }
        }

        let streak = StreakEngine.compute(progressByDay: progressByDay, today: today, calendar: calendar)
        let history = HistoryStats.compute(progressByDay: progressByDay, today: today, calendar: calendar)
        let base = ProgressCalculator.summary(
            completedTasks: completions.count,
            completeDays: streak.completeDays,
            bestStreak: streak.best
        )
        let bonus = AchievementEvaluator.bonus(unlocked: extras.unlockedIDs)
        let summary = ProgressCalculator.summary(
            totalXP: base.totalXP + bonus.xp,
            points: base.points + bonus.points - extras.spentPoints
        )
        let todayMain = progressByDay[today]
            ?? DayProgress.compute(day: today, specs: specs, completedIDs: completedByDay[today] ?? [], calendar: calendar)

        let mainIDs = Set(tasks.filter { $0.kind == .main }.map(\.id))
        let secondaryCompleted = completions.filter { !mainIDs.contains($0.taskID) }.count
        var finishedAt: [DayKey: Date] = [:]
        for completion in completions where mainIDs.contains(completion.taskID) {
            guard progressByDay[completion.day]?.state == .complete else { continue }
            finishedAt[completion.day] = max(finishedAt[completion.day] ?? .distantPast, completion.completedAt)
        }
        let defaults = UserDefaults.standard
        let provider: AdhanPrayerTimes? = defaults.bool(forKey: SettingsKey.hasPrayerLocation)
            ? AdhanPrayerTimes(
                latitude: defaults.double(forKey: SettingsKey.prayerLatitude),
                longitude: defaults.double(forKey: SettingsKey.prayerLongitude))
            : nil
        let timing = AchievementTiming.counts(finishedAt: finishedAt, provider: provider, calendar: calendar)

        return ProgressSnapshot(
            today: today,
            todayMain: todayMain,
            streak: streak,
            summary: summary,
            baseSummary: base,
            history: history,
            progressByDay: progressByDay,
            completedTasks: completions.count,
            unlockedIDs: extras.unlockedIDs,
            secondaryCompleted: secondaryCompleted,
            timing: timing,
            pagesCreated: extras.pagesCreated,
            pageSessions: extras.pageSessions
        )
    }
}
