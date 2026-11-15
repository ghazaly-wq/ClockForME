import HabitCore
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @Query private var alarms: [AlarmRecord]
    @Query private var tasks: [TaskRecord]
    @Query private var completions: [CompletionRecord]
    @AppStorage(SettingsKey.digitStyle) private var digitRaw = DigitStyle.western.rawValue
    @AppStorage(SettingsKey.equippedLiveStyle) private var liveStyle = ShopCatalog.defaultLiveStyle
    @AppStorage(SettingsKey.liveActivityEnabled) private var liveEnabled = true
    @AppStorage(SettingsKey.liveActivityAutoStart) private var liveAutoStart = true
    @AppStorage(SettingsKey.hasPrayerLocation) private var hasLocation = false
    @AppStorage(SettingsKey.prayerLatitude) private var latitude = 0.0
    @AppStorage(SettingsKey.prayerLongitude) private var longitude = 0.0
    @State private var refreshTick = 0

    /// Anything that should make the notification plan be rebuilt.
    private var replanKey: String {
        let alarmPart = alarms.map(\.fingerprint).sorted().joined(separator: ";")
        return "\(alarmPart)#\(hasLocation)#\(latitude)#\(longitude)#\(refreshTick)"
    }

    /// Anything that changes what the widgets and the Live Activity show.
    private var widgetKey: Int {
        var hasher = Hasher()
        for task in tasks {
            hasher.combine(task.id)
            hasher.combine(task.title)
            hasher.combine(task.kindRaw)
            hasher.combine(task.repetitionData)
            hasher.combine(task.startDayISO)
            hasher.combine(task.endDayISO)
            hasher.combine(task.timeData)
            hasher.combine(task.sortOrder)
        }
        for completion in completions {
            hasher.combine(completion.taskID)
            hasher.combine(completion.dayISO)
        }
        for alarm in alarms { hasher.combine(alarm.fingerprint) }
        hasher.combine(dayStartHour)
        hasher.combine(digitRaw)
        hasher.combine(liveStyle)
        hasher.combine(liveEnabled)
        hasher.combine(liveAutoStart)
        hasher.combine(hasLocation)
        hasher.combine(latitude)
        hasher.combine(longitude)
        hasher.combine(refreshTick)
        return hasher.finalize()
    }

    private func makeWidgetOutput(now: Date) -> WidgetSnapshotBuilder.Output {
        let provider: AdhanPrayerTimes? = hasLocation ? AdhanPrayerTimes(latitude: latitude, longitude: longitude) : nil
        return WidgetSnapshotBuilder.make(
            tasks: tasks, completions: completions, alarms: alarms,
            extras: ProgressExtras.load(context: context),
            now: now, dayStartHour: dayStartHour, provider: provider,
            styleID: liveStyle, arabicDigits: DigitStyle(storedValue: digitRaw) == .arabicIndic
        )
    }

    private func handle(_ url: URL) {
        guard url.scheme == "habits" else { return }
        switch url.host {
        case "today", "tasks":
            router.selectedTab = .tasks
        case "start":
            router.selectedTab = .home
            Task { await LiveActivityController.shared.startManually(makeWidgetOutput(now: Date()), now: Date()) }
        default:
            router.selectedTab = .home
        }
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
        // Widgets and the Live Activity follow the data (and the shop style / settings).
        .task(id: widgetKey) {
            let now = Date()
            await LiveActivityController.shared.sync(makeWidgetOutput(now: now), now: now)
        }
        .task {
            await LiveActivityController.shared.updateMorningReminder()
        }
        .onOpenURL { handle($0) }
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
