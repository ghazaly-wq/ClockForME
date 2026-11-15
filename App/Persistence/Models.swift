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

    var spec: TaskSpec {
        TaskSpec(id: id, kind: kind, repetition: repetition, startDay: startDay, endDay: endDay)
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
