import Foundation

/// A calendar day in local time. The "day" can start at a custom hour
/// (e.g. 03:00) so late-night work still counts for the previous day.
public struct DayKey: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day a moment belongs to, given the user's day-start hour (0...23).
    public init(date: Date, calendar: Calendar, dayStartHour: Int = 0) {
        let hour = min(max(dayStartHour, 0), 23)
        let shifted = calendar.date(byAdding: .hour, value: -hour, to: date) ?? date
        let parts = calendar.dateComponents([.year, .month, .day], from: shifted)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// The moment this day begins (midnight plus the day-start hour).
    public func startDate(calendar: Calendar, dayStartHour: Int = 0) -> Date? {
        let hour = min(max(dayStartHour, 0), 23)
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))
    }

    /// This day shifted by a number of calendar days (negative goes back).
    public func adding(days: Int, calendar: Calendar) -> DayKey? {
        guard
            let start = calendar.date(from: DateComponents(year: year, month: month, day: day)),
            let moved = calendar.date(byAdding: .day, value: days, to: start)
        else { return nil }
        return DayKey(date: moved, calendar: calendar)
    }

    /// Parses `yyyy-MM-dd` (the format of `isoString`).
    public init?(isoString: String) {
        let parts = isoString.split(separator: "-")
        guard
            parts.count == 3,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
            (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// Day of the week (Sunday-based numbering, independent of `firstWeekday`).
    public func weekday(calendar: Calendar) -> Weekday? {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        return Weekday(rawValue: calendar.component(.weekday, from: date))
    }

    /// Number of days in this day's month.
    public func daysInMonth(calendar: Calendar) -> Int {
        guard
            let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
            let range = calendar.range(of: .day, in: .month, for: first)
        else { return 31 }
        return range.count
    }

    /// `yyyy-MM-dd`, handy for stable identifiers.
    public var isoString: String {
        func pad(_ n: Int, _ width: Int) -> String {
            let s = String(n)
            return String(repeating: "0", count: max(0, width - s.count)) + s
        }
        return "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
