import ActivityKit
import Foundation
import Observation
import UserNotifications
import WidgetKit

/// Starts, updates and ends the "today's main tasks" Live Activity, writes the widget snapshot
/// and keeps the local reminders. Everything here runs inside the app: without a paid developer
/// account nothing can update the activity from a server.
@MainActor
@Observable
final class LiveActivityController {
    static let shared = LiveActivityController()

    private(set) var isRunning = false

    private let renewID = "com.ghazaly.habits.liveRenew"
    private let morningID = "com.ghazaly.habits.morning"
    /// Live Activities last about 8 hours; remind a little before that.
    private let renewAfter: TimeInterval = 7 * 3600
    private let restartAfter: TimeInterval = 7.5 * 3600

    private enum Key {
        static let lastStart = "liveActivityLastStart"
        static let stopDay = "liveActivityStopDay"
    }

    private let defaults = UserDefaults.standard

    private init() {
        isRunning = !Activity<TodayActivityAttributes>.activities.isEmpty
    }

    private func flag(_ key: String) -> Bool {
        (defaults.object(forKey: key) as? Bool) ?? true
    }

    // MARK: - Sync

    /// Publishes the snapshot to the widgets and brings the Live Activity in line with it.
    func sync(_ output: WidgetSnapshotBuilder.Output, now: Date) async {
        let snapshot = output.snapshot
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()

        let dayKey = output.dayKey.isoString
        let current = Activity<TodayActivityAttributes>.activities.first

        guard flag(SettingsKey.liveActivityEnabled), snapshot.total > 0 else {
            await endAll()
            return
        }

        if let current {
            if current.attributes.dayKey == dayKey {
                await current.update(ActivityContent(state: state(from: snapshot), staleDate: staleDate(for: snapshot, now: now)))
                isRunning = true
                return
            }
            await current.end(nil, dismissalPolicy: .immediate)
        }

        let lastStart = defaults.object(forKey: Key.lastStart) as? Date
        let sameDay = lastStart.map { Calendar.app.isDate($0, inSameDayAs: now) } ?? false
        let freshEnough = lastStart.map { now.timeIntervalSince($0) < restartAfter } ?? false
        let stoppedToday = defaults.string(forKey: Key.stopDay) == dayKey
        let shouldAutoStart = flag(SettingsKey.liveActivityAutoStart) && !stoppedToday && !(sameDay && freshEnough)

        if shouldAutoStart {
            _ = await start(snapshot, dayKey: dayKey, now: now)
        } else {
            isRunning = false
        }
    }

    // MARK: - Start / stop

    /// "ابدأ يومك": starts it even if auto-start is off or it was stopped earlier today.
    @discardableResult
    func startManually(_ output: WidgetSnapshotBuilder.Output, now: Date) async -> Bool {
        defaults.removeObject(forKey: Key.stopDay)
        output.snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
        if let current = Activity<TodayActivityAttributes>.activities.first {
            await current.end(nil, dismissalPolicy: .immediate)
        }
        return await start(output.snapshot, dayKey: output.dayKey.isoString, now: now)
    }

    /// Stops it for the rest of today (auto-start waits for tomorrow).
    func stopForToday(dayKey: String) async {
        defaults.set(dayKey, forKey: Key.stopDay)
        await endAll()
    }

    private func start(_ snapshot: WidgetSnapshot, dayKey: String, now: Date) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, snapshot.total > 0 else {
            isRunning = false
            return false
        }
        do {
            _ = try Activity.request(
                attributes: TodayActivityAttributes(dayKey: dayKey),
                content: ActivityContent(state: state(from: snapshot), staleDate: staleDate(for: snapshot, now: now)),
                pushType: nil
            )
            defaults.set(now, forKey: Key.lastStart)
            isRunning = true
            await scheduleRenewalReminder()
            return true
        } catch {
            isRunning = false
            return false
        }
    }

    private func endAll() async {
        for activity in Activity<TodayActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [renewID])
        isRunning = false
    }

    // MARK: - Content

    private func state(from snapshot: WidgetSnapshot) -> TodayActivityAttributes.ContentState {
        let next = snapshot.nextItem(at: Date())
        return TodayActivityAttributes.ContentState(
            segments: snapshot.segments,
            nextTitle: next?.title,
            nextTime: next.flatMap { snapshot.effectiveTime(of: $0, at: Date()) },
            arabicDigits: snapshot.arabicDigits,
            styleID: snapshot.styleID,
            themeID: UserDefaults.standard.string(forKey: SettingsKey.equippedTheme)
        )
    }

    /// The activity goes stale when the next timed task is due (its "next task" text is then
    /// out of date until the app runs), or at the end of the day.
    private func staleDate(for snapshot: WidgetSnapshot, now: Date) -> Date {
        if let next = snapshot.nextItem(at: now), let time = snapshot.effectiveTime(of: next, at: now), time > now { return time }
        return max(snapshot.dayEnd, now.addingTimeInterval(60))
    }

    // MARK: - Local notifications

    /// Asks once; returns whether alerts are allowed.
    private func notificationsAllowed() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    /// Reminds the owner to reopen the app before the activity runs out.
    private func scheduleRenewalReminder() async {
        guard await notificationsAllowed() else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [renewID])
        let content = UNMutableNotificationContent()
        content.title = "ينتهي عرض مهماتك قريباً"
        content.body = "افتح التطبيق عشان يتجدد على شاشة القفل."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: renewAfter, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: renewID, content: content, trigger: trigger))
    }

    /// The daily "ابدأ يومك" reminder. Call again whenever its settings change.
    func updateMorningReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morningID])
        guard (defaults.object(forKey: SettingsKey.morningEnabled) as? Bool) ?? false else { return }
        guard await notificationsAllowed() else { return }

        let content = UNMutableNotificationContent()
        content.title = "ابدأ يومك"
        content.body = "افتح التطبيق وشوف مهماتك اليوم."
        content.sound = .default
        var parts = DateComponents()
        parts.hour = (defaults.object(forKey: SettingsKey.morningHour) as? Int) ?? 7
        parts.minute = (defaults.object(forKey: SettingsKey.morningMinute) as? Int) ?? 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: morningID, content: content, trigger: trigger))
    }
}
