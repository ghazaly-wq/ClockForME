import Foundation

/// A setting value stored in a backup (UserDefaults holds bools, numbers and strings).
public enum BackupSettingValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Int.self) { self = .int(value); return }
        if let value = try? container.decode(Double.self) { self = .double(value); return }
        self = .string(try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        }
    }
}

/// One row of each stored table. Nested JSON blobs (repetition, time, page definition, session) are kept as
/// the raw `Data` the app already stores, so a backup can never lose a field the app adds later.
public struct BackupTask: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var kindRaw: String
    public var repetitionData: Data?
    public var startDayISO: String
    public var endDayISO: String?
    public var notes: String
    public var createdAt: Date
    public var sortOrder: Int
    public var alarmID: UUID?
    public var timeData: Data?
    public var pageID: UUID?
    public var routineEndISO: String?
    public var extraPrayersData: Data?

    public init(
        id: UUID, title: String, kindRaw: String, repetitionData: Data?, startDayISO: String, endDayISO: String?,
        notes: String, createdAt: Date, sortOrder: Int, alarmID: UUID?, timeData: Data?, pageID: UUID?,
        routineEndISO: String?, extraPrayersData: Data?
    ) {
        self.id = id; self.title = title; self.kindRaw = kindRaw; self.repetitionData = repetitionData
        self.startDayISO = startDayISO; self.endDayISO = endDayISO; self.notes = notes; self.createdAt = createdAt
        self.sortOrder = sortOrder; self.alarmID = alarmID; self.timeData = timeData; self.pageID = pageID
        self.routineEndISO = routineEndISO; self.extraPrayersData = extraPrayersData
    }
}

public struct BackupCompletion: Codable, Equatable, Sendable {
    public var id: UUID
    public var taskID: UUID
    public var dayISO: String
    public var completedAt: Date

    public init(id: UUID, taskID: UUID, dayISO: String, completedAt: Date) {
        self.id = id; self.taskID = taskID; self.dayISO = dayISO; self.completedAt = completedAt
    }
}

public struct BackupAlarm: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var note: String
    public var isEnabled: Bool
    public var repetitionData: Data
    public var timeData: Data
    public var isMainTask: Bool
    public var createdAt: Date
    public var linkedPageID: UUID?
    public var extraPrayersData: Data?
    public var endDayISO: String?
    public var deliveryRaw: String?
    /// JSON of `AlarmChallenge` (nil = no challenge). Absent in backups made before challenges existed.
    public var challengeData: Data?
    /// JSON of `StopDestination` (nil = this app). Absent in older backups.
    public var destinationData: Data?

    public init(
        id: UUID, title: String, note: String, isEnabled: Bool, repetitionData: Data, timeData: Data,
        isMainTask: Bool, createdAt: Date, linkedPageID: UUID?, extraPrayersData: Data?, endDayISO: String?,
        deliveryRaw: String?, challengeData: Data? = nil, destinationData: Data? = nil
    ) {
        self.id = id; self.title = title; self.note = note; self.isEnabled = isEnabled
        self.repetitionData = repetitionData; self.timeData = timeData; self.isMainTask = isMainTask
        self.createdAt = createdAt; self.linkedPageID = linkedPageID; self.extraPrayersData = extraPrayersData
        self.endDayISO = endDayISO; self.deliveryRaw = deliveryRaw
        self.challengeData = challengeData; self.destinationData = destinationData
    }
}

public struct BackupPage: Codable, Equatable, Sendable {
    public var id: UUID
    public var definitionData: Data
    public var createdAt: Date
    public var sortOrder: Int
    public var isTemplate: Bool

    public init(id: UUID, definitionData: Data, createdAt: Date, sortOrder: Int, isTemplate: Bool) {
        self.id = id; self.definitionData = definitionData; self.createdAt = createdAt
        self.sortOrder = sortOrder; self.isTemplate = isTemplate
    }
}

public struct BackupPageSession: Codable, Equatable, Sendable {
    public var id: UUID
    public var pageID: UUID
    public var tabID: UUID
    public var dayISO: String
    public var startedAt: Date
    public var isFinished: Bool
    public var sessionData: Data

    public init(id: UUID, pageID: UUID, tabID: UUID, dayISO: String, startedAt: Date, isFinished: Bool, sessionData: Data) {
        self.id = id; self.pageID = pageID; self.tabID = tabID; self.dayISO = dayISO
        self.startedAt = startedAt; self.isFinished = isFinished; self.sessionData = sessionData
    }
}

public struct BackupUnlock: Codable, Equatable, Sendable {
    public var achievementID: String
    public var unlockedAt: Date

    public init(achievementID: String, unlockedAt: Date) {
        self.achievementID = achievementID; self.unlockedAt = unlockedAt
    }
}

public struct BackupPurchase: Codable, Equatable, Sendable {
    public var itemID: String
    public var price: Int
    public var purchasedAt: Date

    public init(itemID: String, price: Int, purchasedAt: Date) {
        self.itemID = itemID; self.price = price; self.purchasedAt = purchasedAt
    }
}

public struct BackupReward: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var note: String
    public var kindRaw: String
    public var target: Int
    public var achievementID: String
    public var createdAt: Date
    public var claimedAt: Date?
    public var claimedCost: Int

    public init(
        id: UUID, title: String, note: String, kindRaw: String, target: Int, achievementID: String,
        createdAt: Date, claimedAt: Date?, claimedCost: Int
    ) {
        self.id = id; self.title = title; self.note = note; self.kindRaw = kindRaw; self.target = target
        self.achievementID = achievementID; self.createdAt = createdAt; self.claimedAt = claimedAt
        self.claimedCost = claimedCost
    }
}

/// The whole backup file (versioned JSON). Pure data: the app turns its SwiftData records into this and back.
public struct BackupDocument: Codable, Equatable, Sendable {
    /// Bump when the shape changes in a way old readers can't handle. Readers refuse a newer version.
    public static let currentVersion = 1

    public var schemaVersion: Int
    public var createdAt: Date
    public var appVersion: String
    public var tasks: [BackupTask]
    public var completions: [BackupCompletion]
    public var alarms: [BackupAlarm]
    public var pages: [BackupPage]
    public var pageSessions: [BackupPageSession]
    public var unlocks: [BackupUnlock]
    public var purchases: [BackupPurchase]
    public var rewards: [BackupReward]
    public var settings: [String: BackupSettingValue]
    /// Page images by file name (JPEG data).
    public var images: [String: Data]

    public init(
        schemaVersion: Int = BackupDocument.currentVersion, createdAt: Date, appVersion: String,
        tasks: [BackupTask] = [], completions: [BackupCompletion] = [], alarms: [BackupAlarm] = [],
        pages: [BackupPage] = [], pageSessions: [BackupPageSession] = [], unlocks: [BackupUnlock] = [],
        purchases: [BackupPurchase] = [], rewards: [BackupReward] = [],
        settings: [String: BackupSettingValue] = [:], images: [String: Data] = [:]
    ) {
        self.schemaVersion = schemaVersion; self.createdAt = createdAt; self.appVersion = appVersion
        self.tasks = tasks; self.completions = completions; self.alarms = alarms; self.pages = pages
        self.pageSessions = pageSessions; self.unlocks = unlocks; self.purchases = purchases
        self.rewards = rewards; self.settings = settings; self.images = images
    }
}

/// How many of each thing a backup holds (shown before an import replaces everything).
public struct BackupSummary: Equatable, Sendable {
    public var tasks: Int
    public var completions: Int
    public var alarms: Int
    public var pages: Int
    public var sessions: Int
    public var rewards: Int
    public var achievements: Int
}

public enum BackupError: Error, Equatable, Sendable {
    case unreadable
    case newerVersion(found: Int)
    case invalid(String)
}

public enum BackupCoding {
    public static func encode(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(document)
    }

    /// Decodes and validates. Throws `.unreadable` for anything that isn't a backup, `.newerVersion` when the
    /// file came from a newer app, and `.invalid` when the contents contradict themselves.
    public static func decode(_ data: Data) throws -> BackupDocument {
        struct VersionProbe: Decodable { var schemaVersion: Int }
        guard let probe = try? JSONDecoder().decode(VersionProbe.self, from: data) else { throw BackupError.unreadable }
        if probe.schemaVersion > BackupDocument.currentVersion { throw BackupError.newerVersion(found: probe.schemaVersion) }
        if probe.schemaVersion < 1 { throw BackupError.invalid("version") }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(BackupDocument.self, from: data) else { throw BackupError.unreadable }
        try validate(document)
        return document
    }

    public static func validate(_ document: BackupDocument) throws {
        func unique<T: Hashable>(_ values: [T], _ name: String) throws {
            if Set(values).count != values.count { throw BackupError.invalid("duplicate \(name)") }
        }
        try unique(document.tasks.map(\.id), "tasks")
        try unique(document.alarms.map(\.id), "alarms")
        try unique(document.pages.map(\.id), "pages")
        try unique(document.pageSessions.map(\.id), "sessions")
        try unique(document.rewards.map(\.id), "rewards")
        try unique(document.unlocks.map(\.achievementID), "unlocks")
        try unique(document.purchases.map(\.itemID), "purchases")
    }

    public static func summary(of document: BackupDocument) -> BackupSummary {
        BackupSummary(
            tasks: document.tasks.count,
            completions: document.completions.count,
            alarms: document.alarms.count,
            pages: document.pages.filter { !$0.isTemplate }.count,
            sessions: document.pageSessions.count,
            rewards: document.rewards.count,
            achievements: document.unlocks.count
        )
    }

    /// The oldest files to delete so only the newest `keep` remain. Names look like `habits-backup-2026-11-15.json`
    /// (sortable by date). Anything that isn't a backup file is never listed.
    public static func filesToPrune(_ names: [String], keep: Int) -> [String] {
        let backups = names.filter { $0.hasPrefix("habits-backup-") && $0.hasSuffix(".json") }.sorted()
        guard backups.count > keep else { return [] }
        return Array(backups.prefix(backups.count - keep))
    }

    /// Whether a weekly automatic backup is due.
    public static func isAutoBackupDue(last: Date?, now: Date, intervalDays: Int = 7) -> Bool {
        guard let last else { return true }
        return now.timeIntervalSince(last) >= Double(intervalDays) * 86_400
    }
}
