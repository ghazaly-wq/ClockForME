import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        ZStack {
            Theme.surface.ignoresSafeArea()
            page(for: router.selectedTab)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CurvedTabBar(selection: $router.selectedTab)
        }
        .sheet(isPresented: $router.showSettings) {
            SettingsView()
        }
    }

    @ViewBuilder
    private func page(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .alarms: AlarmsView()
        case .tasks: TasksView()
        case .achievements: AchievementsView()
        case .pages: PagesView()
        }
    }
}
