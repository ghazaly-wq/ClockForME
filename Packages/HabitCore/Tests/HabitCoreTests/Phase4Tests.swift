import XCTest
@testable import HabitCore

final class Phase4Tests: XCTestCase {
    private let cal = TestSupport.calendar

    private func d(_ y: Int, _ m: Int, _ day: Int) -> DayKey { DayKey(year: y, month: m, day: day) }

    private func progress(_ states: [(Int, DayProgress)], base: DayKey) -> [DayKey: DayProgress] {
        var out: [DayKey: DayProgress] = [:]
        for (offset, p) in states { out[base.adding(days: offset, calendar: cal)!] = p }
        return out
    }
    private let full = DayProgress(total: 2, completed: 2)
    private let half = DayProgress(total: 2, completed: 1)
    private let zero = DayProgress(total: 2, completed: 0)

    func testCompleteRunAndNeutralDays() {
        let base = d(2026, 3, 1)
        let history = progress([(0, full), (1, full), (2, DayProgress(total: 0, completed: 0)), (3, full), (4, half), (5, full)], base: base)
        let stats = HistoryStats.compute(progressByDay: history, today: d(2026, 3, 6), calendar: cal)
        XCTAssertEqual(stats.longestCompleteRun, 3)
    }

    func testComebackAfterGrace() {
        let base = d(2026, 3, 1)
        let history = progress([(0, full), (1, zero), (2, zero), (3, zero), (4, full)], base: base)
        XCTAssertEqual(HistoryStats.compute(progressByDay: history, today: d(2026, 3, 5), calendar: cal).comebacks, 1)
        let short = progress([(0, full), (1, zero), (2, zero), (3, full)], base: base)
        XCTAssertEqual(HistoryStats.compute(progressByDay: short, today: d(2026, 3, 4), calendar: cal).comebacks, 0)
    }

    func testTodayPartialDoesNotBreakRun() {
        let base = d(2026, 3, 1)
        let history = progress([(0, full), (1, full), (2, half)], base: base)
        XCTAssertEqual(HistoryStats.compute(progressByDay: history, today: d(2026, 3, 3), calendar: cal).longestCompleteRun, 2)
    }

    func testAchievementCatalogIsConsistent() {
        let ids = AchievementCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(AchievementCatalog.all.allSatisfy { $0.xp > 0 && $0.points > 0 })
    }

    func testNewlyUnlockedAndProgress() {
        let stats = AchievementStats(completedTasks: 12, completeDays: 1, currentStreak: 3, bestStreak: 3, baseLevel: 2)
        let ids = Set(AchievementEvaluator.newlyUnlocked(stats: stats, alreadyUnlocked: []).map(\.id))
        XCTAssertEqual(ids, ["tasks.1", "tasks.10", "days.1", "streak.3"])
        let again = AchievementEvaluator.newlyUnlocked(stats: stats, alreadyUnlocked: ids)
        XCTAssertTrue(again.isEmpty)
        let p = AchievementEvaluator.progress(of: AchievementCatalog.definition(id: "tasks.100")!, stats: stats)
        XCTAssertEqual(p.current, 12)
        XCTAssertEqual(p.target, 100)
        XCTAssertFalse(p.isMet)
    }

    func testBonusIgnoresUnknownIDs() {
        let b = AchievementEvaluator.bonus(unlocked: ["tasks.1", "streak.3", "nope"])
        XCTAssertEqual(b.xp, 25)
        XCTAssertEqual(b.points, 3)
    }

    func testRewardStates() {
        var ctx = RewardContext(level: 5, bestStreak: 10, totalTasks: 40, perfectDays: 4, pointsBalance: 30)
        XCTAssertEqual(RewardEvaluator.state(of: .level(5), claimed: false, context: ctx), .unlocked)
        XCTAssertEqual(RewardEvaluator.state(of: .streak(30), claimed: false, context: ctx), .locked)
        XCTAssertEqual(RewardEvaluator.state(of: .points(50), claimed: false, context: ctx), .locked)
        XCTAssertEqual(RewardEvaluator.state(of: .points(30), claimed: false, context: ctx), .unlocked)
        XCTAssertEqual(RewardEvaluator.state(of: .points(30), claimed: true, context: ctx), .claimed)
        ctx.unlockedAchievements = ["tasks.1"]
        XCTAssertEqual(RewardEvaluator.state(of: .achievement("tasks.1"), claimed: false, context: ctx), .unlocked)
        XCTAssertEqual(RewardCondition.points(30).cost, 30)
        XCTAssertEqual(RewardCondition.level(3).cost, 0)
    }

    func testShopAvailability() {
        let gold = ShopCatalog.item(id: "frame.gold")!
        XCTAssertEqual(ShopCatalog.availability(of: gold, owned: [], level: 5, pointsBalance: 500), .levelTooLow(required: 10))
        XCTAssertEqual(ShopCatalog.availability(of: gold, owned: [], level: 10, pointsBalance: 50), .notEnoughPoints(missing: 30))
        XCTAssertEqual(ShopCatalog.availability(of: gold, owned: [], level: 10, pointsBalance: 80), .purchasable)
        XCTAssertEqual(ShopCatalog.availability(of: gold, owned: ["frame.gold"], level: 1, pointsBalance: 0), .owned)
        XCTAssertEqual(ShopCatalog.availability(of: ShopCatalog.item(id: "theme.default")!, owned: [], level: 1, pointsBalance: 0), .owned)
        for c in ShopCategory.allCases { XCTAssertNotNil(ShopCatalog.item(id: ShopCatalog.defaultID(for: c))) }
    }

    func testWeeklyCompletionAndHeatmap() {
        // 2026-03-01 is a Sunday; calendar is Sunday-first.
        let base = d(2026, 3, 1)
        let history = progress([(0, full), (1, half), (7, full)], base: base)
        let today = d(2026, 3, 9)
        let weeks = StatsCalculator.weeklyCompletion(progressByDay: history, today: today, weeks: 2, calendar: cal)
        XCTAssertEqual(weeks.count, 2)
        XCTAssertEqual(weeks[0].start, base)
        XCTAssertEqual(weeks[0].fraction, 0.75, accuracy: 0.0001)
        XCTAssertEqual(weeks[1].fraction, 1, accuracy: 0.0001)
        let cells = StatsCalculator.heatmap(progressByDay: history, today: today, weeks: 2, calendar: cal)
        XCTAssertEqual(cells.count, 9)
        XCTAssertEqual(cells.first?.state, .complete)
        XCTAssertEqual(cells.last?.row, 1)
        XCTAssertEqual(cells.last?.column, 1)
    }

    func testXPTimelineIsCumulative() {
        let base = d(2026, 3, 1)
        let history = progress([(0, full), (1, half)], base: base)
        let counts: [DayKey: Int] = [base: 2, base.adding(days: 1, calendar: cal)!: 1]
        let line = StatsCalculator.xpTimeline(completedTasksByDay: counts, progressByDay: history, from: base, to: d(2026, 3, 2), calendar: cal)
        XCTAssertEqual(line.map(\.cumulativeXP), [40, 50])
    }
}

final class AchievementExtraTests: XCTestCase {
    struct FixedPrayers: PrayerTimeProviding {
        func times(for day: DayKey, calendar: Calendar) -> [Prayer: Date]? {
            let base = Date(timeIntervalSince1970: 1_800_000_000)
            return [.dhuhr: base.addingTimeInterval(12 * 3600), .isha: base.addingTimeInterval(20 * 3600)]
        }
    }

    func testTimingCounts() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let cal = Calendar(identifier: .gregorian)
        let d1 = DayKey(year: 2027, month: 1, day: 1), d2 = DayKey(year: 2027, month: 1, day: 2), d3 = DayKey(year: 2027, month: 1, day: 3)
        let counts = AchievementTiming.counts(
            finishedAt: [d1: base.addingTimeInterval(11 * 3600), d2: base.addingTimeInterval(21 * 3600), d3: base.addingTimeInterval(15 * 3600)],
            provider: FixedPrayers(), calendar: cal)
        XCTAssertEqual(counts, AchievementTiming.Counts(earlyBirdDays: 1, nightFinisherDays: 1))
        XCTAssertEqual(AchievementTiming.counts(finishedAt: [d1: base], provider: nil, calendar: cal), AchievementTiming.Counts())
    }

    func testNewConditions() {
        let stats = AchievementStats(completedTasks: 30, completeDays: 5, comebacks: 3, secondaryTasks: 25,
                                     biggestCompleteDay: 5, earlyBirdDays: 1, nightFinisherDays: 0, pagesCreated: 1, pageSessions: 9)
        let ids = Set(AchievementEvaluator.newlyUnlocked(stats: stats, alreadyUnlocked: []).map(\.id))
        XCTAssertTrue(ids.isSuperset(of: ["tasks.25", "days.5", "hidden.comeback3", "secondary.25", "bigday.5", "early.1", "page.1"]))
        XCTAssertFalse(ids.contains("night.1"))
        XCTAssertFalse(ids.contains("sessions.10"))
        XCTAssertEqual(AchievementCatalog.all.count, 48)
    }

    func testBiggestCompleteDay() {
        let cal = Calendar(identifier: .gregorian)
        let d1 = DayKey(year: 2027, month: 1, day: 1), d2 = DayKey(year: 2027, month: 1, day: 2)
        let h = HistoryStats.compute(
            progressByDay: [d1: DayProgress(total: 3, completed: 3), d2: DayProgress(total: 6, completed: 4)],
            today: d2, calendar: cal)
        XCTAssertEqual(h.biggestCompleteDay, 3)
    }
}
