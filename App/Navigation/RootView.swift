import HabitCore
import SwiftData
import SwiftUI
import WidgetKit

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
    @AppStorage(SettingsKey.equippedTheme) private var equippedTheme = ShopCatalog.defaultTheme
    @AppStorage(SettingsKey.liveActivityEnabled) private var liveEnabled = true
    @AppStorage(SettingsKey.liveActivityAutoStart) private var liveAutoStart = true
    @AppStorage(SettingsKey.hasPrayerLocation) private var hasLocation = false
    @AppStorage(SettingsKey.prayerLatitude) private var latitude = 0.0
    @AppStorage(SettingsKey.prayerLongitude) private var longitude = 0.0
    @AppStorage(SettingsKey.alarmSound) private var alarmSound = ""
    @AppStorage(SettingsKey.taskFollowsNextRing) private var followsNextRing = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pageWidth: CGFloat = 393
    @State private var dragX: CGFloat = 0
    @State private var headerConfigs: [AppTab: HeaderConfig] = [:]
    @State private var refreshTick = 0

    /// Anything that should make the notification plan be rebuilt.
    private var replanKey: String {
        let alarmPart = alarms.map(\.fingerprint).sorted().joined(separator: ";")
        return "\(alarmPart)#\(hasLocation)#\(latitude)#\(longitude)#\(alarmSound)#\(refreshTick)"
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
            hasher.combine(task.extraPrayersData)
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
        hasher.combine(equippedTheme)
        hasher.combine(liveEnabled)
        hasher.combine(liveAutoStart)
        hasher.combine(hasLocation)
        hasher.combine(latitude)
        hasher.combine(longitude)
        hasher.combine(followsNextRing)
        hasher.combine(refreshTick)
        return hasher.finalize()
    }

    private func makeWidgetOutput(now: Date) -> WidgetSnapshotBuilder.Output {
        let provider: AdhanPrayerTimes? = hasLocation ? AdhanPrayerTimes(latitude: latitude, longitude: longitude) : nil
        return WidgetSnapshotBuilder.make(
            tasks: tasks, completions: completions, alarms: alarms,
            extras: ProgressExtras.load(context: context),
            now: now, dayStartHour: dayStartHour, provider: provider,
            styleID: liveStyle, arabicDigits: DigitStyle(storedValue: digitRaw) == .arabicIndic,
            followsNextRing: followsNextRing
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

    private var headerMorphKey: String {
        router.selectedTab.rawValue + "|" + (headerConfigs[router.selectedTab]?.titleKey ?? "")
            + "|" + (headerConfigs[router.selectedTab]?.subtitle ?? "")
    }

    @ViewBuilder
    private var sharedHeader: some View {
        if let config = headerConfigs[router.selectedTab] {
            CurvedHeader(
                title: config.title, subtitle: config.subtitle,
                onAdd: config.onAdd, onBack: config.onBack, extraButtons: config.extraButtons
            ) { router.showSettings = true }
        }
    }

    var body: some View {
        @Bindable var router = router

        ZStack {
            Theme.surface.ignoresSafeArea()
            // The five tabs are laid out side by side like pages of a book (the bar's order, right to left).
            // Dragging from a screen edge moves the pages with the finger, so half of each shows;
            // tapping a tab slides to it. All tabs stay alive, so each keeps its own state.
            // With Reduce Motion the pages cross-fade in place instead.
            VStack(spacing: 0) {
            // One header for every page: it stays put and morphs (height, title, buttons) to the page shown.
            sharedHeader
            ZStack {
                ForEach(AppTab.allCases) { tab in
                    let isCurrent = tab == router.selectedTab
                    page(for: tab)
                        .environment(\.pageTab, tab)
                        .environment(\.layoutDirection, .rightToLeft)
                        .background(Theme.surface)
                        .offset(x: reduceMotion ? 0 : CGFloat(router.selectedTab.order - tab.order) * pageWidth + dragX)
                        .opacity(reduceMotion && !isCurrent ? 0 : 1)
                        .allowsHitTesting(isCurrent)
                        .accessibilityHidden(!isCurrent)
                }
            }
            // Left-to-right container: offsets and drags are in plain screen coordinates (no RTL mirroring).
            .environment(\.layoutDirection, .leftToRight)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = max($0, 1) }
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .smooth(duration: 0.38), value: router.selectedTab)
            .overlay(alignment: .leading) { edgeSwipeStrip }
            .overlay(alignment: .trailing) { edgeSwipeStrip }
            }
            .onPreferenceChange(HeaderPreferenceKey.self) { headerConfigs = $0 }
            .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: headerMorphKey)

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
        // Weekly automatic backup and the "renew from AltStore" reminder.
        .task {
            BackupService.runAutoBackupIfDue(context: context)
            await SignatureInfo.rescheduleReminder()
        }
        // The widget extension reads the theme from the App Group defaults.
        .task(id: equippedTheme) {
            Theme.mirrorThemeToSharedDefaults(equippedTheme)
            WidgetCenter.shared.reloadAllTimelines()
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
                BackupService.runAutoBackupIfDue(context: context)
                Task { await SignatureInfo.rescheduleReminder() }
            } else if phase == .background {
                AppDelegate.scheduleBackgroundRefresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshTick += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .achievementsNeedSync)) { _ in
            refreshTick += 1
        }
    }

    /// A thin strip on each screen edge: dragging inward from it pages to the next tab in the bar.
    /// Starting at the edge keeps it from fighting row swipe actions, chip scrolls, charts or sliders.
    private var edgeSwipeStrip: some View {
        Color.clear
            .frame(width: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                                                let dx = value.translation.width
                        guard abs(dx) > abs(value.translation.height) else { return }
                        // Finger moving left shows the tab to the right of this one, and vice versa.
                        let hasNext = router.selectedTab.neighbor(dx < 0 ? -1 : 1) != nil
                        dragX = hasNext ? dx : dx * 0.25   // rubber band at the ends
                    }
                    .onEnded { value in
                        let dx = value.translation.width
                        let predicted = value.predictedEndTranslation.width
                        let horizontal = abs(dx) > abs(value.translation.height)
                        let next = router.selectedTab.neighbor(dx < 0 ? -1 : 1)
                        let commit = horizontal && next != nil
                            && (abs(dx) > pageWidth * 0.3 || abs(predicted) > pageWidth * 0.55)
                        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .smooth(duration: 0.38)) {
                            dragX = 0
                            if commit, let next { router.selectedTab = next }
                        }
                    }
            )
            .accessibilityHidden(true)
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
