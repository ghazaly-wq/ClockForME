import Foundation
import HabitCore
import SwiftData

/// What happened because of a completion, so the UI can celebrate.
struct CompletionOutcome {
    var completedDay = false
    var newLevel: ProgressSummary?
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

        let before = ProgressSnapshot.make(tasks: tasks, completions: completions, now: now, dayStartHour: dayStartHour)
        let record = CompletionRecord(taskID: task.id, day: day, completedAt: now)
        context.insert(record)
        try? context.save()
        let after = ProgressSnapshot.make(tasks: tasks, completions: completions + [record], now: now, dayStartHour: dayStartHour)

        var outcome = CompletionOutcome()
        if task.kind == .main, before.todayMain.state != .complete, after.todayMain.state == .complete {
            outcome.completedDay = true
        }
        if after.summary.level > before.summary.level {
            outcome.newLevel = after.summary
        }
        return outcome
    }

    /// Deleting a task that has history only stops it from appearing from today on,
    /// so past days (and the streak) are not rewritten.
    static func delete(
        _ task: TaskRecord,
        completions: [CompletionRecord],
        context: ModelContext,
        today: DayKey
    ) {
        if completions.contains(where: { $0.taskID == task.id }) {
            task.endDay = today
        } else {
            context.delete(task)
        }
        try? context.save()
    }
}
