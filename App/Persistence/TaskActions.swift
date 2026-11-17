import Foundation
import HabitCore
import SwiftData
import SwiftUI

/// What happened because of a completion, so the UI can celebrate.
struct CompletionOutcome {
    /// A task was marked done (false when a completion was removed).
    var didComplete = false
    var completedDay = false
    var newLevel: ProgressSummary?
    var newAchievements: [AchievementDef] = []
}

/// Everything needed to bring a hard-deleted task back.
struct DeletedTaskSnapshot {
    let id: UUID
    let title: String
    let kindRaw: String
    let repetitionData: Data?
    let startDayISO: String
    let endDayISO: String?
    let notes: String
    let createdAt: Date
    let sortOrder: Int
}

/// How to reverse a delete.
enum DeleteUndo {
    /// The task had history, so it was only stopped from today on.
    case restoreEndDay(TaskRecord, previous: String?)
    /// The task had no history and was removed completely.
    case recreate(DeletedTaskSnapshot)
}

@MainActor
enum TaskActions {
    /// Marks a task done for `day`, or removes that completion (which revokes its XP and points).
    @discardableResult
    static func toggle(
        _ task: TaskRecord,
        on day: DayKey,
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        context: ModelContext,
        now: Date,
        dayStartHour: Int
    ) -> CompletionOutcome {
        if let existing = completions.first(where: { $0.taskID == task.id && $0.day == day }) {
            context.delete(existing)
            try? context.save()
            return CompletionOutcome()
        }

        let before = ProgressSnapshot.make(
            tasks: tasks, completions: completions, now: now, dayStartHour: dayStartHour,
            extras: ProgressExtras.load(context: context)
        )
        let record = CompletionRecord(taskID: task.id, day: day, completedAt: now)
        context.insert(record)
        try? context.save()
        let updated = completions + [record]
        let sync = AchievementActions.sync(tasks: tasks, completions: updated, context: context, now: now, dayStartHour: dayStartHour)
        let after = ProgressSnapshot.make(
            tasks: tasks, completions: updated, now: now, dayStartHour: dayStartHour,
            extras: ProgressExtras.load(context: context)
        )

        var outcome = CompletionOutcome()
        outcome.didComplete = true
        if task.kind == .main, before.todayMain.state != .complete, after.todayMain.state == .complete {
            outcome.completedDay = true
        }
        if after.summary.level > before.summary.level {
            outcome.newLevel = after.summary
        }
        outcome.newAchievements = sync.unlocked
        return outcome
    }

    /// Deleting a task that has history only stops it from appearing from today on,
    /// so past days (and the streak) are not rewritten. Returns a token to undo it.
    static func delete(
        _ task: TaskRecord,
        completions: [CompletionRecord],
        context: ModelContext,
        today: DayKey
    ) -> DeleteUndo {
        let undo: DeleteUndo
        if completions.contains(where: { $0.taskID == task.id }) {
            undo = .restoreEndDay(task, previous: task.endDayISO)
            task.endDay = today
        } else {
            undo = .recreate(DeletedTaskSnapshot(
                id: task.id, title: task.title, kindRaw: task.kindRaw, repetitionData: task.repetitionData,
                startDayISO: task.startDayISO, endDayISO: task.endDayISO, notes: task.notes,
                createdAt: task.createdAt, sortOrder: task.sortOrder
            ))
            context.delete(task)
        }
        try? context.save()
        return undo
    }

    static func undoDelete(_ undo: DeleteUndo, context: ModelContext) {
        switch undo {
        case .restoreEndDay(let task, let previous):
            task.endDayISO = previous
        case .recreate(let snapshot):
            let task = TaskRecord(
                id: snapshot.id, title: snapshot.title, kind: .main, repetition: nil,
                startDay: DayKey(isoString: snapshot.startDayISO) ?? DayKey(year: 1970, month: 1, day: 1),
                notes: snapshot.notes, createdAt: snapshot.createdAt, sortOrder: snapshot.sortOrder
            )
            task.kindRaw = snapshot.kindRaw
            task.repetitionData = snapshot.repetitionData
            task.endDayISO = snapshot.endDayISO
            context.insert(task)
        }
        try? context.save()
    }

    /// Reorders the tasks shown in a list. Other tasks keep their places, so the
    /// order stays sensible on days that show a different set of tasks.
    static func move(
        displayed: [TaskRecord],
        from source: IndexSet,
        to destination: Int,
        allTasks: [TaskRecord],
        context: ModelContext
    ) {
        // Give every task a distinct position first (old data all starts at 0).
        let ordered = allTasks.sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
        for (index, task) in ordered.enumerated() { task.sortOrder = index }

        var reordered = displayed
        reordered.move(fromOffsets: source, toOffset: destination)
        let slots = displayed.map(\.sortOrder).sorted()
        for (task, slot) in zip(reordered, slots) { task.sortOrder = slot }
        try? context.save()
    }
}
