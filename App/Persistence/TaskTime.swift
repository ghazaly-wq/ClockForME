import Foundation
import HabitCore

extension TaskRecord {
    /// The task's time as an alarm rule, so the same planner resolves it (several prayers included).
    var timeRule: AlarmRule? {
        guard let time else { return nil }
        return AlarmRule(title: "", repetition: .daily, time: time, extraPrayers: extraPrayers)
    }

    /// Every moment this task is due on `day`, sorted: one for a plain time, several when its alarm
    /// follows several prayers. Prayer-based times need a provider; without one the result is empty.
    func dueDates(on day: DayKey, provider: PrayerTimeProviding?, calendar: Calendar) -> [Date] {
        guard let rule = timeRule else { return [] }
        return NotificationPlanner.fireDates(of: rule, on: day, provider: provider, calendar: calendar).sorted()
    }

    /// The moment this task is due on `day` (tasks made from an alarm carry its time), if it has one.
    /// With several times this is the earliest. Prayer-based times need a provider; without one the result is nil.
    func dueDate(on day: DayKey, provider: PrayerTimeProviding?, calendar: Calendar) -> Date? {
        dueDates(on: day, provider: provider, calendar: calendar).first
    }

    /// What the next-task logic needs for this task today.
    func todayItem(done: Bool, on day: DayKey, provider: PrayerTimeProviding?, calendar: Calendar) -> TodayTaskItem {
        let dates = dueDates(on: day, provider: provider, calendar: calendar)
        return TodayTaskItem(id: id, isDone: done, time: dates.first, times: dates)
    }
}

/// The time wording a task row shows (the same on the Tasks page and on Home).
enum TaskTimeText {
    /// A plain time: its clock time. A prayer time: today's resolved time(s), or the wording ("بعد العصر بـ ١٠ دقائق")
    /// when no location is saved. With several prayers: every time (`showAll`), else the one the next-task rule
    /// would use (`followsNextRing` picks the next ring instead of the first).
    static func text(
        for task: TaskRecord,
        on day: DayKey,
        provider: PrayerTimeProviding?,
        calendar: Calendar,
        now: Date,
        showAll: Bool,
        followsNextRing: Bool,
        digits: DigitStyle
    ) -> String? {
        guard let time = task.time, let rule = task.timeRule else { return nil }
        guard time.isPrayerBased else { return AlarmText.summary(of: time, digits: digits) }

        let dates = task.dueDates(on: day, provider: provider, calendar: calendar)
        guard let first = dates.first else { return AlarmText.summary(of: rule, digits: digits) }
        guard dates.count > 1 else { return AlarmText.time(first, digits: digits) }

        if showAll {
            return dates.map { AlarmText.time($0, digits: digits) }.joined(separator: " · ")
        }
        let item = TodayTaskItem(id: task.id, isDone: false, time: first, times: dates)
        return AlarmText.time(item.effectiveTime(now: now, followsNextRing: followsNextRing) ?? first, digits: digits)
    }
}
