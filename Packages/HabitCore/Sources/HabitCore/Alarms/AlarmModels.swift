import Foundation

/// When an alarm rings on a day it occurs.
public enum TimeSpec: Codable, Equatable, Sendable {
    /// A plain clock time.
    case clock(hour: Int, minute: Int)
    /// Relative to a prayer: `hours` + `minutes` before or after it.
    case prayer(Prayer, Direction, hours: Int, minutes: Int)

    public var isPrayerBased: Bool {
        if case .prayer = self { return true }
        return false
    }
}

/// An alarm definition (the app stores it in SwiftData; this is the pure form).
public struct AlarmRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var note: String
    public var isEnabled: Bool
    public var repetition: Repetition
    public var time: TimeSpec
    public var isMainTask: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        isEnabled: Bool = true,
        repetition: Repetition,
        time: TimeSpec,
        isMainTask: Bool = false
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.isEnabled = isEnabled
        self.repetition = repetition
        self.time = time
        self.isMainTask = isMainTask
    }
}
