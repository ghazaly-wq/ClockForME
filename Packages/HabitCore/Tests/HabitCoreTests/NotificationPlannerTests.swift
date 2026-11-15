import XCTest
@testable import HabitCore

private struct FixedPrayers: PrayerTimeProviding {
    let base: Date   // Fajr; others follow every 2 hours
    func times(for day: DayKey, calendar: Calendar) -> [Prayer: Date]? {
        guard let start = day.startDate(calendar: calendar) else { return nil }
        return [
            .fajr: start.addingTimeInterval(5 * 3600),
            .dhuhr: start.addingTimeInterval(12 * 3600),
            .asr: start.addingTimeInterval(15 * 3600),
            .maghrib: start.addingTimeInterval(18 * 3600),
            .isha: start.addingTimeInterval(19.5 * 3600)
        ]
    }
}

final class NotificationPlannerTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
        c.firstWeekday = 1
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
    private let provider = FixedPrayers(base: Date())

    func testDailyClockAlarmSkipsPastAndCoversHorizon() {
        let alarm = AlarmRule(title: "a", repetition: .daily, time: .clock(hour: 7, minute: 30))
        let now = date(2026, 3, 10, 8, 0)
        let plan = NotificationPlanner.plan(alarms: [alarm], from: now, days: 14, provider: nil, calendar: cal)
        XCTAssertEqual(plan.count, 13)  // today's 07:30 already passed; days 11...23
        XCTAssertEqual(plan.first?.fireDate, date(2026, 3, 11, 7, 30))
        XCTAssertTrue(plan.first!.identifier.hasSuffix("202603110730"))
    }

    func testDisabledAlarmIsIgnored() {
        var alarm = AlarmRule(title: "a", repetition: .daily, time: .clock(hour: 7, minute: 30))
        alarm.isEnabled = false
        XCTAssertTrue(NotificationPlanner.plan(alarms: [alarm], from: date(2026, 3, 10, 8, 0), provider: nil, calendar: cal).isEmpty)
    }

    func testLimitKeepsSoonest() {
        let alarms = (0..<5).map { AlarmRule(title: "a\($0)", repetition: .daily, time: .clock(hour: 6 + $0, minute: 0)) }
        let now = date(2026, 3, 10, 0, 0)
        let plan = NotificationPlanner.plan(alarms: alarms, from: now, limit: 60, provider: nil, calendar: cal)
        XCTAssertEqual(plan.count, 60)
        XCTAssertEqual(plan, plan.sorted { $0.fireDate < $1.fireDate })
        XCTAssertEqual(Set(plan.map(\.identifier)).count, 60)
    }

    func testOnceAlarmFiresOnlyOnItsDay() {
        let alarm = AlarmRule(title: "once", repetition: .once(DayKey(year: 2026, month: 3, day: 12)), time: .clock(hour: 9, minute: 0))
        let plan = NotificationPlanner.plan(alarms: [alarm], from: date(2026, 3, 10, 8, 0), provider: nil, calendar: cal)
        XCTAssertEqual(plan.map(\.fireDate), [date(2026, 3, 12, 9, 0)])
    }

    func testWeeklyOnlyChosenWeekdays() {
        let alarm = AlarmRule(title: "w", repetition: .weekly([.friday]), time: .clock(hour: 11, minute: 0))
        let plan = NotificationPlanner.plan(alarms: [alarm], from: date(2026, 3, 10, 0, 0), days: 14, provider: nil, calendar: cal)
        XCTAssertEqual(plan.count, 2)
        for p in plan { XCTAssertEqual(cal.component(.weekday, from: p.fireDate), 6) }
    }

    func testMonthlyDay31FiresOnLastDayOfShortMonth() {
        let alarm = AlarmRule(title: "m", repetition: .monthly([31]), time: .clock(hour: 10, minute: 0))
        let plan = NotificationPlanner.plan(alarms: [alarm], from: date(2026, 4, 20, 0, 0), days: 14, provider: nil, calendar: cal)
        XCTAssertEqual(plan.map(\.fireDate), [date(2026, 4, 30, 10, 0)])
    }

    func testPrayerBeforeAndAfter() {
        let before = AlarmRule(title: "b", repetition: .daily, time: .prayer(.fajr, .before, hours: 1, minutes: 30))
        let after = AlarmRule(title: "a", repetition: .daily, time: .prayer(.isha, .after, hours: 0, minutes: 45))
        let day = DayKey(year: 2026, month: 3, day: 11)
        XCTAssertEqual(NotificationPlanner.fireDate(of: before, on: day, provider: provider, calendar: cal), date(2026, 3, 11, 3, 30))
        XCTAssertEqual(NotificationPlanner.fireDate(of: after, on: day, provider: provider, calendar: cal), date(2026, 3, 11, 20, 15))
    }

    func testPrayerAlarmWithoutProviderIsSkipped() {
        let alarm = AlarmRule(title: "p", repetition: .daily, time: .prayer(.dhuhr, .after, hours: 0, minutes: 0))
        XCTAssertTrue(NotificationPlanner.plan(alarms: [alarm], from: date(2026, 3, 10, 0, 0), provider: nil, calendar: cal).isEmpty)
    }

    func testAfterIshaCrossingMidnightIsStillPlanned() {
        let alarm = AlarmRule(title: "late", repetition: .daily, time: .prayer(.isha, .after, hours: 5, minutes: 0))  // 00:30 next day
        let now = date(2026, 3, 10, 23, 0)
        let plan = NotificationPlanner.plan(alarms: [alarm], from: now, days: 2, provider: provider, calendar: cal)
        XCTAssertEqual(plan.first?.fireDate, date(2026, 3, 11, 0, 30))
    }

    func testPlanningTwiceGivesSameIdentifiers() {
        let alarm = AlarmRule(title: "a", repetition: .daily, time: .clock(hour: 7, minute: 30))
        let now = date(2026, 3, 10, 8, 0)
        XCTAssertEqual(
            NotificationPlanner.plan(alarms: [alarm], from: now, provider: nil, calendar: cal),
            NotificationPlanner.plan(alarms: [alarm], from: now, provider: nil, calendar: cal))
    }

    func testTimeSpecCodableRoundTrip() throws {
        let rule = AlarmRule(title: "x", repetition: .weekly([.monday, .friday]), time: .prayer(.asr, .before, hours: 1, minutes: 5), isMainTask: true)
        let data = try JSONEncoder().encode(rule)
        XCTAssertEqual(try JSONDecoder().decode(AlarmRule.self, from: data), rule)
    }

    func testSeveralPrayersRingSeparatelyWithSameOffset() {
        var alarm = AlarmRule(title: "p", repetition: .daily, time: .prayer(.asr, .after, hours: 0, minutes: 10))
        alarm.extraPrayers = [.fajr, .asr]   // duplicate of the main prayer is ignored
        let day = DayKey(year: 2026, month: 3, day: 11)
        XCTAssertEqual(alarm.prayers, [.asr, .fajr])
        XCTAssertEqual(
            NotificationPlanner.fireDates(of: alarm, on: day, provider: provider, calendar: cal),
            [date(2026, 3, 11, 5, 10), date(2026, 3, 11, 15, 10)]
        )
        XCTAssertEqual(NotificationPlanner.fireDate(of: alarm, on: day, provider: provider, calendar: cal), date(2026, 3, 11, 5, 10))
        let plan = NotificationPlanner.plan(alarms: [alarm], from: date(2026, 3, 11, 0, 0), days: 2, provider: provider, calendar: cal)
        XCTAssertEqual(plan.count, 4)
        XCTAssertEqual(Set(plan.map(\.identifier)).count, 4)
    }

    func testRoutineEndDayStopsAlarm() {
        var alarm = AlarmRule(title: "study", repetition: .daily, time: .clock(hour: 20, minute: 0))
        alarm.endDay = DayKey(year: 2026, month: 3, day: 12)
        let plan = NotificationPlanner.plan(alarms: [alarm], from: date(2026, 3, 10, 0, 0), days: 14, provider: nil, calendar: cal)
        XCTAssertEqual(plan.map(\.fireDate), [date(2026, 3, 10, 20, 0), date(2026, 3, 11, 20, 0), date(2026, 3, 12, 20, 0)])
    }

    func testOldEncodedAlarmStillDecodes() throws {
        let alarm = AlarmRule(title: "x", repetition: .daily, time: .clock(hour: 7, minute: 0))
        var obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(alarm)) as! [String: Any]
        obj.removeValue(forKey: "extraPrayers"); obj.removeValue(forKey: "endDay")
        let decoded = try JSONDecoder().decode(AlarmRule.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(decoded.extraPrayers, [])
        XCTAssertNil(decoded.endDay)
    }
}

final class AdhanPrayerTimesTests: XCTestCase {
    func testRiyadhOrderingAndIshaAfterMaghrib() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
        let provider = AdhanPrayerTimes(latitude: 24.7136, longitude: 46.6753)
        let t = try XCTUnwrap(provider.times(for: DayKey(year: 2026, month: 3, day: 11), calendar: cal))
        let order: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
        for (a, b) in zip(order, order.dropFirst()) { XCTAssertLessThan(t[a]!, t[b]!) }
        // Umm al-Qura: Isha is 90 minutes after Maghrib (120 in Ramadan).
        let gap = t[.isha]!.timeIntervalSince(t[.maghrib]!) / 60
        XCTAssertEqual(gap, 90, accuracy: 1)
        // Dhuhr in Riyadh falls around midday local time.
        let hour = cal.component(.hour, from: t[.dhuhr]!)
        XCTAssertTrue((11...12).contains(hour))
    }

    func testInvalidCoordinatesGiveNil() {
        let cal = Calendar(identifier: .gregorian)
        XCTAssertNil(AdhanPrayerTimes(latitude: 200, longitude: 0).times(for: DayKey(year: 2026, month: 3, day: 11), calendar: cal))
    }
}
