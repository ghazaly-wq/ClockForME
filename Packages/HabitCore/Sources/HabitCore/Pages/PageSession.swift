import Foundation

/// One time the owner used a page: what he typed, when, and in which tab.
public struct PageSession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var pageID: UUID
    public var tabID: UUID
    public var day: DayKey
    public var startedAt: Date
    public var finishedAt: Date?
    /// Values keyed by block id string.
    public var values: [String: BlockValue]

    public init(
        id: UUID = UUID(), pageID: UUID, tabID: UUID, day: DayKey, startedAt: Date = Date(),
        finishedAt: Date? = nil, values: [String: BlockValue] = [:]
    ) {
        self.id = id; self.pageID = pageID; self.tabID = tabID; self.day = day
        self.startedAt = startedAt; self.finishedAt = finishedAt; self.values = values
    }

    public func value(for blockID: UUID) -> BlockValue? { values[blockID.uuidString] }

    public mutating func set(_ value: BlockValue?, for blockID: UUID) {
        values[blockID.uuidString] = value
    }

    public var isFinished: Bool { finishedAt != nil }

    /// True when nothing was typed (an untouched session isn't worth keeping).
    public var hasNoData: Bool { values.values.allSatisfy(\.isEmpty) }
}

public struct SeriesPoint: Equatable, Sendable {
    public let day: DayKey
    public let value: Double
    public init(day: DayKey, value: Double) { self.day = day; self.value = value }
}

public enum PageLogic {
    // MARK: Rotation

    /// Which tab a day uses. With rotation and a schedule, scheduled days cycle through the tabs in order
    /// (Sun → A, Tue → B, Thu → C, next Sun → A …); a day that isn't scheduled gets the next scheduled day's tab.
    /// Without rotation the first tab is used.
    public static func tabIndex(for day: DayKey, page: PageDefinition, calendar: Calendar) -> Int {
        let count = page.tabs.count
        guard count > 1, page.rotatesTabs, let schedule = page.schedule else { return 0 }
        guard day > page.anchorDay else { return 0 }
        var occurrences = 0
        var cursor = page.anchorDay
        var guardCount = 0
        while cursor < day, guardCount < 4000 {
            if schedule.repetition.occurs(on: cursor, calendar: calendar) { occurrences += 1 }
            guard let next = cursor.adding(days: 1, calendar: calendar) else { break }
            cursor = next
            guardCount += 1
        }
        return occurrences % count
    }

    public static func tab(for day: DayKey, page: PageDefinition, calendar: Calendar) -> PageTab? {
        guard !page.tabs.isEmpty else { return nil }
        return page.tabs[tabIndex(for: day, page: page, calendar: calendar)]
    }

    // MARK: History

    /// Finished sessions of a page, oldest first.
    public static func finished(_ sessions: [PageSession], pageID: UUID) -> [PageSession] {
        sessions.filter { $0.pageID == pageID && $0.isFinished }
            .sorted { ($0.day, $0.startedAt) < ($1.day, $1.startedAt) }
    }

    /// The most recent finished value of a block before `session` (for "last time" hints).
    public static func lastValue(of blockID: UUID, in sessions: [PageSession], pageID: UUID, before session: PageSession?) -> BlockValue? {
        let list = finished(sessions, pageID: pageID).filter { $0.id != session?.id }
        let earlier = session.map { s in list.filter { ($0.day, $0.startedAt) < (s.day, s.startedAt) } } ?? list
        for s in earlier.reversed() {
            if let v = s.value(for: blockID), !v.isEmpty { return v }
        }
        return nil
    }

    /// One number per finished session for a block (skips sessions without it).
    public static func series(of blockID: UUID, metric: ChartMetric, in sessions: [PageSession], pageID: UUID) -> [SeriesPoint] {
        finished(sessions, pageID: pageID).compactMap { s in
            guard let v = s.value(for: blockID), let n = metricValue(v, metric: metric) else { return nil }
            return SeriesPoint(day: s.day, value: n)
        }
    }

    public static func metricValue(_ value: BlockValue, metric: ChartMetric) -> Double? {
        switch (metric, value) {
        case (.value, .number(let n)): return n
        case (.value, .duration(let d)): return d
        case (.setsMax, .rows(let rows)):
            let weights = rows.compactMap { $0.values.first ?? nil }
            return weights.max()
        case (.setsVolume, .rows(let rows)):
            let volume = rows.reduce(0.0) { sum, row in
                let w = row.values.indices.contains(0) ? (row.values[0] ?? 0) : 0
                let r = row.values.indices.contains(1) ? (row.values[1] ?? 0) : 0
                return sum + w * r
            }
            return volume > 0 ? volume : nil
        case (.setsTotal, .rows(let rows)):
            let total = rows.reduce(0.0) { $0 + (($1.values.indices.contains(1) ? $1.values[1] : nil) ?? 0) }
            return total > 0 ? total : nil
        default: return nil
        }
    }

    /// Placeholder rows for a sets table: the rows of the last session.
    public static func placeholderRows(from last: BlockValue?) -> [SetRow] {
        if case .rows(let rows)? = last { return rows }
        return []
    }

    /// 0...1 progress of a value toward a target (a missing or zero target gives 0).
    public static func progress(value: Double, target: Double?) -> Double {
        guard let target, target > 0 else { return 0 }
        return min(max(value / target, 0), 1)
    }

    /// The numeric value of a block in a session (counter, number, stopwatch, rating).
    public static func number(of blockID: UUID, in session: PageSession) -> Double {
        session.value(for: blockID)?.asNumber ?? 0
    }

    // MARK: Session helpers

    /// Drops values of blocks that no longer exist (after editing the structure).
    public static func pruned(_ session: PageSession, keeping page: PageDefinition) -> PageSession {
        let valid = Set(page.allBlocks.map { $0.id.uuidString })
        var s = session
        s.values = s.values.filter { valid.contains($0.key) }
        return s
    }

    /// Clears everything typed, keeping the session itself.
    public static func cleared(_ session: PageSession) -> PageSession {
        var s = session
        s.values = [:]
        return s
    }

    // MARK: Scheduling

    /// Does the page have a session on this day?
    public static func isScheduled(_ page: PageDefinition, on day: DayKey, calendar: Calendar) -> Bool {
        page.schedule?.repetition.occurs(on: day, calendar: calendar) ?? false
    }

    /// The alarm for a scheduled page: same title as the page, same schedule and time.
    public static func alarmRule(for page: PageDefinition, existingID: UUID = UUID()) -> AlarmRule? {
        guard let schedule = page.schedule else { return nil }
        return AlarmRule(
            id: existingID, title: page.name, repetition: schedule.repetition, time: schedule.time,
            isMainTask: false, linkedPageID: page.id, extraPrayers: schedule.extraPrayers, endDay: schedule.endDay,
            delivery: schedule.delivery, challenge: schedule.challenge, stopDestination: schedule.stopDestination
        )
    }

    /// The target of a progress bar that follows several numbers: the owner's own target if set,
    /// otherwise the sum of the sources' targets (only when every source has one).
    public static func combinedTarget(explicit: Double?, sourceTargets: [Double?]) -> Double? {
        if let explicit { return explicit }
        guard !sourceTargets.isEmpty, sourceTargets.allSatisfy({ $0 != nil }) else { return nil }
        return sourceTargets.compactMap { $0 }.reduce(0, +)
    }
}
