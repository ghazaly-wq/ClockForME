import XCTest
@testable import HabitCore

final class DayProgressTests: XCTestCase {
    private let cal = TestSupport.calendar
    private let today = TestSupport.day(2026, 11, 15)   // a Sunday

    private func spec(_ kind: TaskKind, _ rep: Repetition?, start: DayKey? = nil, end: DayKey? = nil) -> TaskSpec {
        TaskSpec(id: UUID(), kind: kind, repetition: rep, startDay: start ?? TestSupport.day(2026, 11, 1), endDay: end)
    }

    func testStates() {
        XCTAssertEqual(DayProgress(total: 0, completed: 0).state, .noTasks)
        XCTAssertEqual(DayProgress(total: 4, completed: 0).state, .none)
        XCTAssertEqual(DayProgress(total: 4, completed: 1).state, .partial)
        XCTAssertEqual(DayProgress(total: 4, completed: 3).state, .partial)
        XCTAssertEqual(DayProgress(total: 4, completed: 4).state, .complete)
        XCTAssertEqual(DayProgress(total: 4, completed: 1).fraction, 0.25, accuracy: 0.0001)
        XCTAssertEqual(DayProgress(total: 0, completed: 0).fraction, 0)
    }

    func testCompletedIsClampedToTotal() {
        XCTAssertEqual(DayProgress(total: 2, completed: 5).completed, 2)
    }

    func testOnlyMainTasksScheduledThatDayCount() {
        let main1 = spec(.main, .daily)
        let main2 = spec(.main, .once(today))
        let mainOtherDay = spec(.main, .once(TestSupport.day(2026, 11, 16)))
        let secondary = spec(.secondary, .daily)
        let anytime = spec(.secondary, nil)
        let specs = [main1, main2, mainOtherDay, secondary, anytime]

        let none = DayProgress.compute(day: today, specs: specs, completedIDs: [], calendar: cal)
        XCTAssertEqual(none, DayProgress(total: 2, completed: 0))

        let one = DayProgress.compute(day: today, specs: specs, completedIDs: [main1.id, secondary.id], calendar: cal)
        XCTAssertEqual(one, DayProgress(total: 2, completed: 1))

        let all = DayProgress.compute(day: today, specs: specs, completedIDs: [main1.id, main2.id], calendar: cal)
        XCTAssertEqual(all.state, .complete)
    }

    func testTaskDoesNotAppearBeforeStartOrFromEndDay() {
        let task = spec(.main, .daily, start: TestSupport.day(2026, 11, 10), end: TestSupport.day(2026, 11, 13))
        func total(_ d: Int) -> Int {
            DayProgress.compute(day: TestSupport.day(2026, 11, d), specs: [task], completedIDs: [], calendar: cal).total
        }
        XCTAssertEqual(total(9), 0)    // before start
        XCTAssertEqual(total(10), 1)
        XCTAssertEqual(total(12), 1)
        XCTAssertEqual(total(13), 0)   // end day is exclusive
        XCTAssertEqual(total(14), 0)
    }

    func testNoMainTasksIsNeutral() {
        let result = DayProgress.compute(day: today, specs: [spec(.secondary, .daily)], completedIDs: [], calendar: cal)
        XCTAssertEqual(result.state, .noTasks)
    }
}
