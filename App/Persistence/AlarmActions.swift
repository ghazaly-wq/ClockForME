import Foundation
import HabitCore
import SwiftData

/// What happened to an alarm that was deleted, so it can come back.
struct DeletedAlarmSnapshot {
    let rule: AlarmRule
    let createdAt: Date
}

@MainActor
enum AlarmActions {
    // MARK: - Linking alarms with main tasks

    /// Keeps the task linked to a main-task alarm in step with the alarm.
    /// Past days are never rewritten: if the schedule changes and the task has history,
    /// the old task stops today and a new one starts.
    static func syncLinkedTask(
        for alarm: AlarmRecord,
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        context: ModelContext,
        today: DayKey
    ) {
        guard alarm.isMainTask else { return }
        let repetition = alarm.repetition
        var start = today
        if case .once(let day) = repetition { start = day }

        let linked = tasks.first { $0.alarmID == alarm.id && $0.endDay == nil }
        guard let linked else {
            let order = (tasks.map(\.sortOrder).max() ?? -1) + 1
            let task = TaskRecord(title: alarm.title, kind: .main, repetition: repetition, startDay: start, sortOrder: order)
            task.alarmID = alarm.id
            context.insert(task)
            try? context.save()
            return
        }

        let hasHistory = completions.contains { $0.taskID == linked.id }
        let scheduleChanged = linked.kind != .main || linked.repetition != repetition
        if hasHistory && scheduleChanged {
            linked.endDay = today
            linked.alarmID = nil
            let task = TaskRecord(title: alarm.title, kind: .main, repetition: repetition, startDay: start, notes: linked.notes, sortOrder: linked.sortOrder)
            task.alarmID = alarm.id
            context.insert(task)
        } else {
            linked.title = alarm.title
            linked.kind = .main
            linked.repetition = repetition
            if case .once(let day) = repetition {
                linked.startDay = day
            } else {
                linked.startDay = min(linked.startDay, today)
            }
        }
        try? context.save()
    }

    /// The alarm stops being a main-task alarm: keep the task as a normal one, or remove it
    /// (a task with history is only stopped from today, like any delete).
    static func unlinkTask(
        of alarm: AlarmRecord,
        deleteTask: Bool,
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        context: ModelContext,
        today: DayKey
    ) {
        for task in tasks where task.alarmID == alarm.id {
            if deleteTask && task.endDay == nil {
                let hadHistory = completions.contains { $0.taskID == task.id }
                _ = TaskActions.delete(task, completions: completions, context: context, today: today)
                if !hadHistory { continue }   // removed completely
            }
            task.alarmID = nil
        }
        try? context.save()
    }

    static func hasLinkedTask(_ alarm: AlarmRecord, tasks: [TaskRecord]) -> Bool {
        tasks.contains { $0.alarmID == alarm.id && $0.endDay == nil }
    }

    // MARK: - Delete / undo

    /// Deleting an alarm keeps its task (still linked by id), so undo restores everything.
    static func delete(_ alarm: AlarmRecord, context: ModelContext) -> DeletedAlarmSnapshot {
        let snapshot = DeletedAlarmSnapshot(rule: alarm.rule, createdAt: alarm.createdAt)
        context.delete(alarm)
        try? context.save()
        return snapshot
    }

    static func undoDelete(_ snapshot: DeletedAlarmSnapshot, context: ModelContext) {
        context.insert(AlarmRecord(rule: snapshot.rule, createdAt: snapshot.createdAt))
        try? context.save()
    }

    // MARK: - From the notification button

    /// "تم ✓" on a notification: completes today's linked main task, in the background.
    static func completeLinkedTask(alarmID: UUID, container: ModelContainer) {
        let context = ModelContext(container)
        let calendar = Calendar.app
        let dayStartHour = UserDefaults.standard.integer(forKey: SettingsKey.dayStartHour)
        let today = DayKey(date: Date(), calendar: calendar, dayStartHour: dayStartHour)
        let tasks = (try? context.fetch(FetchDescriptor<TaskRecord>())) ?? []
        let completions = (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? []
        for task in tasks where task.alarmID == alarmID && task.kind == .main && task.spec.isScheduled(on: today, calendar: calendar) {
            if !completions.contains(where: { $0.taskID == task.id && $0.day == today }) {
                context.insert(CompletionRecord(taskID: task.id, day: today))
            }
        }
        try? context.save()
    }

    // MARK: - Finished one-time alarms

    /// A one-time alarm switches itself off after it has rung (it stays in the list, like the Clock app).
    static func expireFinished(context: ModelContext, now: Date = Date()) {
        let calendar = Calendar.app
        let alarms = (try? context.fetch(FetchDescriptor<AlarmRecord>())) ?? []
        let provider = PrayerLocation.load()?.provider
        var changed = false
        for alarm in alarms where alarm.isEnabled {
            guard case .once(let day) = alarm.repetition,
                  let fire = NotificationPlanner.fireDate(of: alarm.rule, on: day, provider: provider, calendar: calendar),
                  fire <= now else { continue }
            alarm.isEnabled = false
            changed = true
        }
        if changed { try? context.save() }
    }

    // MARK: - Re-planning

    /// After any alarm is saved or switched on: ask for notification permission the first
    /// time (never earlier), then refresh the pending notifications.
    static func requestAndReplan() async {
        await AlarmScheduler.requestAuthorizationIfNeeded()
        await replan(container: AppEnvironment.shared.container)
    }

    /// Reads alarms and the prayer location from storage and refreshes the pending notifications.
    static func replan(container: ModelContainer) async {
        let context = ModelContext(container)
        expireFinished(context: context)
        let alarms = ((try? context.fetch(FetchDescriptor<AlarmRecord>())) ?? []).map(\.rule)
        let location = PrayerLocation.load()
        await AlarmScheduler.replan(alarms: alarms, location: location)
    }
}
