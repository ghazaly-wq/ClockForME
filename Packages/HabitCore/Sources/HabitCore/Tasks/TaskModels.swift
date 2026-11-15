import Foundation

public enum TaskKind: String, Codable, CaseIterable, Sendable {
    /// The day's focus: drives the streak and the Live Activity.
    case main
    /// Extra tasks: same XP, but no effect on the streak.
    case secondary
}

/// The scheduling facts about a task that the rules need (no UI, no storage).
public struct TaskSpec: Equatable, Sendable {
    public let id: UUID
    public let kind: TaskKind
    /// `nil` means "anytime, until done" (secondary tasks only).
    public let repetition: Repetition?
    /// First day the task can appear.
    public let startDay: DayKey
    /// The day the task stopped appearing (exclusive). History before it is kept.
    public let endDay: DayKey?

    public init(id: UUID, kind: TaskKind, repetition: Repetition?, startDay: DayKey, endDay: DayKey? = nil) {
        self.id = id
        self.kind = kind
        self.repetition = repetition
        self.startDay = startDay
        self.endDay = endDay
    }

    public func isScheduled(on day: DayKey, calendar: Calendar) -> Bool {
        guard let repetition else { return false }
        if day < startDay { return false }
        if let endDay, day >= endDay { return false }
        return repetition.occurs(on: day, calendar: calendar)
    }
}

/// How much of a day's main tasks is done.
public struct DayProgress: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case noTasks    // nothing scheduled: neutral
        case none       // tasks scheduled, 0% done
        case partial    // some done, not all
        case complete   // all done
    }

    public let total: Int
    public let completed: Int

    public init(total: Int, completed: Int) {
        self.total = max(0, total)
        self.completed = min(max(0, completed), max(0, total))
    }

    public var state: State {
        if total == 0 { return .noTasks }
        if completed == 0 { return .none }
        return completed == total ? .complete : .partial
    }

    public var fraction: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }

    /// Progress of the main tasks scheduled on `day`.
    public static func compute(day: DayKey, specs: [TaskSpec], completedIDs: Set<UUID>, calendar: Calendar) -> DayProgress {
        var total = 0
        var done = 0
        for spec in specs where spec.kind == .main && spec.isScheduled(on: day, calendar: calendar) {
            total += 1
            if completedIDs.contains(spec.id) { done += 1 }
        }
        return DayProgress(total: total, completed: done)
    }
}
