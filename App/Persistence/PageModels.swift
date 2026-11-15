import Foundation
import HabitCore
import SwiftData

/// A custom page ("صفحاتي"). The structure lives in `definition` (JSON of HabitCore's `PageDefinition`).
@Model
final class PageRecord {
    @Attribute(.unique) var id: UUID
    var definitionData: Data
    var createdAt: Date
    var sortOrder: Int = 0
    /// A saved template ("قوالبي"): never shown in the pages list, only in the new-page sheet.
    var isTemplate: Bool = false

    init(definition: PageDefinition, createdAt: Date = Date(), sortOrder: Int = 0, isTemplate: Bool = false) {
        self.id = definition.id
        self.definitionData = (try? JSONEncoder().encode(definition)) ?? Data()
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.isTemplate = isTemplate
    }
}

extension PageRecord {
    var definition: PageDefinition {
        get {
            if let value = try? JSONDecoder().decode(PageDefinition.self, from: definitionData) {
                return value
            }
            return PageDefinition(id: id, name: "صفحة", tabs: [PageTab(name: "الرئيسية")])
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { definitionData = data }
        }
    }
}

/// One saved use of a page (what was typed). Plain fields are kept for filtering; the full value is JSON.
@Model
final class PageSessionRecord {
    @Attribute(.unique) var id: UUID
    var pageID: UUID
    var tabID: UUID
    var dayISO: String
    var startedAt: Date
    var isFinished: Bool
    var sessionData: Data

    init(session: PageSession) {
        self.id = session.id
        self.pageID = session.pageID
        self.tabID = session.tabID
        self.dayISO = session.day.isoString
        self.startedAt = session.startedAt
        self.isFinished = session.isFinished
        self.sessionData = (try? JSONEncoder().encode(session)) ?? Data()
    }
}

extension PageSessionRecord {
    var session: PageSession? {
        try? JSONDecoder().decode(PageSession.self, from: sessionData)
    }

    func apply(_ session: PageSession) {
        tabID = session.tabID
        dayISO = session.day.isoString
        startedAt = session.startedAt
        isFinished = session.isFinished
        if let data = try? JSONEncoder().encode(session) { sessionData = data }
    }
}
