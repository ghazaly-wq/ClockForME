import BackgroundTasks
import HabitCore
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

/// Things the app delegate, the notification buttons and the SwiftUI scene all share.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let container: ModelContainer
    let router = AppRouter()

    private init() {
        do {
            container = try ModelContainer(for: TaskRecord.self, CompletionRecord.self, AlarmRecord.self)
        } catch {
            fatalError("Could not open the database: \(error)")
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    nonisolated static let refreshTaskID = "com.ghazaly.habits.refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        let digits = DigitStyle(storedValue: UserDefaults.standard.string(forKey: SettingsKey.digitStyle) ?? DigitStyle.western.rawValue)
        NotificationService.registerCategories(digits: digits)

        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Self.scheduleBackgroundRefresh()
            let work = Task { @MainActor in
                await AlarmActions.replan(container: AppEnvironment.shared.container)
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
        }
        return true
    }

    /// Asks the system to wake the app now and then so the notification window keeps rolling,
    /// even if the app isn't opened for a few days. iOS decides the actual time.
    nonisolated static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Notifications

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let content = response.notification.request.content
        let alarmID = content.userInfo["alarmID"] as? String ?? ""
        let title = content.title
        let body = content.body
        let category = content.categoryIdentifier

        switch action {
        case NotificationIDs.actionDone:
            if let id = UUID(uuidString: alarmID) {
                await MainActor.run {
                    AlarmActions.completeLinkedTask(alarmID: id, container: AppEnvironment.shared.container)
                }
            }
        case NotificationIDs.actionSnooze:
            await NotificationService.snooze(alarmID: alarmID, title: title, body: body, category: category)
        case UNNotificationDefaultActionIdentifier:
            await MainActor.run {
                AppEnvironment.shared.router.selectedTab = .alarms
            }
        default:
            break
        }
    }
}
