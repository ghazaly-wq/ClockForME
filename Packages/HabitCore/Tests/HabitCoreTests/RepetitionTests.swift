import XCTest
@testable import HabitCore

final class RepetitionTests: XCTestCase {
    private let cal = TestSupport.calendar
    private func d(_ y: Int, _ m: Int, _ day: Int) -> DayKey { TestSupport.day(y, m, day) }

    func testOnceMatchesOnlyThatDay() {
        let rule = Repetition.once(d(2026, 11, 14))
        XCTAssertTrue(rule.occurs(on: d(2026, 11, 14), calendar: cal))
        XCTAssertFalse(rule.occurs(on: d(2026, 11, 15), calendar: cal))
    }

    func testWeekdayLookup() {
        // 14 Nov 2026 is a Saturday; 15 Nov a Sunday.
        XCTAssertEqual(d(2026, 11, 14).weekday(calendar: cal), .saturday)
        XCTAssertEqual(d(2026, 11, 15).weekday(calendar: cal), .sunday)
    }

    func testWeeklyMatchesChosenWeekdays() {
        let rule = Repetition.weekly([.sunday, .tuesday, .thursday])
        XCTAssertTrue(rule.occurs(on: d(2026, 11, 15), calendar: cal))   // Sunday
        XCTAssertFalse(rule.occurs(on: d(2026, 11, 16), calendar: cal))  // Monday
        XCTAssertTrue(rule.occurs(on: d(2026, 11, 17), calendar: cal))   // Tuesday
        XCTAssertTrue(rule.occurs(on: d(2026, 11, 19), calendar: cal))   // Thursday
        XCTAssertFalse(rule.occurs(on: d(2026, 11, 21), calendar: cal))  // Saturday
    }

    func testDailyMatchesEveryDay() {
        for offset in 0..<14 {
            let day = d(2026, 11, 1).adding(days: offset, calendar: cal)!
            XCTAssertTrue(Repetition.daily.occurs(on: day, calendar: cal))
        }
    }

    func testEmptyWeeklyAndMonthlyNeverOccur() {
        XCTAssertFalse(Repetition.weekly([]).occurs(on: d(2026, 11, 14), calendar: cal))
        XCTAssertFalse(Repetition.monthly([]).occurs(on: d(2026, 11, 30), calendar: cal))
    }

    func testMonthlyMatchesChosenDays() {
        let rule = Repetition.monthly([1, 15])
        XCTAssertTrue(rule.occurs(on: d(2026, 11, 1), calendar: cal))
        XCTAssertTrue(rule.occurs(on: d(2026, 11, 15), calendar: cal))
        XCTAssertFalse(rule.occurs(on: d(2026, 11, 16), calendar: cal))
    }

    func testMonthlyDay31FiresOnLastDayOfShortMonths() {
        let rule = Repetition.monthly([31])
        XCTAssertTrue(rule.occurs(on: d(2026, 10, 31), calendar: cal))   // 31-day month
        XCTAssertFalse(rule.occurs(on: d(2026, 11, 29), calendar: cal))
        XCTAssertTrue(rule.occurs(on: d(2026, 11, 30), calendar: cal))   // April-like: last day
        XCTAssertTrue(rule.occurs(on: d(2026, 2, 28), calendar: cal))    // non-leap February
        XCTAssertFalse(rule.occurs(on: d(2028, 2, 28), calendar: cal))   // leap year: 29th is last
        XCTAssertTrue(rule.occurs(on: d(2028, 2, 29), calendar: cal))
    }

    func testMonthlyFiresOnlyOncePerMonthWhenSeveralDaysAreMissing() {
        let rule = Repetition.monthly([30, 31])
        let feb = (1...28).filter { rule.occurs(on: d(2026, 2, $0), calendar: cal) }
        XCTAssertEqual(feb, [28])
    }

    func testDaysInMonth() {
        XCTAssertEqual(d(2026, 2, 1).daysInMonth(calendar: cal), 28)
        XCTAssertEqual(d(2028, 2, 1).daysInMonth(calendar: cal), 29)
        XCTAssertEqual(d(2026, 11, 1).daysInMonth(calendar: cal), 30)
        XCTAssertEqual(d(2026, 12, 1).daysInMonth(calendar: cal), 31)
    }

    func testCodableRoundTrip() throws {
        let rules: [Repetition] = [.once(d(2026, 11, 14)), .weekly([.monday, .friday]), .monthly([1, 31])]
        for rule in rules {
            let data = try JSONEncoder().encode(rule)
            XCTAssertEqual(try JSONDecoder().decode(Repetition.self, from: data), rule)
        }
    }

    func testIsoStringParsing() {
        XCTAssertEqual(DayKey(isoString: "2026-03-07"), d(2026, 3, 7))
        XCTAssertNil(DayKey(isoString: "2026-13-01"))
        XCTAssertNil(DayKey(isoString: "garbage"))
        XCTAssertNil(DayKey(isoString: "2026-03"))
        let key = d(2026, 11, 4)
        XCTAssertEqual(DayKey(isoString: key.isoString), key)
    }
}
