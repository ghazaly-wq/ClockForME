import Foundation

/// What the widgets know about today. The app writes it as JSON into the App Group
/// container; the widgets only read it.
struct WidgetSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var time: Date?
        var done: Bool
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

    var total: Int { items.count }
    var completed: Int { items.filter(\.done).count }
    var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    var segments: [Bool] { items.map(\.done) }

    /// Same rule as the app's "next task": the soonest timed task not yet passed, else the first
    /// untimed one, else the most overdue timed one. Done tasks are skipped.
    func nextItem(at date: Date) -> Item? {
        let open = items.filter { !$0.done }
        if let upcoming = open
            .filter({ ($0.time ?? .distantPast) >= date && $0.time != nil })
            .min(by: { ($0.time ?? .distantFuture) < ($1.time ?? .distantFuture) }) {
            return upcoming
        }
        if let untimed = open.first(where: { $0.time == nil }) { return untimed }
        return open.min { ($0.time ?? .distantFuture) < ($1.time ?? .distantFuture) }
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
