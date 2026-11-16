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

/// How an alarm reaches the owner.
public enum AlarmDelivery: String, Codable, CaseIterable, Equatable, Sendable {
    /// A real alarm: covers the screen and rings (AlarmKit).
    case alarm
    /// Only a notification: a banner and a sound, no ringing screen.
    case notification
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
    /// Set when the alarm belongs to a custom page (stopping it opens that page).
    public var linkedPageID: UUID?
    /// More prayers that ring with the same before/after offset as `time` (which must then be prayer-based).
    public var extraPrayers: [Prayer]
    /// Last day a weekly/monthly routine still rings (inclusive). `nil` = never ends.
    public var endDay: DayKey?
    /// A ringing alarm (default) or just a notification.
    public var delivery: AlarmDelivery
    /// What must be done before the alarm stops ringing; nil = a normal alarm.
    public var challenge: AlarmChallenge?
    /// Where the stop button leads instead of this app; nil = this app.
    public var stopDestination: StopDestination?

    public init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        isEnabled: Bool = true,
        repetition: Repetition,
        time: TimeSpec,
        isMainTask: Bool = false,
        linkedPageID: UUID? = nil,
        extraPrayers: [Prayer] = [],
        endDay: DayKey? = nil,
        delivery: AlarmDelivery = .alarm,
        challenge: AlarmChallenge? = nil,
        stopDestination: StopDestination? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.isEnabled = isEnabled
        self.repetition = repetition
        self.time = time
        self.isMainTask = isMainTask
        self.linkedPageID = linkedPageID
        self.extraPrayers = extraPrayers
        self.endDay = endDay
        self.delivery = delivery
        self.challenge = challenge
        self.stopDestination = stopDestination
    }

    /// A ringing alarm that must be stopped with a challenge (a notification can't ask for one).
    public var hasChallenge: Bool { delivery == .alarm && challenge != nil }

    /// A challenge or a destination only makes sense for a ringing alarm.
    public var usesStopOverride: Bool {
        delivery == .alarm && (challenge != nil || stopDestination?.isValid == true)
    }

    /// Part of the alarm's fingerprint: changes when the challenge or the destination changes.
    public var stopOverrideFingerprint: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let challengeText = challenge.flatMap { try? encoder.encode($0) }.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let destinationText = stopDestination.flatMap { try? encoder.encode($0) }.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return challengeText + "|" + destinationText
    }

    /// Every prayer this alarm follows, the main one first. Empty for clock alarms.
    public var prayers: [Prayer] {
        guard case let .prayer(first, _, _, _) = time else { return [] }
        return [first] + extraPrayers.filter { $0 != first }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, note, isEnabled, repetition, time, isMainTask, linkedPageID, extraPrayers, endDay, delivery, challenge, stopDestination
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        note = try c.decode(String.self, forKey: .note)
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
        repetition = try c.decode(Repetition.self, forKey: .repetition)
        time = try c.decode(TimeSpec.self, forKey: .time)
        isMainTask = try c.decode(Bool.self, forKey: .isMainTask)
        linkedPageID = try c.decodeIfPresent(UUID.self, forKey: .linkedPageID)
        extraPrayers = try c.decodeIfPresent([Prayer].self, forKey: .extraPrayers) ?? []
        endDay = try c.decodeIfPresent(DayKey.self, forKey: .endDay)
        delivery = try c.decodeIfPresent(AlarmDelivery.self, forKey: .delivery) ?? .alarm
        challenge = try c.decodeIfPresent(AlarmChallenge.self, forKey: .challenge)
        stopDestination = try c.decodeIfPresent(StopDestination.self, forKey: .stopDestination)
    }
}
