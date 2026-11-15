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
    static func replan(alarms: [AlarmRule], location: PrayerLocation?, now: Date = Date()) async {
        let manager = AlarmManager.shared
        guard manager.authorizationState == .authorized else { return }

        let plan = NotificationPlanner.plan(
            alarms: alarms,
            from: now.addingTimeInterval(5),
            limit: defaultLimit,
            provider: location?.provider,
            calendar: Calendar.app
        )
        let rules = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var wanted: [UUID: (PlannedNotification, AlarmRule)] = [:]
        for item in plan {
            guard let rule = rules[item.alarmID] else { continue }
            wanted[stableID(item.identifier, fingerprint(of: rule))] = (item, rule)
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
        for (id, entry) in wanted { map[id.uuidString] = entry.1.id.uuidString }
        let live = Set(existing.map { $0.id.uuidString }).union(wanted.keys.map(\.uuidString))
        map = map.filter { live.contains($0.key) }
        UserDefaults.standard.set(map, forKey: mapKey)

        let existingIDs = Set(existing.map(\.id))
        let missing = wanted.filter { !existingIDs.contains($0.key) }
            .sorted { $0.value.0.fireDate < $1.value.0.fireDate }
        for (id, entry) in missing {
            do {
                _ = try await manager.schedule(id: id, configuration: configuration(for: entry.1, fireDate: entry.0.fireDate))
            } catch {
                // Over the system's limit (or a bad date): keep what we have, the nearest ones are in.
                if case AlarmManager.AlarmError.maximumLimitReached = error { break }
            }
        }
    }

    // MARK: - Building one alarm

    private static func configuration(for rule: AlarmRule, fireDate: Date) -> AlarmManager.AlarmConfiguration<HabitAlarmMetadata> {
        let title = LocalizedStringResource(stringLiteral: rule.title)
        let snooze = AlarmButton(text: "تأجيل 10 دقائق", textColor: .white, systemImageName: "bell.slash")
        let alert = AlarmPresentation.Alert(
            title: title,
            secondaryButton: snooze,
            secondaryButtonBehavior: .countdown
        )
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
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: snoozeSeconds),
            schedule: .fixed(fireDate),
            attributes: attributes,
            stopIntent: OpenHabitsIntent(showTasks: rule.isMainTask, pageID: rule.linkedPageID?.uuidString ?? ""),
            secondaryIntent: nil,
            sound: AlarmSoundStore.alertSound
        )
    }

    private static func fingerprint(of rule: AlarmRule) -> String {
        "\(rule.title)|\(rule.isMainTask)|\(rule.linkedPageID?.uuidString ?? "")|\(AlarmSoundStore.selectedName)"
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
