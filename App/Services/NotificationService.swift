import Foundation
import HabitCore
import UserNotifications

/// Identifiers shared between planning, categories and the notification delegate.
enum NotificationIDs {
    static let categoryPlain = "alarm.plain"
    static let categoryTask = "alarm.task"
    static let actionDone = "alarm.done"
    static let actionSnooze = "alarm.snooze"
    static let alarmPrefix = "alarm."
    static let snoozePrefix = "snooze."
    static let snoozeSeconds: TimeInterval = 600
}

/// Talks to the system notification center. Free-account rules: local notifications only,
/// at most 64 pending, so we keep a rolling window and re-plan often.
enum NotificationService {
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func isAllowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    /// Asks the first time only; afterwards just reports the current state.
    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await authorizationStatus()
        if status == .notDetermined {
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
        return isAllowed(status)
    }

    static func registerCategories(digits: DigitStyle) {
        let done = UNNotificationAction(identifier: NotificationIDs.actionDone, title: "تم ✓", options: [])
        let snooze = UNNotificationAction(
            identifier: NotificationIDs.actionSnooze,
            title: digits.format("تأجيل 10 دقائق"),
            options: []
        )
        let plain = UNNotificationCategory(identifier: NotificationIDs.categoryPlain, actions: [snooze], intentIdentifiers: [])
        let task = UNNotificationCategory(identifier: NotificationIDs.categoryTask, actions: [done, snooze], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([plain, task])
    }

    /// Makes the system's pending list match what the planner wants: removes stale
    /// notifications, adds missing ones, leaves unchanged ones alone.
    static func replan(alarms: [AlarmRule], location: PrayerLocation?, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let pendingAlarm = pending.filter { $0.identifier.hasPrefix(NotificationIDs.alarmPrefix) }

        guard isAllowed(await authorizationStatus()) else {
            center.removePendingNotificationRequests(withIdentifiers: pendingAlarm.map(\.identifier))
            return
        }

        let snoozeCount = pending.filter { $0.identifier.hasPrefix(NotificationIDs.snoozePrefix) }.count
        let calendar = Calendar.app
        let plan = NotificationPlanner.plan(
            alarms: alarms,
            from: now,
            limit: max(0, NotificationPlanner.defaultLimit - snoozeCount),
            provider: location?.provider,
            calendar: calendar
        )
        let rules = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var wanted: [String: (PlannedNotification, AlarmRule)] = [:]
        for item in plan {
            if let rule = rules[item.alarmID] { wanted[item.identifier] = (item, rule) }
        }

        var existing: [String: String] = [:]   // identifier -> fingerprint
        for request in pendingAlarm {
            existing[request.identifier] = request.content.userInfo["fp"] as? String ?? ""
        }

        let stale = existing.filter { id, fp in
            guard let (_, rule) = wanted[id] else { return true }
            return fp != fingerprint(of: rule)
        }.map(\.key)
        if !stale.isEmpty { center.removePendingNotificationRequests(withIdentifiers: stale) }

        let kept = Set(existing.keys).subtracting(stale)
        for (id, entry) in wanted.sorted(by: { $0.value.0.fireDate < $1.value.0.fireDate }) where !kept.contains(id) {
            let (item, rule) = entry
            let content = UNMutableNotificationContent()
            content.title = rule.title
            content.body = rule.note
            content.sound = .default
            content.categoryIdentifier = rule.isMainTask ? NotificationIDs.categoryTask : NotificationIDs.categoryPlain
            content.userInfo = ["alarmID": rule.id.uuidString, "fp": fingerprint(of: rule)]
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    /// Rings again after 10 minutes with the same text and buttons.
    static func snooze(alarmID: String, title: String, body: String, category: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = ["alarmID": alarmID, "fp": "snooze"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: NotificationIDs.snoozeSeconds, repeats: false)
        let id = "\(NotificationIDs.snoozePrefix)\(alarmID).\(Int(Date().timeIntervalSince1970))"
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private static func fingerprint(of rule: AlarmRule) -> String {
        "\(rule.title)|\(rule.note)|\(rule.isMainTask)"
    }
}
