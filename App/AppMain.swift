import SwiftData
import SwiftUI

@main
struct HabitsApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .appRoot()
        }
        .modelContainer(for: [TaskRecord.self, CompletionRecord.self])
    }
}
