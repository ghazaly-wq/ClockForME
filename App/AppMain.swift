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
    }
}
