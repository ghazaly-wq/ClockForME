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
    /// (or a prayer time is needed but unavailable).
    public static func fireDate(
        of alarm: AlarmRule,
        on day: DayKey,
        provider: PrayerTimeProviding?,
        calendar: Calendar
    ) -> Date? {
        guard alarm.repetition.occurs(on: day, calendar: calendar) else { return nil }
        switch alarm.time {
        case let .clock(hour, minute):
            let h = min(max(hour, 0), 23), m = min(max(minute, 0), 59)
            return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: h, minute: m))
        case let .prayer(prayer, direction, hours, minutes):
            guard let base = provider?.times(for: day, calendar: calendar)?[prayer] else { return nil }
            let offset = TimeInterval(max(hours, 0) * 3600 + max(minutes, 0) * 60)
            return direction == .before ? base.addingTimeInterval(-offset) : base.addingTimeInterval(offset)
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
                guard let fire = fireDate(of: alarm, on: day, provider: provider, calendar: calendar),
                      fire > now else { continue }
                result.append(PlannedNotification(
                    identifier: "alarm.\(alarm.id.uuidString).\(stamp(fire, calendar: calendar))",
                    alarmID: alarm.id,
                    fireDate: fire
                ))
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
