import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @Query private var alarms: [AlarmRecord]
    @AppStorage(SettingsKey.hasPrayerLocation) private var hasLocation = false
    @AppStorage(SettingsKey.prayerLatitude) private var latitude = 0.0
    @AppStorage(SettingsKey.prayerLongitude) private var longitude = 0.0
    @State private var refreshTick = 0

    /// Anything that should make the notification plan be rebuilt.
    private var replanKey: String {
        let alarmPart = alarms.map(\.fingerprint).sorted().joined(separator: ";")
        return "\(alarmPart)#\(hasLocation)#\(latitude)#\(longitude)#\(refreshTick)"
    }

    var body: some View {
        @Bindable var router = router

        ZStack {
            Theme.surface.ignoresSafeArea()
            page(for: router.selectedTab)

            if router.showDayComplete {
                DayCompleteOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: router.showDayComplete)
        .sheet(item: $router.unlock, onDismiss: { router.unlockSheetClosed() }) { info in
            AchievementUnlockSheet(info: info)
                .appRoot()
        }
        .sheet(item: $router.levelUp) { info in
            LevelUpSheet(info: info)
                .appRoot()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CurvedTabBar(selection: $router.selectedTab)
        }
        .sheet(isPresented: $router.showSettings) {
            SettingsView()
        }
        // Rolling notification window: rebuilt on launch, return to the app,
        // a new day, and any change to alarms or the prayer location.
        .task(id: replanKey) {
            await AlarmActions.replan(container: AppEnvironment.shared.container)
        }
        // Catches achievements earned while the app was closed or from older history.
        .task(id: refreshTick) {
            let result = AchievementActions.syncFromStore(context: context, now: Date(), dayStartHour: dayStartHour)
            router.present(achievements: result.unlocked, newLevel: result.newLevel)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshTick += 1
            } else if phase == .background {
                AppDelegate.scheduleBackgroundRefresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshTick += 1
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
