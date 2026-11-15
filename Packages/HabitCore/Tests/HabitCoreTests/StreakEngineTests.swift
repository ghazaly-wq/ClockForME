import XCTest
@testable import HabitCore

final class StreakEngineTests: XCTestCase {
    private let cal = TestSupport.calendar
    private let start = TestSupport.day(2026, 11, 1)

    /// Runs the engine over `pattern`, evaluated on the day after it (so every day has ended).
    private func run(_ pattern: String, from start: DayKey? = nil) -> StreakResult {
        let h = TestSupport.history(pattern, from: start ?? self.start)
        return StreakEngine.compute(progressByDay: h.progress, today: h.next, calendar: cal)
    }

    func testEmptyHistory() {
        let r = StreakEngine.compute(progressByDay: [:], today: start, calendar: cal)
        XCTAssertEqual(r, StreakResult(current: 0, best: 0, missedRun: 0, completeDays: 0))
    }

    func testCompleteDaysIncreaseTheStreak() {
        let r = run("CCC")
        XCTAssertEqual(r.current, 3)
        XCTAssertEqual(r.best, 3)
        XCTAssertEqual(r.completeDays, 3)
    }

    func testPartialDayHoldsTheStreak() {
        let r = run("CCP")
        XCTAssertEqual(r.current, 2)
        XCTAssertEqual(r.missedRun, 0)
    }

    func testPartialDaysForeverNeverDropTheStreak() {
        XCTAssertEqual(run("CCPPPPPPPPPP").current, 2)
    }

    func testFirstThreeMissedDaysChangeNothing() {
        XCTAssertEqual(run("CC0").current, 2)
        XCTAssertEqual(run("CC00").current, 2)
        XCTAssertEqual(run("CC000").current, 2)
        XCTAssertEqual(run("CC000").missedRun, 3)
    }

    func testFromTheFourthMissedDayTheStreakDropsByOnePerDay() {
        XCTAssertEqual(run("CC0000").current, 1)
        XCTAssertEqual(run("CC00000").current, 0)
    }

    func testStreakNeverGoesBelowZero() {
        XCTAssertEqual(run("CC0000000000").current, 0)
        XCTAssertEqual(run("0000000").current, 0)
    }

    func testBestStreakIsKeptAfterDrops() {
        let r = run("CCCCC000000")   // 5, then 6 missed: drops on missed days 4, 5, 6
        XCTAssertEqual(r.best, 5)
        XCTAssertEqual(r.current, 2)
    }

    func testPartialDayResetsTheMissedRun() {
        // 2 misses, a partial day, then 1 miss: the run restarts, so nothing drops.
        let r = run("CC00P0")
        XCTAssertEqual(r.current, 2)
        XCTAssertEqual(r.missedRun, 1)
    }

    func testCompletingADayContinuesFromCurrentValueNotZero() {
        // 4th missed day drops 3 → 2, then a complete day continues to 3.
        let r = run("CCC0000C")
        XCTAssertEqual(r.current, 3)
        XCTAssertEqual(r.missedRun, 0)
    }

    func testCompleteDayResetsMissedRun() {
        let r = run("CC00C00")
        XCTAssertEqual(r.current, 3)
        XCTAssertEqual(r.missedRun, 2)
    }

    func testDaysWithoutTasksAreNeutral() {
        // Missed days separated by no-task days still add up; the gaps neither count nor reset.
        XCTAssertEqual(run("CC0-0-0").current, 2)
        XCTAssertEqual(run("CC0-0-00").current, 1)
        XCTAssertEqual(run("CC---------").current, 2)
    }

    func testTodayCountsOnlyWhenComplete() {
        let h = TestSupport.history("CC", from: start)
        var progress = h.progress

        progress[h.next] = DayProgress(total: 3, completed: 3)
        XCTAssertEqual(StreakEngine.compute(progressByDay: progress, today: h.next, calendar: cal).current, 3)

        progress[h.next] = DayProgress(total: 3, completed: 1)
        XCTAssertEqual(StreakEngine.compute(progressByDay: progress, today: h.next, calendar: cal).current, 2)

        progress[h.next] = DayProgress(total: 3, completed: 0)
        let zero = StreakEngine.compute(progressByDay: progress, today: h.next, calendar: cal)
        XCTAssertEqual(zero.current, 2)
        XCTAssertEqual(zero.missedRun, 0)   // today is never "missed" before it ends
    }

    func testIncompleteTodayDoesNotUseUpTheGrace() {
        // 3 missed days, today still at 0%: streak must not drop yet.
        let h = TestSupport.history("CC000", from: start)
        var progress = h.progress
        progress[h.next] = DayProgress(total: 3, completed: 0)
        XCTAssertEqual(StreakEngine.compute(progressByDay: progress, today: h.next, calendar: cal).current, 2)
    }

    func testStreakAcrossMonthAndYearBoundaries() {
        XCTAssertEqual(run("CCCCC", from: TestSupport.day(2026, 11, 28)).current, 5)
        XCTAssertEqual(run("CCCC", from: TestSupport.day(2026, 12, 30)).current, 4)
        XCTAssertEqual(run("CCCCCC", from: TestSupport.day(2028, 2, 27)).current, 6)   // leap day inside
    }

    func testMissedDaysAcrossMonthBoundary() {
        // C on Nov 29, then Nov 30 + Dec 1, 2, 3 missed → the 4th miss (Dec 3) drops it.
        let r = run("C0000", from: TestSupport.day(2026, 11, 29))
        XCTAssertEqual(r.current, 0)
    }

    func testDayStartHourDecidesWhichDayAMomentBelongsTo() {
        // A task finished at 01:30 on the 15th belongs to the 14th when the day starts at 03:00.
        let finished = cal.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 1, minute: 30))!
        XCTAssertEqual(DayKey(date: finished, calendar: cal, dayStartHour: 3), TestSupport.day(2026, 11, 14))

        let h = TestSupport.history("CC", from: TestSupport.day(2026, 11, 12))
        var progress = h.progress
        let key = DayKey(date: finished, calendar: cal, dayStartHour: 3)
        progress[key] = DayProgress(total: 2, completed: 2)   // the 14th, finished after midnight
        let r = StreakEngine.compute(progressByDay: progress, today: TestSupport.day(2026, 11, 15), calendar: cal)
        XCTAssertEqual(r.current, 3)
    }

    func testRecomputingAfterEditingThePastIsConsistent() {
        // Un-completing a past day changes the result deterministically (no stale counter).
        let full = run("CCCC")
        XCTAssertEqual(full.current, 4)
        let edited = run("CCPC")
        XCTAssertEqual(edited.current, 3)
    }
}
