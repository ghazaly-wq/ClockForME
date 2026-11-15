import Foundation

/// One notification the app should have scheduled with the system.
public struct PlannedNotification: Equatable, Sendable {
    /// `alarm.<alarm id>.<yyyyMMddHHmm>` — stable, so planning twice yields the same ids.
    public let identifier: String
    public let alarmID: UUID
    public let fireDate: Date

    public init(identifier: String, alarmID: UUID, fireDate: Date) {
        self.identifier = identifier
        self.alarmID = alarmID
        self.fireDate = fireDate
    }
}

public enum NotificationPlanner {
    /// The system keeps at most 64 pending notifications; we plan 60 and keep a few spare.
    public static let defaultLimit = 60
    public static let defaultHorizonDays = 14

    /// The moment an alarm rings on `day`, or nil if it doesn't occur that day
    /// (or a prayer time is needed but unavailable). With several prayers: the earliest one.
    public static func fireDate(
        of alarm: AlarmRule,
        on day: DayKey,
        provider: PrayerTimeProviding?,
        calendar: Calendar
    ) -> Date? {
        fireDates(of: alarm, on: day, provider: provider, calendar: calendar).first
    }

    /// Every moment an alarm rings on `day`, earliest first: one for a clock alarm,
    /// one per chosen prayer for a prayer alarm. Empty when it doesn't occur that day
    /// (including after the routine's end day) or prayer times are unavailable.
    public static func fireDates(
        of alarm: AlarmRule,
        on day: DayKey,
        provider: PrayerTimeProviding?,
        calendar: Calendar
    ) -> [Date] {
        guard alarm.repetition.occurs(on: day, calendar: calendar) else { return [] }
        if let end = alarm.endDay, day > end { return [] }
        switch alarm.time {
        case let .clock(hour, minute):
            let h = min(max(hour, 0), 23), m = min(max(minute, 0), 59)
            return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: h, minute: m)).map { [$0] } ?? []
        case let .prayer(_, direction, hours, minutes):
            guard let times = provider?.times(for: day, calendar: calendar) else { return [] }
            let offset = TimeInterval(max(hours, 0) * 3600 + max(minutes, 0) * 60)
            return alarm.prayers
                .compactMap { times[$0] }
                .map { direction == .before ? $0.addingTimeInterval(-offset) : $0.addingTimeInterval(offset) }
                .sorted()
        }
    }

    /// The next notifications to schedule, soonest first: enabled alarms within
    /// `days` days from `now`, capped at `limit`.
    public static func plan(
        alarms: [AlarmRule],
        from now: Date,
        days: Int = defaultHorizonDays,
        limit: Int = defaultLimit,
        provider: PrayerTimeProviding?,
        calendar: Calendar
    ) -> [PlannedNotification] {
        let enabled = alarms.filter(\.isEnabled)
        guard !enabled.isEmpty, days > 0, limit > 0 else { return [] }

        let today = DayKey(date: now, calendar: calendar)
        var result: [PlannedNotification] = []
        // Start one day early: "30 min after Isha" can land after midnight of the next day.
        for offset in -1..<days {
            guard let day = today.adding(days: offset, calendar: calendar) else { continue }
            for alarm in enabled {
                for fire in fireDates(of: alarm, on: day, provider: provider, calendar: calendar) where fire > now {
                    result.append(PlannedNotification(
                        identifier: "alarm.\(alarm.id.uuidString).\(stamp(fire, calendar: calendar))",
                        alarmID: alarm.id,
                        fireDate: fire
                    ))
                }
            }
        }
        result.sort { ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier) }
        return Array(result.prefix(limit))
    }

    static func stamp(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        func pad(_ n: Int?, _ w: Int) -> String {
            let s = String(n ?? 0)
            return String(repeating: "0", count: max(0, w - s.count)) + s
        }
        return pad(c.year, 4) + pad(c.month, 2) + pad(c.day, 2) + pad(c.hour, 2) + pad(c.minute, 2)
    }
}
