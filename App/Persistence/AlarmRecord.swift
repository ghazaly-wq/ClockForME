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

    var rule: AlarmRule {
        AlarmRule(id: id, title: title, note: note, isEnabled: isEnabled, repetition: repetition, time: time, isMainTask: isMainTask, linkedPageID: linkedPageID)
    }

    func apply(_ rule: AlarmRule) {
        title = rule.title
        note = rule.note
        isEnabled = rule.isEnabled
        repetition = rule.repetition
        time = rule.time
        isMainTask = rule.isMainTask
        linkedPageID = rule.linkedPageID
    }

    /// Changes whenever anything that affects notifications changes.
    var fingerprint: String {
        "\(id.uuidString)|\(title)|\(note)|\(isEnabled)|\(isMainTask)|\(linkedPageID?.uuidString ?? "")|\(repetitionData.base64EncodedString())|\(timeData.base64EncodedString())"
    }
}
