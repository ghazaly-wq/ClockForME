import Foundation

/// Counts complete days finished before Dhuhr / after Isha.
public enum AchievementTiming {
    public struct Counts: Equatable, Sendable {
        public var earlyBirdDays: Int
        public var nightFinisherDays: Int
        public init(earlyBirdDays: Int = 0, nightFinisherDays: Int = 0) {
            self.earlyBirdDays = earlyBirdDays
            self.nightFinisherDays = nightFinisherDays
        }
    }

    /// - Parameter finishedAt: for each complete day, when its last main task was completed.
    /// Days without computable prayer times (no location) are skipped.
    public static func counts(
        finishedAt: [DayKey: Date],
        provider: PrayerTimeProviding?,
        calendar: Calendar
    ) -> Counts {
        guard let provider else { return Counts() }
        var result = Counts()
        for (day, finished) in finishedAt {
            guard let times = provider.times(for: day, calendar: calendar) else { continue }
            if let dhuhr = times[.dhuhr], finished < dhuhr { result.earlyBirdDays += 1 }
            if let isha = times[.isha], finished > isha { result.nightFinisherDays += 1 }
        }
        return result
    }
}
