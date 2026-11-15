import Foundation

/// Facts replayed from history that the streak alone does not give.
public struct HistoryStats: Equatable, Sendable {
    /// Longest run of consecutive complete days (days without main tasks are neutral).
    public let longestCompleteRun: Int
    /// Times the owner completed a day right after being away for at least the grace period.
    public let comebacks: Int
    /// Most main tasks in a single complete day.
    public let biggestCompleteDay: Int

    public init(longestCompleteRun: Int, comebacks: Int, biggestCompleteDay: Int = 0) {
        self.longestCompleteRun = longestCompleteRun
        self.comebacks = comebacks
        self.biggestCompleteDay = biggestCompleteDay
    }

    public static func compute(
        progressByDay: [DayKey: DayProgress],
        today: DayKey,
        calendar: Calendar,
        graceMissedDays: Int = StreakRules.graceMissedDays
    ) -> HistoryStats {
        guard let first = progressByDay.keys.min(), first <= today else {
            return HistoryStats(longestCompleteRun: 0, comebacks: 0)
        }
        var run = 0, bestRun = 0, missed = 0, comebacks = 0, biggest = 0
        var day = first
        while day <= today {
            let state = progressByDay[day]?.state ?? .noTasks
            let isToday = day == today
            switch state {
            case .noTasks:
                break
            case .complete:
                if missed >= graceMissedDays { comebacks += 1 }
                missed = 0
                run += 1
                bestRun = max(bestRun, run)
                biggest = max(biggest, progressByDay[day]?.total ?? 0)
            case .partial:
                if !isToday { missed = 0; run = 0 }
            case .none:
                if !isToday { missed += 1; run = 0 }
            }
            guard let next = day.adding(days: 1, calendar: calendar) else { break }
            day = next
        }
        return HistoryStats(longestCompleteRun: bestRun, comebacks: comebacks, biggestCompleteDay: biggest)
    }
}

public struct WeekPoint: Equatable, Sendable {
    /// First day of the week (the calendar's first weekday).
    public let start: DayKey
    /// Share of main tasks done in that week, 0...1 (0 when nothing was scheduled).
    public let fraction: Double
    public let hadTasks: Bool
}

public struct HeatCell: Equatable, Sendable {
    public let day: DayKey
    public let state: DayProgress.State
    /// 0 = first weekday of the calendar … 6.
    public let row: Int
    /// Week column counted from the oldest shown week.
    public let column: Int
}

public struct XPPoint: Equatable, Sendable {
    public let day: DayKey
    public let cumulativeXP: Int
}

public enum StatsCalculator {
    /// Start of the week containing `day`, following the calendar's first weekday.
    public static func weekStart(of day: DayKey, calendar: Calendar) -> DayKey {
        guard let weekday = day.weekday(calendar: calendar) else { return day }
        let offset = (weekday.rawValue - calendar.firstWeekday + 7) % 7
        return day.adding(days: -offset, calendar: calendar) ?? day
    }

    /// Completion share per week for the last `weeks` weeks (oldest first, current week last).
    public static func weeklyCompletion(
        progressByDay: [DayKey: DayProgress],
        today: DayKey,
        weeks: Int,
        calendar: Calendar
    ) -> [WeekPoint] {
        guard weeks > 0 else { return [] }
        let currentStart = weekStart(of: today, calendar: calendar)
        var result: [WeekPoint] = []
        for index in stride(from: weeks - 1, through: 0, by: -1) {
            guard let start = currentStart.adding(days: -7 * index, calendar: calendar) else { continue }
            var total = 0, done = 0
            for offset in 0..<7 {
                guard let day = start.adding(days: offset, calendar: calendar), day <= today,
                      let progress = progressByDay[day] else { continue }
                total += progress.total
                done += progress.completed
            }
            result.append(WeekPoint(start: start, fraction: total == 0 ? 0 : Double(done) / Double(total), hadTasks: total > 0))
        }
        return result
    }

    /// A week-by-week grid ending with the current week; days after `today` are omitted.
    public static func heatmap(
        progressByDay: [DayKey: DayProgress],
        today: DayKey,
        weeks: Int,
        calendar: Calendar
    ) -> [HeatCell] {
        guard weeks > 0 else { return [] }
        let currentStart = weekStart(of: today, calendar: calendar)
        guard let firstStart = currentStart.adding(days: -7 * (weeks - 1), calendar: calendar) else { return [] }
        var cells: [HeatCell] = []
        for column in 0..<weeks {
            for row in 0..<7 {
                guard let day = firstStart.adding(days: column * 7 + row, calendar: calendar), day <= today else { continue }
                cells.append(HeatCell(day: day, state: progressByDay[day]?.state ?? .noTasks, row: row, column: column))
            }
        }
        return cells
    }

    /// Cumulative XP earned from tasks and complete days (milestone/achievement bonuses excluded).
    public static func xpTimeline(
        completedTasksByDay: [DayKey: Int],
        progressByDay: [DayKey: DayProgress],
        from: DayKey,
        to: DayKey,
        calendar: Calendar
    ) -> [XPPoint] {
        guard from <= to else { return [] }
        var points: [XPPoint] = []
        var total = 0
        // XP earned before `from` is the starting level of the line.
        for (day, count) in completedTasksByDay where day < from {
            total += count * ProgressRules.xpPerTask
        }
        for (day, progress) in progressByDay where day < from && progress.state == .complete {
            total += ProgressRules.xpPerCompleteDay
        }
        var day = from
        while day <= to {
            total += (completedTasksByDay[day] ?? 0) * ProgressRules.xpPerTask
            if progressByDay[day]?.state == .complete { total += ProgressRules.xpPerCompleteDay }
            points.append(XPPoint(day: day, cumulativeXP: total))
            guard let next = day.adding(days: 1, calendar: calendar) else { break }
            day = next
        }
        return points
    }
}
