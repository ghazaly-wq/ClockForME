import Foundation
import HabitCore
import SwiftData
import UniformTypeIdentifiers
import SwiftUI

/// A backup file for `fileExporter`.
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension SettingsKey {
    static let autoBackupEnabled = "autoBackupEnabled"
    static let lastBackupAt = "lastBackupAt"
    static let signatureReminderEnabled = "signatureReminderEnabled"
}

/// Turns SwiftData records into a `BackupDocument` and back. All the rules (versioning, validation,
/// pruning) live in HabitCore; this file only moves data between the database and that value type.
@MainActor
enum BackupService {
    /// Settings that go into a backup (shop picks, prayer location, display options...). The alarm sound is a
    /// file in Library/Sounds and is not backed up.
    static let settingKeys: [String] = [
        SettingsKey.appearance, SettingsKey.digitStyle, SettingsKey.dayStartHour,
        SettingsKey.hasPrayerLocation, SettingsKey.prayerLatitude, SettingsKey.prayerLongitude, SettingsKey.prayerPlaceName,
        SettingsKey.equippedTheme, SettingsKey.equippedFrame, SettingsKey.equippedEffect,
        SettingsKey.equippedLiveStyle, SettingsKey.equippedIcon,
        SettingsKey.liveActivityEnabled, SettingsKey.liveActivityAutoStart,
        SettingsKey.morningEnabled, SettingsKey.morningHour, SettingsKey.morningMinute,
        SettingsKey.taskShowAllTimes, SettingsKey.taskFollowsNextRing, SettingsKey.appBlockEnabled,
        SettingsKey.soundEffectsEnabled
    ]

    private static let backupsFolderName = "Backups"
    private static let keepCount = 4

    // MARK: - Build a document

    static func makeDocument(context: ModelContext) throws -> BackupDocument {
        let tasks = try context.fetch(FetchDescriptor<TaskRecord>()).map { (t: TaskRecord) -> BackupTask in
            BackupTask(
                id: t.id, title: t.title, kindRaw: t.kindRaw, repetitionData: t.repetitionData, startDayISO: t.startDayISO,
                endDayISO: t.endDayISO, notes: t.notes, createdAt: t.createdAt, sortOrder: t.sortOrder, alarmID: t.alarmID,
                timeData: t.timeData, pageID: t.pageID, routineEndISO: t.routineEndISO, extraPrayersData: t.extraPrayersData,
                blocksApps: t.blocksApps ? true : nil
            )
        }
        let completions = try context.fetch(FetchDescriptor<CompletionRecord>()).map { (c: CompletionRecord) -> BackupCompletion in
            BackupCompletion(id: c.id, taskID: c.taskID, dayISO: c.dayISO, completedAt: c.completedAt)
        }
        let alarms = try context.fetch(FetchDescriptor<AlarmRecord>()).map { (a: AlarmRecord) -> BackupAlarm in
            BackupAlarm(
                id: a.id, title: a.title, note: a.note, isEnabled: a.isEnabled, repetitionData: a.repetitionData,
                timeData: a.timeData, isMainTask: a.isMainTask, createdAt: a.createdAt, linkedPageID: a.linkedPageID,
                extraPrayersData: a.extraPrayersData, endDayISO: a.endDayISO, deliveryRaw: a.deliveryRaw,
                challengeData: a.challengeData, destinationData: a.destinationData
            )
        }
        let pages = try context.fetch(FetchDescriptor<PageRecord>()).map { (p: PageRecord) -> BackupPage in
            BackupPage(id: p.id, definitionData: p.definitionData, createdAt: p.createdAt, sortOrder: p.sortOrder, isTemplate: p.isTemplate)
        }
        let sessions = try context.fetch(FetchDescriptor<PageSessionRecord>()).map { (s: PageSessionRecord) -> BackupPageSession in
            BackupPageSession(
                id: s.id, pageID: s.pageID, tabID: s.tabID, dayISO: s.dayISO, startedAt: s.startedAt,
                isFinished: s.isFinished, sessionData: s.sessionData
            )
        }
        let unlocks = try context.fetch(FetchDescriptor<AchievementUnlockRecord>()).map { (u: AchievementUnlockRecord) -> BackupUnlock in
            BackupUnlock(achievementID: u.achievementID, unlockedAt: u.unlockedAt)
        }
        let purchases = try context.fetch(FetchDescriptor<PurchaseRecord>()).map { (p: PurchaseRecord) -> BackupPurchase in
            BackupPurchase(itemID: p.itemID, price: p.price, purchasedAt: p.purchasedAt)
        }
        let rewards = try context.fetch(FetchDescriptor<RewardRecord>()).map { (r: RewardRecord) -> BackupReward in
            BackupReward(
                id: r.id, title: r.title, note: r.note, kindRaw: r.kindRaw, target: r.target, achievementID: r.achievementID,
                createdAt: r.createdAt, claimedAt: r.claimedAt, claimedCost: r.claimedCost
            )
        }
        return BackupDocument(
            createdAt: Date(), appVersion: versionText(), tasks: tasks, completions: completions, alarms: alarms,
            pages: pages, pageSessions: sessions, unlocks: unlocks, purchases: purchases, rewards: rewards,
            settings: readSettings(), images: readImages()
        )
    }

    static func encodedBackup(context: ModelContext) throws -> Data {
        try BackupCoding.encode(try makeDocument(context: context))
    }

    // MARK: - Restore

    /// Replaces everything in the database (and the page images and the backed-up settings) with the document.
    static func restore(_ document: BackupDocument, context: ModelContext) throws {
        try BackupCoding.validate(document)
        try deleteEverything(context: context)

        for t in document.tasks {
            let record = TaskRecord(
                id: t.id, title: t.title, kind: TaskKind(rawValue: t.kindRaw) ?? .main, repetition: nil,
                startDay: DayKey(isoString: t.startDayISO) ?? DayKey(year: 1970, month: 1, day: 1),
                notes: t.notes, createdAt: t.createdAt, sortOrder: t.sortOrder
            )
            record.repetitionData = t.repetitionData
            record.endDayISO = t.endDayISO
            record.alarmID = t.alarmID
            record.timeData = t.timeData
            record.pageID = t.pageID
            record.routineEndISO = t.routineEndISO
            record.extraPrayersData = t.extraPrayersData
            record.blocksApps = t.blocksApps ?? false
            context.insert(record)
        }
        for c in document.completions {
            let record = CompletionRecord(
                id: c.id, taskID: c.taskID, day: DayKey(isoString: c.dayISO) ?? DayKey(year: 1970, month: 1, day: 1),
                completedAt: c.completedAt
            )
            context.insert(record)
        }
        for a in document.alarms {
            let rule = AlarmRule(id: a.id, title: a.title, note: a.note, isEnabled: a.isEnabled, repetition: .daily, time: .clock(hour: 7, minute: 0), isMainTask: a.isMainTask)
            let record = AlarmRecord(rule: rule, createdAt: a.createdAt)
            record.repetitionData = a.repetitionData
            record.timeData = a.timeData
            record.linkedPageID = a.linkedPageID
            record.extraPrayersData = a.extraPrayersData
            record.endDayISO = a.endDayISO
            record.deliveryRaw = a.deliveryRaw
            record.challengeData = a.challengeData
            record.destinationData = a.destinationData
            context.insert(record)
        }
        for p in document.pages {
            let fallback = PageDefinition(id: p.id, name: "صفحة", tabs: [PageTab(name: "الرئيسية")])
            let record = PageRecord(definition: fallback, createdAt: p.createdAt, sortOrder: p.sortOrder, isTemplate: p.isTemplate)
            record.definitionData = p.definitionData
            context.insert(record)
        }
        for s in document.pageSessions {
            guard let session = try? JSONDecoder().decode(PageSession.self, from: s.sessionData) else { continue }
            let record = PageSessionRecord(session: session)
            record.id = s.id
            record.pageID = s.pageID
            record.tabID = s.tabID
            record.dayISO = s.dayISO
            record.startedAt = s.startedAt
            record.isFinished = s.isFinished
            record.sessionData = s.sessionData
            context.insert(record)
        }
        for u in document.unlocks { context.insert(AchievementUnlockRecord(achievementID: u.achievementID, unlockedAt: u.unlockedAt)) }
        for p in document.purchases { context.insert(PurchaseRecord(itemID: p.itemID, price: p.price, purchasedAt: p.purchasedAt)) }
        for r in document.rewards {
            let record = RewardRecord(
                id: r.id, title: r.title, note: r.note, kind: RewardKind(rawValue: r.kindRaw) ?? .level,
                target: r.target, achievementID: r.achievementID, createdAt: r.createdAt
            )
            record.claimedAt = r.claimedAt
            record.claimedCost = r.claimedCost
            context.insert(record)
        }
        try context.save()

        writeImages(document.images)
        applySettings(document.settings)
    }

    // MARK: - Reset

    /// Deletes all data and puts the settings back to their defaults.
    static func resetAll(context: ModelContext) throws {
        try deleteEverything(context: context)
        try context.save()
        clearImages()
        let defaults = UserDefaults.standard
        for key in settingKeys + [SettingsKey.alarmSound, SettingsKey.autoBackupEnabled, SettingsKey.lastBackupAt, SettingsKey.signatureReminderEnabled] {
            defaults.removeObject(forKey: key)
        }
        AppIconSwitcher.apply(shopID: ShopCatalog.defaultIcon)
    }

    private static func deleteEverything(context: ModelContext) throws {
        try context.delete(model: TaskRecord.self)
        try context.delete(model: CompletionRecord.self)
        try context.delete(model: AlarmRecord.self)
        try context.delete(model: PageRecord.self)
        try context.delete(model: PageSessionRecord.self)
        try context.delete(model: AchievementUnlockRecord.self)
        try context.delete(model: PurchaseRecord.self)
        try context.delete(model: RewardRecord.self)
    }

    // MARK: - Automatic backups (Documents/Backups, visible in the Files app)

    static var backupsFolder: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent(backupsFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Saved copies inside the app, newest first.
    static func internalBackups() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: backupsFolder, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.lastPathComponent.hasPrefix("habits-backup-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// Writes today's copy (replacing an earlier one from the same day) and keeps only the newest four.
    /// Returns `false` when there is nothing worth saving yet.
    @discardableResult
    static func saveInternalBackup(context: ModelContext, now: Date = Date()) -> Bool {
        guard let document = try? makeDocument(context: context) else { return false }
        if document.tasks.isEmpty, document.alarms.isEmpty, document.pages.isEmpty { return false }
        guard let data = try? BackupCoding.encode(document) else { return false }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let name = "habits-backup-\(formatter.string(from: now)).json"
        do {
            try data.write(to: backupsFolder.appendingPathComponent(name), options: .atomic)
        } catch {
            return false
        }
        let names = internalBackups().map(\.lastPathComponent)
        for old in BackupCoding.filesToPrune(names, keep: keepCount) {
            try? FileManager.default.removeItem(at: backupsFolder.appendingPathComponent(old))
        }
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: SettingsKey.lastBackupAt)
        return true
    }

    /// Called on launch / foreground: a weekly copy when the owner left it on.
    static func runAutoBackupIfDue(context: ModelContext, now: Date = Date()) {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: SettingsKey.autoBackupEnabled) as? Bool ?? true
        guard enabled else { return }
        let last = defaults.double(forKey: SettingsKey.lastBackupAt)
        let lastDate: Date? = last > 0 ? Date(timeIntervalSince1970: last) : nil
        guard BackupCoding.isAutoBackupDue(last: lastDate, now: now) else { return }
        saveInternalBackup(context: context, now: now)
    }

    // MARK: - Settings

    private static func readSettings() -> [String: BackupSettingValue] {
        let defaults = UserDefaults.standard
        var result: [String: BackupSettingValue] = [:]
        for key in settingKeys {
            guard let object = defaults.object(forKey: key) else { continue }
            if let text = object as? String {
                result[key] = .string(text)
            } else if let number = object as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() {
                    result[key] = .bool(number.boolValue)
                } else if CFNumberIsFloatType(number) {
                    result[key] = .double(number.doubleValue)
                } else {
                    result[key] = .int(number.intValue)
                }
            }
        }
        return result
    }

    private static func applySettings(_ settings: [String: BackupSettingValue]) {
        let defaults = UserDefaults.standard
        for key in settingKeys {
            guard let value = settings[key] else {
                defaults.removeObject(forKey: key)
                continue
            }
            switch value {
            case .bool(let flag): defaults.set(flag, forKey: key)
            case .int(let number): defaults.set(number, forKey: key)
            case .double(let number): defaults.set(number, forKey: key)
            case .string(let text): defaults.set(text, forKey: key)
            }
        }
    }

    // MARK: - Page images

    private static func readImages() -> [String: Data] {
        let folder = PageImageStore.folder
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        var result: [String: Data] = [:]
        for name in names {
            if let data = try? Data(contentsOf: folder.appendingPathComponent(name)) { result[name] = data }
        }
        return result
    }

    private static func clearImages() {
        let folder = PageImageStore.folder
        for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    private static func writeImages(_ images: [String: Data]) {
        clearImages()
        let folder = PageImageStore.folder
        for (name, data) in images {
            // Names come from a file the owner picked: never let one point outside the images folder.
            guard !name.contains("/"), !name.contains("..") else { continue }
            try? data.write(to: folder.appendingPathComponent(name), options: .atomic)
        }
    }

    // MARK: - Misc

    static func versionText() -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
