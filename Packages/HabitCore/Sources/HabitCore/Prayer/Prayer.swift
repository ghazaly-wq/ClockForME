import Foundation

/// The five daily prayers.
public enum Prayer: String, Codable, CaseIterable, Sendable {
    case fajr, dhuhr, asr, maghrib, isha
}

/// Before or after a prayer, for alarms like "30 minutes before Fajr".
public enum Direction: String, Codable, Sendable {
    case before, after
}

/// Source of prayer times for a day. The app uses `AdhanPrayerTimes`;
/// tests can plug in fixed times.
public protocol PrayerTimeProviding {
    /// The five prayer moments of a calendar day, or nil when they can't be computed.
    func times(for day: DayKey, calendar: Calendar) -> [Prayer: Date]?
}
