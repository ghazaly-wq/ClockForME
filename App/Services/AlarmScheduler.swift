import AlarmKit
import AppIntents
import CryptoKit
import Foundation
import HabitCore
import SwiftUI

/// Runs when the stop button is pressed: stops the alarm and opens the app
/// (on the Tasks page for main-task alarms, otherwise on the Alarms page).
struct OpenHabitsIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "فتح التطبيق"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "tasks")
    var showTasks: Bool

    @Parameter(title: "page")
    var pageID: String

    init() {}

    init(showTasks: Bool, pageID: String = "") {
        self.showTasks = showTasks
        self.pageID = pageID
    }

    func perform() async throws -> some IntentResult {
        let tasks = showTasks
        let page = UUID(uuidString: pageID)
        await MainActor.run {
            let router = AppEnvironment.shared.router
            if let page {
                router.openPageID = page
                router.selectedTab = .pages
            } else {
                router.selectedTab = tasks ? .tasks : .alarms
            }
            // The app then checks whether this ring has a challenge or a destination waiting.
            router.alarmStoppedAt = Date()
        }
        return .result()
    }
}

/// Talks to AlarmKit (iOS 26): real alarms that cover the screen and ring, even in Silent mode.
/// We schedule one-time alarms for the next days and rebuild the window often, so prayer-based
/// alarms follow each day's prayer time.
enum AlarmScheduler {
    static let snoozeSeconds: TimeInterval = 600
    static let defaultLimit = 60

    static var authorizationState: AlarmManager.AuthorizationState {
        AlarmManager.shared.authorizationState
    }

    /// Asks the first time only (when the first alarm is saved). Returns whether alarms are allowed.
    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined {
            return ((try? await manager.requestAuthorization()) ?? .denied) == .authorized
        }
        return manager.authorizationState == .authorized
    }

    // Remembers which of our alarms each AlarmKit alarm belongs to (AlarmKit ids are derived hashes).
    private static let mapKey = "alarmKitRuleMap"

    private static func loadMap() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: mapKey) as? [String: String] ?? [:]
    }

    // Remembers which ring (occurrence) of a challenge alarm each AlarmKit alarm belongs to: the main one and its chain.
    private static let occurrenceMapKey = "alarmKitOccurrenceMap"
    private static let ledgerKey = "challengeLedger"
    private static let ledgerLock = NSLock()

    private static func loadOccurrenceMap() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: occurrenceMapKey) as? [String: String] ?? [:]
    }

    /// The rings of challenge alarms that wait for their challenge, and the ones already done.
    static func challengeLedger() -> ChallengeLedger {
        ledgerLock.lock()
        defer { ledgerLock.unlock() }
        return readLedger()
    }

    private static func readLedger() -> ChallengeLedger {
        guard let data = UserDefaults.standard.data(forKey: ledgerKey),
              let ledger = try? JSONDecoder().decode(ChallengeLedger.self, from: data) else { return ChallengeLedger() }
        return ledger
    }

    private static func changeLedger(_ body: (inout ChallengeLedger) -> Void) {
        ledgerLock.lock()
        defer { ledgerLock.unlock() }
        var ledger = readLedger()
        body(&ledger)
        if let data = try? JSONEncoder().encode(ledger) { UserDefaults.standard.set(data, forKey: ledgerKey) }
    }

    /// The challenge was done: remember it, stop the ring that may still be sounding and cancel the rest of the chain.
    static func completeChallenge(occurrence: String) {
        changeLedger { $0.complete(occurrence) }
        let manager = AlarmManager.shared
        for (kitID, owner) in loadOccurrenceMap() where owner == occurrence {
            guard let id = UUID(uuidString: kitID) else { continue }
            try? manager.stop(id: id)
            try? manager.cancel(id: id)
        }
    }

    /// Stops and removes everything AlarmKit holds for one alarm, including a snoozed (counting down) one.
    static func cancelAll(forRule ruleID: UUID) {
        let manager = AlarmManager.shared
        let map = loadMap()
        for (kitID, rule) in map where rule == ruleID.uuidString {
            if let id = UUID(uuidString: kitID) { try? manager.cancel(id: id) }
        }
    }

    /// Makes AlarmKit's scheduled alarms match the plan: cancels stale ones, adds missing ones.
    /// Alarms that are ringing, snoozed or paused are never touched.
    static func replan(alarms: [AlarmRule], location: PrayerLocation?, completed: Set<String> = [], now: Date = Date()) async {
        let manager = AlarmManager.shared
        guard manager.authorizationState == .authorized else { return }

        let plan = NotificationPlanner.plan(
            alarms: alarms,
            from: now.addingTimeInterval(5),
            limit: defaultLimit,
            provider: location?.provider,
            calendar: Calendar.app,
            skipping: completed
        )
        let rules = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // One AlarmKit alarm we want: a normal ring, or one of the extra rings that follow a challenge alarm.
        var wanted: [UUID: Wanted] = [:]
        for item in plan {
            guard let rule = rules[item.alarmID] else { continue }
            wanted[stableID(item.identifier, fingerprint(of: rule))] = Wanted(
                fireDate: item.fireDate, rule: rule,
                occurrence: rule.usesStopOverride ? item.identifier : nil, isChain: false
            )
        }

        // Challenge alarms keep ringing every minute after the main ring until the challenge is done.
        // Only the next couple of rings of each alarm get their chain, to stay far from the system's limit.
        var plannedEntries: [ChallengeLedger.Entry] = []
        var perRule: [UUID: Int] = [:]
        for item in plan {
            guard let rule = rules[item.alarmID], rule.usesStopOverride,
                  perRule[rule.id, default: 0] < ChallengeChain.plannedOccurrences else { continue }
            perRule[rule.id, default: 0] += 1
            plannedEntries.append(ChallengeLedger.Entry(key: item.identifier, alarmID: rule.id, fireDate: item.fireDate))
        }
        var ledger = ChallengeLedger()
        changeLedger {
            $0.reconcile(planned: plannedEntries, now: now)
            ledger = $0
        }
        for entry in ledger.entries where !ledger.isCompleted(entry.key) {
            guard let rule = rules[entry.alarmID], rule.hasChallenge else { continue }
            for followUp in ChallengeChain.followUps(after: entry.fireDate) where followUp.date > now.addingTimeInterval(5) {
                let identifier = ChallengeChain.identifier(occurrence: entry.key, index: followUp.index)
                wanted[stableID(identifier, fingerprint(of: rule))] = Wanted(
                    fireDate: followUp.date, rule: rule, occurrence: entry.key, isChain: true
                )
            }
        }

        let existing = (try? manager.alarms) ?? []
        let knownRules = Set(alarms.map { $0.id.uuidString })
        var map = loadMap()
        for alarm in existing where wanted[alarm.id] == nil {
            if alarm.state == .scheduled {
                try? manager.cancel(id: alarm.id)
            } else if let owner = map[alarm.id.uuidString], !knownRules.contains(owner) {
                // A snoozed or paused alarm whose alarm was deleted.
                try? manager.cancel(id: alarm.id)
            }
        }
        var occurrences = loadOccurrenceMap()
        for (id, entry) in wanted {
            map[id.uuidString] = entry.rule.id.uuidString
            if let occurrence = entry.occurrence { occurrences[id.uuidString] = occurrence }
        }
        let live = Set(existing.map { $0.id.uuidString }).union(wanted.keys.map(\.uuidString))
        map = map.filter { live.contains($0.key) }
        occurrences = occurrences.filter { live.contains($0.key) }
        UserDefaults.standard.set(map, forKey: mapKey)
        UserDefaults.standard.set(occurrences, forKey: occurrenceMapKey)

        // The next two days and every extra ring of a chain go in first, so a crowded plan can't push them out.
        let horizon = now.addingTimeInterval(48 * 3600)
        func tier(_ entry: Wanted) -> Int { entry.isChain || entry.fireDate <= horizon ? 0 : 1 }
        let existingIDs = Set(existing.map(\.id))
        let missing = wanted.filter { !existingIDs.contains($0.key) }
            .sorted { (tier($0.value), $0.value.fireDate) < (tier($1.value), $1.value.fireDate) }
        // When the system's limit is hit, far-away rings are dropped to make room for the near ones (replan brings them back later).
        var victims = existing
            .filter { $0.state == .scheduled }
            .compactMap { alarm -> (id: UUID, date: Date)? in
                guard let entry = wanted[alarm.id], tier(entry) == 1 else { return nil }
                return (alarm.id, entry.fireDate)
            }
            .sorted { $0.date > $1.date }
        var report = AlarmScheduleReport(
            date: now, wanted: wanted.count, alreadyScheduled: wanted.keys.filter { existingIDs.contains($0) }.count,
            chainWanted: wanted.values.filter(\.isChain).count
        )
        scheduling: for (id, entry) in missing {
            var classic = false
            var freed = 0
            while true {
                do {
                    _ = try await manager.schedule(
                        id: id, configuration: configuration(for: entry.rule, fireDate: entry.fireDate, classic: classic)
                    )
                    report.scheduledNow += 1
                    if entry.isChain { report.chainScheduledNow += 1 }
                    break
                } catch {
                    if case AlarmManager.AlarmError.maximumLimitReached = error {
                        if tier(entry) == 0, freed < 20, let victim = victims.first {
                            victims.removeFirst()
                            try? manager.cancel(id: victim.id)
                            freed += 1
                            report.droppedForRoom += 1
                            continue
                        }
                        report.limitReached = true
                        break scheduling
                    }
                    report.failures.append(String(describing: error))
                    if entry.rule.hasChallenge, !classic {
                        // The system refused the challenge version: ring as a plain alarm rather than not at all.
                        classic = true
                        report.fellBackToClassic += 1
                        continue
                    }
                    break
                }
            }
        }
        saveReport(report)
    }

    // MARK: - What happened (for the diagnostics screen)

    private static let reportKey = "alarmScheduleReport"

    private static func saveReport(_ report: AlarmScheduleReport) {
        if let data = try? JSONEncoder().encode(report) { UserDefaults.standard.set(data, forKey: reportKey) }
    }

    static func lastReport() -> AlarmScheduleReport? {
        UserDefaults.standard.data(forKey: reportKey).flatMap { try? JSONDecoder().decode(AlarmScheduleReport.self, from: $0) }
    }

    /// Which AlarmKit alarms belong to a challenge ring (the main ring or one of its extra rings).
    static func occurrenceOwner(of kitID: UUID) -> String? {
        loadOccurrenceMap()[kitID.uuidString]
    }

    // MARK: - Building one alarm

    private struct Wanted {
        let fireDate: Date
        let rule: AlarmRule
        /// The ring this alarm belongs to when the rule has a challenge or a destination.
        let occurrence: String?
        let isChain: Bool
    }

    /// `classic` builds the plain alarm (with snooze) even for a challenge alarm: the fallback when the system
    /// refuses the challenge version, so the alarm always rings.
    private static func configuration(
        for rule: AlarmRule, fireDate: Date, classic: Bool = false
    ) -> AlarmManager.AlarmConfiguration<HabitAlarmMetadata> {
        let title = LocalizedStringResource(stringLiteral: rule.title)
        // A challenge alarm has no snooze: the chain rings again every minute until the challenge is done.
        let noSnooze = rule.hasChallenge && !classic
        let snooze = AlarmButton(text: "تأجيل 10 دقائق", textColor: .white, systemImageName: "bell.slash")
        let alert = noSnooze
            ? AlarmPresentation.Alert(title: title, secondaryButton: nil, secondaryButtonBehavior: nil)
            : AlarmPresentation.Alert(title: title, secondaryButton: snooze, secondaryButtonBehavior: .countdown)
        // Shown while a snoozed alarm counts down.
        let countdown = AlarmPresentation.Countdown(
            title: title,
            pauseButton: AlarmButton(text: "إيقاف مؤقت", textColor: .white, systemImageName: "pause.fill")
        )
        let paused = AlarmPresentation.Paused(
            title: "متوقف",
            resumeButton: AlarmButton(text: "متابعة", textColor: .white, systemImageName: "play.fill")
        )
        let attributes = AlarmAttributes<HabitAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert, countdown: countdown, paused: paused),
            metadata: HabitAlarmMetadata(alarmID: rule.id.uuidString),
            tintColor: Color(red: 0.07, green: 0.66, blue: 0.42)
        )
        return AlarmManager.AlarmConfiguration(
            countdownDuration: noSnooze ? nil : Alarm.CountdownDuration(preAlert: nil, postAlert: snoozeSeconds),
            schedule: .fixed(fireDate),
            attributes: attributes,
            stopIntent: OpenHabitsIntent(showTasks: rule.isMainTask, pageID: rule.linkedPageID?.uuidString ?? ""),
            secondaryIntent: nil,
            sound: AlarmSoundStore.alertSound
        )
    }

    private static func fingerprint(of rule: AlarmRule) -> String {
        "\(rule.title)|\(rule.isMainTask)|\(rule.linkedPageID?.uuidString ?? "")|\(AlarmSoundStore.selectedName)|\(rule.stopOverrideFingerprint)"
    }

    /// The same alarm moment + same text always gives the same id, so re-planning is a cheap diff.
    private static func stableID(_ identifier: String, _ fingerprint: String) -> UUID {
        let hash = SHA256.hash(data: Data((identifier + "#" + fingerprint).utf8))
        var bytes = Array(hash.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50   // version 5 style
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

/// What the last re-plan did, shown in the diagnostics screen so a problem can be seen instead of guessed.
struct AlarmScheduleReport: Codable {
    var date: Date
    var wanted: Int
    var alreadyScheduled: Int
    var chainWanted: Int
    var scheduledNow = 0
    var chainScheduledNow = 0
    var droppedForRoom = 0
    var fellBackToClassic = 0
    var limitReached = false
    var failures: [String] = []
}
