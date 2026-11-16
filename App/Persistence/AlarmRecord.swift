import Foundation
import HabitCore
import SwiftData

/// An alarm the owner created. The pure form is `AlarmRule` (in HabitCore).
@Model
final class AlarmRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var note: String
    var isEnabled: Bool
    var repetitionData: Data
    var timeData: Data
    var isMainTask: Bool
    var createdAt: Date
    /// The custom page this alarm belongs to, if any.
    var linkedPageID: UUID? = nil
    /// JSON of `[Prayer]`: more prayers that ring with the same offset (nil = just the main one).
    var extraPrayersData: Data? = nil
    /// Last day a routine still rings (`yyyy-MM-dd`), nil = never ends.
    var endDayISO: String? = nil
    /// `AlarmDelivery` raw value; nil (older data) means a ringing alarm.
    var deliveryRaw: String? = nil
    /// JSON of `AlarmChallenge`; nil (older data or no challenge) means a normal alarm.
    var challengeData: Data? = nil
    /// JSON of `StopDestination`; nil means the stop button opens this app.
    var destinationData: Data? = nil

    init(rule: AlarmRule, createdAt: Date = Date()) {
        self.id = rule.id
        self.title = rule.title
        self.note = rule.note
        self.isEnabled = rule.isEnabled
        self.repetitionData = (try? JSONEncoder().encode(rule.repetition)) ?? Data()
        self.timeData = (try? JSONEncoder().encode(rule.time)) ?? Data()
        self.isMainTask = rule.isMainTask
        self.createdAt = createdAt
        self.linkedPageID = rule.linkedPageID
        self.extraPrayersData = rule.extraPrayers.isEmpty ? nil : (try? JSONEncoder().encode(rule.extraPrayers))
        self.endDayISO = rule.endDay?.isoString
        self.deliveryRaw = rule.delivery == .alarm ? nil : rule.delivery.rawValue
        self.challengeData = rule.challenge.flatMap { try? JSONEncoder().encode($0) }
        self.destinationData = rule.stopDestination.flatMap { try? JSONEncoder().encode($0) }
    }
}

extension AlarmRecord {
    var repetition: Repetition {
        get { (try? JSONDecoder().decode(Repetition.self, from: repetitionData)) ?? .daily }
        set { repetitionData = (try? JSONEncoder().encode(newValue)) ?? repetitionData }
    }

    var time: TimeSpec {
        get { (try? JSONDecoder().decode(TimeSpec.self, from: timeData)) ?? .clock(hour: 7, minute: 0) }
        set { timeData = (try? JSONEncoder().encode(newValue)) ?? timeData }
    }

    var extraPrayers: [Prayer] {
        guard let data = extraPrayersData else { return [] }
        return (try? JSONDecoder().decode([Prayer].self, from: data)) ?? []
    }

    var endDay: DayKey? { endDayISO.flatMap { DayKey(isoString: $0) } }

    var delivery: AlarmDelivery {
        get { deliveryRaw.flatMap { AlarmDelivery(rawValue: $0) } ?? .alarm }
        set { deliveryRaw = newValue == .alarm ? nil : newValue.rawValue }
    }

    var challenge: AlarmChallenge? {
        challengeData.flatMap { try? JSONDecoder().decode(AlarmChallenge.self, from: $0) }
    }

    var stopDestination: StopDestination? {
        destinationData.flatMap { try? JSONDecoder().decode(StopDestination.self, from: $0) }
    }

    var rule: AlarmRule {
        AlarmRule(
            id: id, title: title, note: note, isEnabled: isEnabled, repetition: repetition, time: time,
            isMainTask: isMainTask, linkedPageID: linkedPageID, extraPrayers: extraPrayers, endDay: endDay,
            delivery: delivery, challenge: challenge, stopDestination: stopDestination
        )
    }

    func apply(_ rule: AlarmRule) {
        title = rule.title
        note = rule.note
        isEnabled = rule.isEnabled
        repetition = rule.repetition
        time = rule.time
        isMainTask = rule.isMainTask
        linkedPageID = rule.linkedPageID
        extraPrayersData = rule.extraPrayers.isEmpty ? nil : (try? JSONEncoder().encode(rule.extraPrayers))
        endDayISO = rule.endDay?.isoString
        delivery = rule.delivery
        challengeData = rule.challenge.flatMap { try? JSONEncoder().encode($0) }
        destinationData = rule.stopDestination.flatMap { try? JSONEncoder().encode($0) }
    }

    /// Changes whenever anything that affects notifications changes.
    var fingerprint: String {
        "\(id.uuidString)|\(title)|\(note)|\(isEnabled)|\(isMainTask)|\(linkedPageID?.uuidString ?? "")|\(repetitionData.base64EncodedString())|\(timeData.base64EncodedString())|\(extraPrayersData?.base64EncodedString() ?? "")|\(endDayISO ?? "")|\(deliveryRaw ?? "")|\(challengeData?.base64EncodedString() ?? "")|\(destinationData?.base64EncodedString() ?? "")"
    }
}
