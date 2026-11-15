import Foundation

/// Days of the week. Raw values match `Calendar.component(.weekday)` (Sunday = 1).
public enum Weekday: Int, Codable, CaseIterable, Comparable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// When something happens: once on a date, on chosen weekdays, or on chosen days of the month.
public enum Repetition: Codable, Equatable, Sendable {
    case once(DayKey)
    case weekly(Set<Weekday>)
    case monthly(Set<Int>)   // days 1...31

    /// Every day of the week.
    public static var daily: Repetition { .weekly(Set(Weekday.allCases)) }

    /// Does this repetition fall on the given day?
    /// For monthly rules, a chosen day that a month does not have (e.g. 31 in April)
    /// fires on the last day of that month.
    public func occurs(on day: DayKey, calendar: Calendar) -> Bool {
        switch self {
        case .once(let date):
            return date == day
        case .weekly(let weekdays):
            guard let weekday = day.weekday(calendar: calendar) else { return false }
            return weekdays.contains(weekday)
        case .monthly(let days):
            if days.contains(day.day) { return true }
            let daysInMonth = day.daysInMonth(calendar: calendar)
            return day.day == daysInMonth && days.contains { $0 > daysInMonth }
        }
    }
}
