import Foundation
import HabitCore

/// Builds today's picture for the widgets and the Live Activity from the stored data.
enum WidgetSnapshotBuilder {
    struct Output {
        let snapshot: WidgetSnapshot
        let dayKey: DayKey
    }

    static func make(
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        alarms: [AlarmRecord],
        extras: ProgressExtras,
        now: Date,
        dayStartHour: Int,
        provider: PrayerTimeProviding?,
        calendar: Calendar = .app,
        styleID: String,
        arabicDigits: Bool,
        followsNextRing: Bool
    ) -> Output {
        let progress = ProgressSnapshot.make(
            tasks: tasks, completions: completions, now: now, dayStartHour: dayStartHour,
            calendar: calendar, extras: extras
        )
        let today = progress.today
        let doneToday = Set(completions.filter { $0.day == today }.map(\.taskID))

        let mainToday = tasks
            .filter { $0.kind == .main && $0.repetition != nil && $0.spec.isScheduled(on: today, calendar: calendar) }
            .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }

        let items = mainToday.map { task -> WidgetSnapshot.Item in
            let dates = task.dueDates(on: today, provider: provider, calendar: calendar)
            return WidgetSnapshot.Item(
                id: task.id.uuidString,
                title: task.title,
                time: dates.first,
                done: doneToday.contains(task.id),
                times: dates.count > 1 ? dates : nil
            )
        }

        let dayEnd = today.adding(days: 1, calendar: calendar)?
            .startDate(calendar: calendar, dayStartHour: dayStartHour)
            ?? now.addingTimeInterval(24 * 3600)

        // The soonest enabled alarm from now until the end of tomorrow.
        var nextAlarm: (title: String, date: Date)?
        for offset in 0...1 {
            guard let day = today.adding(days: offset, calendar: calendar) else { continue }
            for alarm in alarms where alarm.isEnabled {
                let rule = alarm.rule
                guard let fire = NotificationPlanner.fireDate(of: rule, on: day, provider: provider, calendar: calendar),
                      fire > now else { continue }
                if nextAlarm == nil || fire < nextAlarm!.date { nextAlarm = (rule.title, fire) }
            }
        }

        let snapshot = WidgetSnapshot(
            generatedAt: now,
            dayEnd: dayEnd,
            items: items,
            streak: progress.streak.current,
            level: progress.summary.level,
            levelTitle: progress.summary.title.arabicName,
            nextAlarmTitle: nextAlarm?.title,
            nextAlarmDate: nextAlarm?.date,
            arabicDigits: arabicDigits,
            styleID: styleID,
            followsNextRing: followsNextRing
        )
        return Output(snapshot: snapshot, dayKey: today)
    }
}
