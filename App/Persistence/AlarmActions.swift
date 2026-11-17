import Foundation
import HabitCore
import SwiftData

/// What happened to an alarm that was deleted, so it can come back.
struct DeletedAlarmSnapshot {
    let rule: AlarmRule
    let createdAt: Date
    /// Deleting a main-task alarm also removes its task; these bring it back.
    let taskUndos: [DeleteUndo]
    let taskIDs: [UUID]
}

/// A task delete from the Tasks list, plus the alarm that went with it (if any).
struct TaskDeletion {
    let taskUndo: DeleteUndo
    let alarm: DeletedAlarmSnapshot?
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
            task.time = alarm.time
            task.extraPrayers = alarm.extraPrayers
            task.routineEnd = alarm.endDay
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
            task.time = alarm.time
            task.extraPrayers = alarm.extraPrayers
            task.routineEnd = alarm.endDay
            context.insert(task)
        } else {
            linked.title = alarm.title
            linked.time = alarm.time
            linked.extraPrayers = alarm.extraPrayers
            linked.routineEnd = alarm.endDay
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

    /// Deleting an alarm also removes the main task linked to it (a task with history is only
    /// stopped from today, like any delete) and cancels anything AlarmKit still holds, even a snoozed alarm.
    static func delete(
        _ alarm: AlarmRecord,
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        context: ModelContext,
        today: DayKey
    ) -> DeletedAlarmSnapshot {
        var undos: [DeleteUndo] = []
        var ids: [UUID] = []
        for task in tasks where task.alarmID == alarm.id && task.endDay == nil {
            ids.append(task.id)
            undos.append(TaskActions.delete(task, completions: completions, context: context, today: today))
        }
        let snapshot = DeletedAlarmSnapshot(rule: alarm.rule, createdAt: alarm.createdAt, taskUndos: undos, taskIDs: ids)
        AlarmScheduler.cancelAll(forRule: alarm.id)
        context.delete(alarm)
        try? context.save()
        return snapshot
    }

    static func undoDelete(_ snapshot: DeletedAlarmSnapshot, context: ModelContext) {
        context.insert(AlarmRecord(rule: snapshot.rule, createdAt: snapshot.createdAt))
        for undo in snapshot.taskUndos { TaskActions.undoDelete(undo, context: context) }
        let tasks = (try? context.fetch(FetchDescriptor<TaskRecord>())) ?? []
        for task in tasks where snapshot.taskIDs.contains(task.id) { task.alarmID = snapshot.rule.id }
        try? context.save()
    }

    // MARK: - Deleting a task that came from an alarm

    /// Deleting a task from the Tasks list also deletes the alarm it was made from.
    static func deleteTask(
        _ task: TaskRecord,
        alarms: [AlarmRecord],
        completions: [CompletionRecord],
        context: ModelContext,
        today: DayKey
    ) -> TaskDeletion {
        var alarmSnapshot: DeletedAlarmSnapshot?
        if let alarmID = task.alarmID, let alarm = alarms.first(where: { $0.id == alarmID }) {
            alarmSnapshot = DeletedAlarmSnapshot(rule: alarm.rule, createdAt: alarm.createdAt, taskUndos: [], taskIDs: [task.id])
            AlarmScheduler.cancelAll(forRule: alarm.id)
            context.delete(alarm)
        }
        let undo = TaskActions.delete(task, completions: completions, context: context, today: today)
        try? context.save()
        return TaskDeletion(taskUndo: undo, alarm: alarmSnapshot)
    }

    static func undoDeleteTask(_ deletion: TaskDeletion, context: ModelContext) {
        if let alarm = deletion.alarm {
            context.insert(AlarmRecord(rule: alarm.rule, createdAt: alarm.createdAt))
        }
        TaskActions.undoDelete(deletion.taskUndo, context: context)
        if let alarm = deletion.alarm {
            let tasks = (try? context.fetch(FetchDescriptor<TaskRecord>())) ?? []
            for task in tasks where alarm.taskIDs.contains(task.id) { task.alarmID = alarm.rule.id }
        }
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

    /// Tasks made from an alarm before tasks had a time get it now, and tasks made before alarms could
    /// follow several prayers pick up the extra prayers of their alarm (or of their page's alarm).
    static func backfillTaskTimes(context: ModelContext) {
        let alarms = (try? context.fetch(FetchDescriptor<AlarmRecord>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<TaskRecord>())) ?? []
        var changed = false
        for task in tasks where task.endDay == nil {
            let alarm: AlarmRecord?
            if let alarmID = task.alarmID {
                alarm = alarms.first { $0.id == alarmID }
            } else if let pageID = task.pageID {
                alarm = alarms.first { $0.linkedPageID == pageID }
            } else {
                alarm = nil
            }
            guard let alarm else { continue }
            if task.timeData == nil {
                task.time = alarm.time
                changed = true
            }
            if task.extraPrayers != alarm.extraPrayers && task.time == alarm.time {
                task.extraPrayers = alarm.extraPrayers
                changed = true
            }
        }
        if changed { try? context.save() }
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
        let container = AppEnvironment.shared.container
        let context = ModelContext(container)
        let rules = ((try? context.fetch(FetchDescriptor<AlarmRecord>())) ?? []).map(\.rule).filter(\.isEnabled)
        if rules.contains(where: { $0.delivery == .alarm }) { await AlarmScheduler.requestAuthorizationIfNeeded() }
        if rules.contains(where: { $0.delivery == .notification }) { await AlarmNotifier.requestAuthorizationIfNeeded() }
        await replan(container: container)
    }

    /// Alarm/day pairs whose linked task (a main-task alarm's task, or a page's task) is already done, as
    /// `NotificationPlanner.doneKey`s: those days' rings are not scheduled, so finishing a task early silences its alarm.
    static func completedOccurrences(
        alarms: [AlarmRecord], tasks: [TaskRecord], completions: [CompletionRecord]
    ) -> Set<String> {
        var alarmsOfTask: [UUID: [UUID]] = [:]
        for task in tasks where task.kind == .main {
            var ids: [UUID] = []
            if let alarmID = task.alarmID { ids.append(alarmID) }
            if let pageID = task.pageID { ids += alarms.filter { $0.linkedPageID == pageID }.map(\.id) }
            if !ids.isEmpty { alarmsOfTask[task.id] = ids }
        }
        var keys = Set<String>()
        for completion in completions {
            for alarmID in alarmsOfTask[completion.taskID] ?? [] {
                keys.insert(NotificationPlanner.doneKey(alarmID: alarmID, day: completion.day))
            }
        }
        return keys
    }

    /// Reads alarms and the prayer location from storage and refreshes the pending notifications.
    static func replan(container: ModelContainer) async {
        let context = ModelContext(container)
        expireFinished(context: context)
        backfillTaskTimes(context: context)
        let records = (try? context.fetch(FetchDescriptor<AlarmRecord>())) ?? []
        let alarms = records.map(\.rule)
        let tasks = (try? context.fetch(FetchDescriptor<TaskRecord>())) ?? []
        let completions = (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? []
        let completed = completedOccurrences(alarms: records, tasks: tasks, completions: completions)
        let location = PrayerLocation.load()
        // Ringing alarms go through AlarmKit; "notification only" ones are plain local notifications.
        await AlarmScheduler.replan(alarms: alarms.filter { $0.delivery == .alarm }, location: location, completed: completed)
        await AlarmNotifier.replan(alarms: alarms.filter { $0.delivery == .notification }, location: location, completed: completed)
    }
}
