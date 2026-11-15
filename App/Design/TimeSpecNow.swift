import HabitCore
import Foundation

extension TimeSpec {
    /// A clock time set to the current hour and minute (the default when a time is first picked).
    static func currentClock(now: Date = Date(), calendar: Calendar = .app) -> TimeSpec {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        return .clock(hour: parts.hour ?? 7, minute: parts.minute ?? 0)
    }
}
