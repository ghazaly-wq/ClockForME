import Foundation
import HabitCore
import SwiftData

/// A task the owner created. Scheduling details are stored in plain fields so the
/// pure rules in HabitCore can read them through `spec`.
@Model
final class TaskRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var kindRaw: String
    /// JSON of `Repetition`; `nil` means "anytime, until done" (secondary tasks only).
    var repetitionData: Data?
    var startDayISO: String
    /// The day the task stopped appearing (exclusive). Set instead of deleting a task that has history.
    var endDayISO: String?
    var notes: String
    var createdAt: Date
    /// Position in lists (lower first). Default keeps existing data migratable.
    var sortOrder: Int = 0
    /// The alarm this task was created from ("main-task alarm"), if any.
    var alarmID: UUID? = nil
    /// JSON of `TimeSpec`: the time of the alarm this task came from, if any.
    var timeData: Data? = nil
    /// The custom page this task belongs to (finishing the page's session completes it).
    var pageID: UUID? = nil
    /// Last day of a routine that ends (inclusive), copied from the alarm it came from. Unlike `endDay` this is
    /// not "stopped by the owner", so the task still counts as the alarm's active task.
    var routineEndISO: String? = nil
    /// More prayers the task's alarm follows with the same offset as `time` (copied from the alarm or page).
    var extraPrayersData: Data? = nil

    init(
        id: UUID = UUID(),
        title: String,
        kind: TaskKind,
        repetition: Repetition?,
        startDay: DayKey,
        notes: String = "",
        createdAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.kindRaw = kind.rawValue
        self.repetitionData = repetition.flatMap { try? JSONEncoder().encode($0) }
        self.startDayISO = startDay.isoString
        self.endDayISO = nil
        self.notes = notes
        self.createdAt = createdAt
    }
}

extension TaskRecord {
    var kind: TaskKind {
        get { TaskKind(rawValue: kindRaw) ?? .main }
        set { kindRaw = newValue.rawValue }
    }

    var repetition: Repetition? {
        get {
            guard let data = repetitionData else { return nil }
            return try? JSONDecoder().decode(Repetition.self, from: data)
        }
        set {
            if let newValue {
                repetitionData = try? JSONEncoder().encode(newValue)
            } else {
                repetitionData = nil
            }
        }
    }

    var time: TimeSpec? {
        get {
            guard let data = timeData else { return nil }
            return try? JSONDecoder().decode(TimeSpec.self, from: data)
        }
        set { timeData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    var startDay: DayKey {
        get { DayKey(isoString: startDayISO) ?? DayKey(year: 1970, month: 1, day: 1) }
        set { startDayISO = newValue.isoString }
    }

    var endDay: DayKey? {
        get {
            guard let iso = endDayISO else { return nil }
            return DayKey(isoString: iso)
        }
        set { endDayISO = newValue?.isoString }
    }

    var extraPrayers: [Prayer] {
        get {
            guard let data = extraPrayersData else { return [] }
            return (try? JSONDecoder().decode([Prayer].self, from: data)) ?? []
        }
        set { extraPrayersData = newValue.isEmpty ? nil : (try? JSONEncoder().encode(newValue)) }
    }

    var routineEnd: DayKey? {
        get { routineEndISO.flatMap { DayKey(isoString: $0) } }
        set { routineEndISO = newValue?.isoString }
    }

    var spec: TaskSpec {
        // A routine end day (inclusive) acts like an exclusive stop on the day after it.
        var stop = endDay
        if let last = routineEnd, let after = last.adding(days: 1, calendar: Calendar.app) {
            stop = stop.map { min($0, after) } ?? after
        }
        return TaskSpec(id: id, kind: kind, repetition: repetition, startDay: startDay, endDay: stop)
    }
}

/// "This task was done on this day." XP and points are derived from these, never stored,
/// so removing a record automatically revokes what it gave.
@Model
final class CompletionRecord {
    var id: UUID
    var taskID: UUID
    var dayISO: String
    var completedAt: Date

    init(id: UUID = UUID(), taskID: UUID, day: DayKey, completedAt: Date = Date()) {
        self.id = id
        self.taskID = taskID
        self.dayISO = day.isoString
        self.completedAt = completedAt
    }
}

extension CompletionRecord {
    var day: DayKey {
        DayKey(isoString: dayISO) ?? DayKey(year: 1970, month: 1, day: 1)
    }
}
