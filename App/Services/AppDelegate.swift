import BackgroundTasks
import HabitCore
import SwiftData
import SwiftUI
import UIKit

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

final class AppDelegate: NSObject, UIApplicationDelegate {
    nonisolated static let refreshTaskID = "com.ghazaly.habits.refresh"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
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
}
