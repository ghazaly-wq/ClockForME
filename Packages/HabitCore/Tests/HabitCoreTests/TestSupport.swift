import Foundation
@testable import HabitCore

enum TestSupport {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 1
        return c
    }

    static func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

    /// Builds history from a string, one character per day starting at `start`:
    /// C = complete, P = partial, 0 = tasks but nothing done, - = no tasks.
    static func history(_ pattern: String, from start: DayKey) -> (progress: [DayKey: DayProgress], next: DayKey) {
        var map: [DayKey: DayProgress] = [:]
        var day = start
        for ch in pattern {
            switch ch {
            case "C": map[day] = DayProgress(total: 4, completed: 4)
            case "P": map[day] = DayProgress(total: 4, completed: 1)
            case "0": map[day] = DayProgress(total: 4, completed: 0)
            default: break   // "-" leaves the day without tasks
            }
            day = day.adding(days: 1, calendar: calendar)!
        }
        return (map, day)
    }
}
