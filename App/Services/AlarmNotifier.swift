import Foundation
import HabitCore
import UserNotifications

/// "Notification only" alarms: plain local notifications (a banner and a sound) instead of AlarmKit alarms.
/// Same idea as `AlarmScheduler`: the next occurrences are planned as concrete dates and rebuilt often,
/// so prayer-based times follow each day.
enum AlarmNotifier {
    static let prefix = "com.ghazaly.habits.alarmnote."
    /// iOS keeps at most 64 pending local notifications per app; leave room for reminders and timers.
    static let defaultLimit = 40

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private static func isAllowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    /// Asks the first time only (when a notification-only alarm is saved). Returns whether notifications are allowed.
    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        return isAllowed(status)
    }

    /// Makes the pending notifications match the plan: removes stale ones, (re)adds the wanted ones.
    static func replan(alarms: [AlarmRule], location: PrayerLocation?, completed: Set<String> = [], now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }

        let status = await center.notificationSettings().authorizationStatus
        guard isAllowed(status), !alarms.isEmpty else {
            center.removePendingNotificationRequests(withIdentifiers: ours)
            return
        }

        let plan = NotificationPlanner.plan(
            alarms: alarms,
            from: now.addingTimeInterval(5),
            limit: defaultLimit,
            provider: location?.provider,
            calendar: Calendar.app,
            skipping: completed
        )
        let rules = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var wanted: [UNNotificationRequest] = []
        for item in plan {
            guard let rule = rules[item.alarmID] else { continue }
            let seconds = item.fireDate.timeIntervalSince(Date())
            guard seconds > 1 else { continue }
            wanted.append(request(identifier: prefix + item.identifier, rule: rule, seconds: seconds))
        }

        let wantedIDs = Set(wanted.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: ours.filter { !wantedIDs.contains($0) })
        // Adding with an existing identifier replaces it, so edited titles and notes are picked up.
        for request in wanted { try? await center.add(request) }
    }

    private static func request(identifier: String, rule: AlarmRule, seconds: TimeInterval) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = rule.title
        content.body = rule.note
        content.sound = .default
        content.threadIdentifier = rule.id.uuidString
        content.userInfo = [
            "kind": "alarmnote",
            "showTasks": rule.isMainTask,
            "pageID": rule.linkedPageID?.uuidString ?? ""
        ]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
