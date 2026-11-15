import SwiftData
import SwiftUI

@main
struct HabitsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment.router)
                .appRoot()
        }
        .modelContainer(environment.container)
    }
}
