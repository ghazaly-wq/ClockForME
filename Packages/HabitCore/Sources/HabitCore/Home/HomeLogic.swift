import Foundation

// MARK: - Greeting

public enum GreetingKind: Equatable, Sendable {
    case morning, evening
}

public enum Greeting {
    /// "صباح الخير" from 04:00 until noon, "مساء الخير" otherwise.
    public static func kind(at date: Date, calendar: Calendar) -> GreetingKind {
        let hour = calendar.component(.hour, from: date)
        return (4..<12).contains(hour) ? .morning : .evening
    }
}

// MARK: - Next prayer

public struct UpcomingPrayer: Equatable, Sendable {
    public let prayer: Prayer
    public let date: Date

    public init(prayer: Prayer, date: Date) {
        self.prayer = prayer
        self.date = date
    }
}

public enum NextPrayer {
    /// The first prayer after `now`: today's, or tomorrow's Fajr once Isha has passed.
    public static func find(provider: PrayerTimeProviding, now: Date, calendar: Calendar) -> UpcomingPrayer? {
        let today = DayKey(date: now, calendar: calendar)
        var days = [today]
        if let tomorrow = today.adding(days: 1, calendar: calendar) { days.append(tomorrow) }

        for day in days {
            guard let times = provider.times(for: day, calendar: calendar) else { continue }
            let upcoming = Prayer.allCases
                .compactMap { prayer in times[prayer].map { UpcomingPrayer(prayer: prayer, date: $0) } }
                .filter { $0.date > now }
                .min { $0.date < $1.date }
            if let upcoming { return upcoming }
        }
        return nil
    }
}

public enum Countdown {
    /// Whole hours and minutes until `target`, rounded up so "0 minutes" never shows before it happens.
    public static func parts(from now: Date, to target: Date) -> (hours: Int, minutes: Int) {
        let seconds = max(0, target.timeIntervalSince(now))
        let totalMinutes = Int((seconds / 60).rounded(.up))
        return (totalMinutes / 60, totalMinutes % 60)
    }
}

// MARK: - Next main task

public struct TodayTaskItem: Equatable, Sendable {
    public let id: UUID
    public let isDone: Bool
    /// When the task is due today (for tasks made from an alarm); nil = no time.
    /// For a task that follows several prayers this is the earliest one.
    public let time: Date?
    /// Every time the task is due today, sorted (more than one when its alarm follows several prayers).
    public let times: [Date]

    public init(id: UUID, isDone: Bool, time: Date?, times: [Date] = []) {
        self.id = id
        self.isDone = isDone
        self.time = time
        self.times = times.sorted()
    }

    /// The time to rank this task by. Normally the earliest time. With `followsNextRing` a task with
    /// several times moves on to its next ring: the first one that hasn't passed, else the last one.
    public func effectiveTime(now: Date, followsNextRing: Bool) -> Date? {
        guard followsNextRing, times.count > 1 else { return time }
        return times.first(where: { $0 >= now }) ?? times.last
    }
}

public enum NextTaskResult: Equatable, Sendable {
    case task(UUID)
    case allDone
    case noTasks
}

public enum NextMainTask {
    /// The next main task to show: the soonest timed task that hasn't passed yet,
    /// else the first task without a time, else the most overdue timed one.
    /// Done tasks are skipped; all done / nothing scheduled have their own results.
    /// `followsNextRing`: a task with several times is ranked by its next ring instead of its first one.
    public static func pick(_ items: [TodayTaskItem], now: Date, followsNextRing: Bool = false) -> NextTaskResult {
        if items.isEmpty { return .noTasks }
        let open = items.filter { !$0.isDone }
        if open.isEmpty { return .allDone }

        let ranked = open.map { (item: $0, time: $0.effectiveTime(now: now, followsNextRing: followsNextRing)) }

        let upcoming = ranked.filter { ($0.time ?? .distantPast) >= now && $0.time != nil }
            .min { ($0.time ?? .distantFuture) < ($1.time ?? .distantFuture) }
        if let upcoming { return .task(upcoming.item.id) }

        if let untimed = ranked.first(where: { $0.time == nil }) { return .task(untimed.item.id) }

        let overdue = ranked.min { ($0.time ?? .distantFuture) < ($1.time ?? .distantFuture) }
        return overdue.map { .task($0.item.id) } ?? .allDone
    }
}
