import ActivityKit
import Foundation

/// The "today's main tasks" Live Activity. Keep the state small (well under 4 KB).
struct TodayActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// One entry per main task of the day; `true` when done.
        var segments: [Bool]
        var nextTitle: String?
        var nextTime: Date?
        var arabicDigits: Bool
        /// Shop style of the progress bar (`live.default`, `live.blocks`, `live.dots`).
        var styleID: String
        /// Shop theme id; optional so an activity started by an older build still decodes.
        var themeID: String? = nil

        var completed: Int { segments.filter { $0 }.count }
        var total: Int { segments.count }
        var allDone: Bool { total > 0 && completed == total }
        var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    }

    /// Day the activity was started for (`yyyy-MM-dd`), so an old one can be replaced.
    var dayKey: String
}
