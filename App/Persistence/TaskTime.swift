import Foundation
import HabitCore

extension TaskRecord {
    /// The moment this task is due on `day` (tasks made from an alarm carry its time), if it has one.
    /// Prayer-based times need a provider; without one the result is nil.
    func dueDate(on day: DayKey, provider: PrayerTimeProviding?, calendar: Calendar) -> Date? {
        guard let time else { return nil }
        let rule = AlarmRule(title: "", repetition: .daily, time: time)
        return NotificationPlanner.fireDate(of: rule, on: day, provider: provider, calendar: calendar)
    }
}
