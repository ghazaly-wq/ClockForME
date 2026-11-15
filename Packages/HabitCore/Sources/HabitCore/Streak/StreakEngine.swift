import Foundation

public enum StreakRules {
    /// Consecutive 0% days that change nothing. From the next one, the streak drops by 1 per day.
    public static let graceMissedDays = 3
}

public struct StreakResult: Equatable, Sendable {
    public let current: Int
    public let best: Int
    /// Consecutive 0% days counted so far.
    public let missedRun: Int
    /// Days where every main task was done (feeds the day-complete XP bonus).
    public let completeDays: Int

    public init(current: Int, best: Int, missedRun: Int, completeDays: Int) {
        self.current = current
        self.best = best
        self.missedRun = missedRun
        self.completeDays = completeDays
    }
}

/// Computes the streak by replaying history, so edits to past days stay consistent.
///
/// Rules (owner-specified):
/// - Day complete (100%)        → streak +1, missed run resets.
/// - Day partial (1%–99%)       → streak holds, missed run resets.
/// - Day at 0% (tasks existed)  → missed run +1; after `graceMissedDays` in a row,
///                                the streak drops by 1 per missed day (never below 0).
/// - Day with no main tasks     → neutral: nothing changes.
/// - Today only counts when complete; it is never "missed" before it ends.
/// No freezes or skips exist by design.
public enum StreakEngine {
    public static func compute(
        progressByDay: [DayKey: DayProgress],
        today: DayKey,
        calendar: Calendar,
        graceMissedDays: Int = StreakRules.graceMissedDays
    ) -> StreakResult {
        guard let first = progressByDay.keys.min(), first <= today else {
            return StreakResult(current: 0, best: 0, missedRun: 0, completeDays: 0)
        }

        var current = 0
        var best = 0
        var missedRun = 0
        var completeDays = 0
        var day = first

        while day <= today {
            let state = progressByDay[day]?.state ?? .noTasks
            let isToday = day == today
            switch state {
            case .noTasks:
                break
            case .complete:
                current += 1
                missedRun = 0
                completeDays += 1
                best = max(best, current)
            case .partial:
                if !isToday { missedRun = 0 }
            case .none:
                if !isToday {
                    missedRun += 1
                    if missedRun > graceMissedDays { current = max(0, current - 1) }
                }
            }
            guard let next = day.adding(days: 1, calendar: calendar) else { break }
            day = next
        }

        return StreakResult(current: current, best: best, missedRun: missedRun, completeDays: completeDays)
    }
}
