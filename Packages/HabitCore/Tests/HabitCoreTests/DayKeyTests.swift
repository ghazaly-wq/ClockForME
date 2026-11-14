import XCTest
@testable import HabitCore

final class DayKeyTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testDayKeyAtMidnightBoundary() {
        let key = DayKey(date: date(2026, 11, 14, 0, 30), calendar: calendar)
        XCTAssertEqual(key, DayKey(year: 2026, month: 11, day: 14))
    }

    func testDayStartHourPushesEarlyMorningToPreviousDay() {
        let early = DayKey(date: date(2026, 11, 14, 0, 30), calendar: calendar, dayStartHour: 3)
        XCTAssertEqual(early, DayKey(year: 2026, month: 11, day: 13))

        let exactlyAtStart = DayKey(date: date(2026, 11, 14, 3, 0), calendar: calendar, dayStartHour: 3)
        XCTAssertEqual(exactlyAtStart, DayKey(year: 2026, month: 11, day: 14))

        let justBefore = DayKey(date: date(2026, 11, 14, 2, 59), calendar: calendar, dayStartHour: 3)
        XCTAssertEqual(justBefore, DayKey(year: 2026, month: 11, day: 13))
    }

    func testDayStartAcrossMonthAndYearBoundary() {
        let month = DayKey(date: date(2026, 12, 1, 1, 0), calendar: calendar, dayStartHour: 3)
        XCTAssertEqual(month, DayKey(year: 2026, month: 11, day: 30))

        let year = DayKey(date: date(2027, 1, 1, 2, 0), calendar: calendar, dayStartHour: 3)
        XCTAssertEqual(year, DayKey(year: 2026, month: 12, day: 31))
    }

    func testInvalidDayStartHourIsClamped() {
        let high = DayKey(date: date(2026, 11, 14, 23, 30), calendar: calendar, dayStartHour: 99)
        XCTAssertEqual(high, DayKey(year: 2026, month: 11, day: 14))
        let low = DayKey(date: date(2026, 11, 14, 0, 30), calendar: calendar, dayStartHour: -5)
        XCTAssertEqual(low, DayKey(year: 2026, month: 11, day: 14))
    }

    func testAddingDaysCrossesMonthsAndLeapYears() {
        XCTAssertEqual(
            DayKey(year: 2026, month: 11, day: 30).adding(days: 1, calendar: calendar),
            DayKey(year: 2026, month: 12, day: 1))
        XCTAssertEqual(
            DayKey(year: 2026, month: 3, day: 1).adding(days: -1, calendar: calendar),
            DayKey(year: 2026, month: 2, day: 28))
        XCTAssertEqual(
            DayKey(year: 2028, month: 2, day: 28).adding(days: 1, calendar: calendar),
            DayKey(year: 2028, month: 2, day: 29))
        XCTAssertEqual(
            DayKey(year: 2026, month: 12, day: 31).adding(days: 1, calendar: calendar),
            DayKey(year: 2027, month: 1, day: 1))
    }

    func testStartDateRespectsDayStartHour() {
        let key = DayKey(year: 2026, month: 11, day: 14)
        XCTAssertEqual(key.startDate(calendar: calendar), date(2026, 11, 14, 0, 0))
        XCTAssertEqual(key.startDate(calendar: calendar, dayStartHour: 3), date(2026, 11, 14, 3, 0))
    }

    func testComparable() {
        let a = DayKey(year: 2026, month: 11, day: 30)
        let b = DayKey(year: 2026, month: 12, day: 1)
        let c = DayKey(year: 2027, month: 1, day: 1)
        XCTAssertLessThan(a, b)
        XCTAssertLessThan(b, c)
        XCTAssertEqual([c, a, b].sorted(), [a, b, c])
    }

    func testIsoString() {
        XCTAssertEqual(DayKey(year: 2026, month: 3, day: 7).isoString, "2026-03-07")
    }

    func testCodableRoundTrip() throws {
        let key = DayKey(year: 2026, month: 11, day: 14)
        let data = try JSONEncoder().encode(key)
        XCTAssertEqual(try JSONDecoder().decode(DayKey.self, from: data), key)
    }
}
