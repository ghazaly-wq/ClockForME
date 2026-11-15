import XCTest
@testable import HabitCore

private struct FixedDay: PrayerTimeProviding {
    func times(for day: DayKey, calendar: Calendar) -> [Prayer: Date]? {
        guard let start = day.startDate(calendar: calendar) else { return nil }
        return [.fajr: start.addingTimeInterval(5 * 3600), .dhuhr: start.addingTimeInterval(12 * 3600),
                .asr: start.addingTimeInterval(15 * 3600), .maghrib: start.addingTimeInterval(18 * 3600),
                .isha: start.addingTimeInterval(19.5 * 3600)]
    }
}

final class HomeLogicTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
        return c
    }
    private func at(_ d: Int, _ h: Int, _ m: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 3, day: d, hour: h, minute: m))!
    }

    func testGreeting() {
        XCTAssertEqual(Greeting.kind(at: at(10, 3, 59), calendar: cal), .evening)
        XCTAssertEqual(Greeting.kind(at: at(10, 4, 0), calendar: cal), .morning)
        XCTAssertEqual(Greeting.kind(at: at(10, 11, 59), calendar: cal), .morning)
        XCTAssertEqual(Greeting.kind(at: at(10, 12, 0), calendar: cal), .evening)
    }

    func testNextPrayerWithinDay() {
        let next = NextPrayer.find(provider: FixedDay(), now: at(10, 13, 0), calendar: cal)
        XCTAssertEqual(next?.prayer, .asr)
        XCTAssertEqual(next?.date, at(10, 15, 0))
    }

    func testNextPrayerBeforeFajr() {
        XCTAssertEqual(NextPrayer.find(provider: FixedDay(), now: at(10, 2, 0), calendar: cal)?.prayer, .fajr)
    }

    func testNextPrayerAfterIshaIsTomorrowsFajr() {
        let next = NextPrayer.find(provider: FixedDay(), now: at(10, 21, 0), calendar: cal)
        XCTAssertEqual(next?.prayer, .fajr)
        XCTAssertEqual(next?.date, at(11, 5, 0))
    }

    func testNextPrayerExactlyAtPrayerMovesToTheFollowingOne() {
        XCTAssertEqual(NextPrayer.find(provider: FixedDay(), now: at(10, 12, 0), calendar: cal)?.prayer, .asr)
    }

    func testCountdownRoundsUp() {
        let now = at(10, 13, 0)
        let c = Countdown.parts(from: now, to: now.addingTimeInterval(2 * 3600 + 14 * 60 + 1))
        XCTAssertEqual(c.hours, 2)
        XCTAssertEqual(c.minutes, 15)
        let past = Countdown.parts(from: now, to: now.addingTimeInterval(-50))
        XCTAssertEqual(past.hours, 0)
        XCTAssertEqual(past.minutes, 0)
    }

    private func item(_ done: Bool, _ time: Date?) -> TodayTaskItem { TodayTaskItem(id: UUID(), isDone: done, time: time) }

    func testNextTaskPicksSoonestUpcomingTimed() {
        let a = item(false, at(10, 18, 0)), b = item(false, at(10, 15, 0)), c = item(false, nil)
        XCTAssertEqual(NextMainTask.pick([a, b, c], now: at(10, 12, 0)), .task(b.id))
    }

    func testNextTaskSkipsDoneAndPassedThenFallsToUntimed() {
        let done = item(true, at(10, 15, 0)), passed = item(false, at(10, 9, 0)), untimed = item(false, nil)
        XCTAssertEqual(NextMainTask.pick([done, passed, untimed], now: at(10, 12, 0)), .task(untimed.id))
    }

    func testNextTaskFallsBackToOverdue() {
        let a = item(false, at(10, 9, 0)), b = item(false, at(10, 7, 0))
        XCTAssertEqual(NextMainTask.pick([a, b], now: at(10, 12, 0)), .task(b.id))
    }

    func testAllDoneAndNoTasks() {
        XCTAssertEqual(NextMainTask.pick([item(true, nil), item(true, at(10, 9, 0))], now: at(10, 12, 0)), .allDone)
        XCTAssertEqual(NextMainTask.pick([], now: at(10, 12, 0)), .noTasks)
    }

    func testTaskDueExactlyNowCountsAsUpcoming() {
        let a = item(false, at(10, 12, 0)), b = item(false, nil)
        XCTAssertEqual(NextMainTask.pick([b, a], now: at(10, 12, 0)), .task(a.id))
    }

    // MARK: - Tasks with several times (alarm follows several prayers)

    func testEffectiveTimeDefaultsToFirst() {
        let t = TodayTaskItem(id: UUID(), isDone: false, time: at(10, 12, 0), times: [at(10, 19, 0), at(10, 12, 0), at(10, 15, 0)])
        XCTAssertEqual(t.times, [at(10, 12, 0), at(10, 15, 0), at(10, 19, 0)])
        XCTAssertEqual(t.effectiveTime(now: at(10, 16, 0), followsNextRing: false), at(10, 12, 0))
    }

    func testEffectiveTimeFollowsNextRing() {
        let t = TodayTaskItem(id: UUID(), isDone: false, time: at(10, 12, 0), times: [at(10, 12, 0), at(10, 15, 0), at(10, 19, 0)])
        XCTAssertEqual(t.effectiveTime(now: at(10, 11, 0), followsNextRing: true), at(10, 12, 0))
        XCTAssertEqual(t.effectiveTime(now: at(10, 13, 0), followsNextRing: true), at(10, 15, 0))
        XCTAssertEqual(t.effectiveTime(now: at(10, 15, 0), followsNextRing: true), at(10, 15, 0))
        XCTAssertEqual(t.effectiveTime(now: at(10, 20, 0), followsNextRing: true), at(10, 19, 0))
    }

    func testSingleTimeIgnoresFollowSetting() {
        let t = TodayTaskItem(id: UUID(), isDone: false, time: at(10, 12, 0), times: [at(10, 12, 0)])
        XCTAssertEqual(t.effectiveTime(now: at(10, 13, 0), followsNextRing: true), at(10, 12, 0))
    }

    func testPickFollowsNextRingOfMultiTimeTask() {
        let multi = TodayTaskItem(id: UUID(), isDone: false, time: at(10, 12, 0), times: [at(10, 12, 0), at(10, 15, 0), at(10, 19, 0)])
        let other = TodayTaskItem(id: UUID(), isDone: false, time: at(10, 17, 0), times: [at(10, 17, 0)])
        let now = at(10, 13, 0)
        // Off: the multi task counts as passed (12:00), so the 17:00 task is next.
        XCTAssertEqual(NextMainTask.pick([multi, other], now: now), .task(other.id))
        // On: its 15:00 ring is still ahead and beats 17:00.
        XCTAssertEqual(NextMainTask.pick([multi, other], now: now, followsNextRing: true), .task(multi.id))
    }

    func testPickFollowOnStillOverdueAfterLastRing() {
        let multi = TodayTaskItem(id: UUID(), isDone: false, time: at(10, 12, 0), times: [at(10, 12, 0), at(10, 15, 0)])
        let untimed = TodayTaskItem(id: UUID(), isDone: false, time: nil)
        XCTAssertEqual(NextMainTask.pick([multi, untimed], now: at(10, 20, 0), followsNextRing: true), .task(untimed.id))
    }
}
