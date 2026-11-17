import Foundation

/// What the app-blocking rule needs to know about one task on one day.
public struct BlockCandidate: Equatable, Sendable {
    public let id: UUID
    /// The owner switched "block apps until I finish this" on for the task.
    public let blocksApps: Bool
    /// Already done for the day being checked.
    public let isDone: Bool
    /// Every time the task is due that day (several when its alarm follows several prayers). Empty = no time.
    public let dueTimes: [Date]

    public init(id: UUID, blocksApps: Bool, isDone: Bool, dueTimes: [Date]) {
        self.id = id
        self.blocksApps = blocksApps
        self.isDone = isDone
        self.dueTimes = dueTimes.sorted()
    }
}

/// Decides which tasks are blocking the owner's chosen apps right now. Pure: the time is passed in.
///
/// The app can't close other apps by itself. The owner makes a Shortcuts automation that opens this app whenever
/// one of the chosen apps opens, and this rule says whether the app should then show its "finish your task first"
/// screen.
public enum AppBlockRule {
    /// A task blocks from the moment its first time of the day arrives until it is done.
    /// Tasks without the switch, finished tasks, tasks with no time and tasks whose time hasn't come yet never block.
    public static func blockingIDs(_ items: [BlockCandidate], now: Date) -> [UUID] {
        items.compactMap { item in
            guard item.blocksApps, !item.isDone, let first = item.dueTimes.first, first <= now else { return nil }
            return item.id
        }
    }
}
