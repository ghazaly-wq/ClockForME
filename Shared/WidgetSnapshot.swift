import Foundation

/// What the widgets know about today. The app writes it as JSON into the App Group
/// container; the widgets only read it.
struct WidgetSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        /// For a task with several times (its alarm follows several prayers) this is the earliest.
        var time: Date?
        var done: Bool
        /// Every time today when there are several; nil or empty for ordinary tasks (older snapshots too).
        var times: [Date]? = nil
    }

    var generatedAt: Date
    /// When the day this snapshot describes ends (respecting the day-start hour).
    var dayEnd: Date
    var items: [Item]
    var streak: Int
    var level: Int
    var levelTitle: String
    var nextAlarmTitle: String?
    var nextAlarmDate: Date?
    var arabicDigits: Bool
    var styleID: String
    /// Setting: a task with several times is ranked by its next ring, not its first. nil = off (older snapshots).
    var followsNextRing: Bool? = nil

    var total: Int { items.count }
    var completed: Int { items.filter(\.done).count }
    var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    var segments: [Bool] { items.map(\.done) }

    /// Same rule as the app's "next task": the soonest timed task not yet passed, else the first
    /// untimed one, else the most overdue timed one. Done tasks are skipped.
    func nextItem(at date: Date) -> Item? {
        let open = items.filter { !$0.done }
        let timed = open.compactMap { item in effectiveTime(of: item, at: date).map { (item: item, time: $0) } }
        if let upcoming = timed.filter({ $0.time >= date }).min(by: { $0.time < $1.time }) { return upcoming.item }
        if let untimed = open.first(where: { $0.time == nil }) { return untimed }
        return timed.min(by: { $0.time < $1.time })?.item
    }

    /// The time to show and rank a task by at `date`: its first time, or (with the setting on and several
    /// times) its next ring, else its last one. Mirrors `TodayTaskItem.effectiveTime` in HabitCore.
    func effectiveTime(of item: Item, at date: Date) -> Date? {
        guard followsNextRing == true, let times = item.times?.sorted(), times.count > 1 else { return item.time }
        return times.first(where: { $0 >= date }) ?? times.last
    }

    /// Every moment the widget should refresh at: each task time, today.
    var allTimes: [Date] {
        items.flatMap { item -> [Date] in
            if let times = item.times, !times.isEmpty { return times }
            return item.time.map { [$0] } ?? []
        }
    }

    // MARK: - Storage

    private static let fileName = "widget-snapshot.json"

    private static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(fileName)
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    @discardableResult
    func save() -> Bool {
        guard let url = Self.fileURL else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(self) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}
