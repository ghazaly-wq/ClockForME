import Foundation
import HabitCore

extension Calendar {
    /// Gregorian, week starts on Sunday, device time zone.
    static var app: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        calendar.timeZone = TimeZone.current
        return calendar
    }
}

/// Everything the UI shows about progress, computed from stored tasks and completions
/// by the pure rules in HabitCore. Nothing here is saved, so it can never go stale.
struct ProgressSnapshot {
    let today: DayKey
    let todayMain: DayProgress
    let streak: StreakResult
    let summary: ProgressSummary

    static func make(
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        now: Date,
        dayStartHour: Int,
        calendar: Calendar = .app
    ) -> ProgressSnapshot {
        let today = DayKey(date: now, calendar: calendar, dayStartHour: dayStartHour)
        let specs = tasks.map(\.spec)

        var completedByDay: [DayKey: Set<UUID>] = [:]
        for completion in completions {
            completedByDay[completion.day, default: []].insert(completion.taskID)
        }

        var progressByDay: [DayKey: DayProgress] = [:]
        if let first = specs.map(\.startDay).min(), first <= today {
            var day = first
            while day <= today {
                let progress = DayProgress.compute(
                    day: day, specs: specs, completedIDs: completedByDay[day] ?? [], calendar: calendar
                )
                if progress.total > 0 { progressByDay[day] = progress }
                guard let next = day.adding(days: 1, calendar: calendar) else { break }
                day = next
            }
        }

        let streak = StreakEngine.compute(progressByDay: progressByDay, today: today, calendar: calendar)
        let summary = ProgressCalculator.summary(
            completedTasks: completions.count,
            completeDays: streak.completeDays,
            bestStreak: streak.best
        )
        let todayMain = progressByDay[today]
            ?? DayProgress.compute(day: today, specs: specs, completedIDs: completedByDay[today] ?? [], calendar: calendar)

        return ProgressSnapshot(today: today, todayMain: todayMain, streak: streak, summary: summary)
    }
}
