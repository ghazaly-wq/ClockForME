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
    @AppStorage(SettingsKey.appBlockEnabled) private var appBlockEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pageWidth: CGFloat = 393
    @State private var dragX: CGFloat = 0
    @State private var headerConfigs: [AppTab: HeaderConfig] = [:]
    @State private var refreshTick = 0
    /// Bumped every 30 seconds so the app-block screen appears when a blocking task's time arrives.
    @State private var blockTick = 0
    private let blockTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    /// Anything that should make the notification plan be rebuilt.
    private var replanKey: String {
        let alarmPart = alarms.map(\.fingerprint).sorted().joined(separator: ";")
        // Finishing (or un-finishing) a task changes whether its alarm should still ring that day. Only recent days
        // matter, so old history doesn't make this key expensive.
        let cutoff = DayKey(date: Date(), calendar: Calendar.app, dayStartHour: dayStartHour)
            .adding(days: -2, calendar: Calendar.app)?.isoString ?? ""
        let donePart = completions.filter { $0.dayISO >= cutoff }
            .map { "\($0.taskID.uuidString)\($0.dayISO)" }.sorted().joined(separator: ",")
        return "\(alarmPart)#\(hasLocation)#\(latitude)#\(longitude)#\(alarmSound)#\(refreshTick)#\(donePart)"
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

    // MARK: - App block

    /// Tasks blocking the owner's apps right now (empty while the master switch is off, the app is in the
    /// background, or a challenge is on screen: the challenge comes first).
    private var blockingTasks: [BlockingTask] {
        _ = blockTick
        _ = refreshTick
        guard appBlockEnabled, scenePhase == .active, router.activeChallenge == nil else { return [] }
        let provider: AdhanPrayerTimes? = hasLocation ? AdhanPrayerTimes(latitude: latitude, longitude: longitude) : nil
        return AppBlockService.blockingTasks(
            tasks: tasks, completions: completions, alarms: alarms,
            now: Date(), dayStartHour: dayStartHour, provider: provider
        )
    }

    private func completeBlockingTask(_ task: TaskRecord) {
        let now = Date()
        let today = DayKey(date: now, calendar: Calendar.app, dayStartHour: dayStartHour)
        let outcome = TaskActions.toggle(
            task, on: today, tasks: tasks, completions: completions,
            context: context, now: now, dayStartHour: dayStartHour
        )
        router.celebrate(outcome)
        blockTick += 1
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

    // MARK: - Alarm stop: challenge and destination

    /// The stop button of an alarm opened the app (the intent already moved to the usual page). If that ring has a
    /// challenge, it comes first; if it only has a destination, we leave for it.
    private func handleAlarmStop() {
        router.alarmStoppedAt = nil
        let now = Date()
        let pending = AlarmScheduler.challengeLedger().pendingEntries(now: now)
        for entry in pending {
            guard let alarm = fetchAlarm(entry.alarmID), alarm.delivery == .alarm else { continue }
            if let challenge = alarm.challenge {
                present(alarm: alarm, challenge: challenge, key: entry.key, fire: entry.fireDate)
                return
            }
            if let destination = alarm.stopDestination, destination.isValid {
                AlarmScheduler.completeChallenge(occurrence: entry.key)
                open(destination)
                return
            }
        }
    }

    /// Opened the app by hand while a challenge alarm is still waiting for its challenge.
    private func presentPendingChallenge() {
        guard router.activeChallenge == nil else { return }
        for entry in AlarmScheduler.challengeLedger().pendingEntries(now: Date()) {
            guard let alarm = fetchAlarm(entry.alarmID), alarm.delivery == .alarm, let challenge = alarm.challenge else { continue }
            present(alarm: alarm, challenge: challenge, key: entry.key, fire: entry.fireDate)
            return
        }
    }

    private func present(alarm: AlarmRecord, challenge: AlarmChallenge, key: String, fire: Date) {
        router.activeChallenge = ActiveChallenge(
            id: key, alarmID: alarm.id, title: alarm.title, challenge: challenge, destination: alarm.stopDestination,
            expiresAt: max(fire.addingTimeInterval(ChallengeChain.window), Date().addingTimeInterval(60)),
            showTasks: alarm.isMainTask, pageID: alarm.linkedPageID
        )
    }

    private func challengeFinished(_ active: ActiveChallenge) {
        AlarmScheduler.completeChallenge(occurrence: active.id)
        router.activeChallenge = nil
        openFallback(showTasks: active.showTasks, pageID: active.pageID)
        if let destination = active.destination, destination.isValid { open(destination) }
        Task { await AlarmActions.replan(container: AppEnvironment.shared.container) }
    }

    private func fetchAlarm(_ id: UUID) -> AlarmRecord? {
        let descriptor = FetchDescriptor<AlarmRecord>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    /// Where the stop button used to lead: the page of a custom-page alarm, the tasks, or the alarms.
    private func openFallback(showTasks: Bool, pageID: UUID?) {
        if let pageID {
            router.openPageID = pageID
            router.selectedTab = .pages
        } else {
            router.selectedTab = showTasks ? .tasks : .alarms
        }
    }

    /// Leaves the app for the chosen website / app / shortcut (a short pause lets this app finish coming forward first).
    private func open(_ destination: StopDestination) {
        guard let url = destination.url else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            _ = await UIApplication.shared.open(url)
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
        // The stop button of a challenge / destination alarm, and a challenge still waiting when the app opens.
        .onChange(of: router.alarmStoppedAt, initial: true) { _, stoppedAt in
            if stoppedAt != nil { handleAlarmStop() }
        }
        .task { presentPendingChallenge() }
        .fullScreenCover(item: $router.activeChallenge) { active in
            ChallengeView(
                active: active,
                onFinished: { challengeFinished(active) },
                onClose: { router.activeChallenge = nil }
            )
            .appRoot()
        }
        // Catches achievements earned while the app was closed or from older history.
        .task(id: refreshTick) {
            let result = AchievementActions.syncFromStore(context: context, now: Date(), dayStartHour: dayStartHour)
            router.present(achievements: result.unlocked, newLevel: result.newLevel)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshTick += 1
                presentPendingChallenge()
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
        .onReceive(blockTimer) { _ in blockTick += 1 }
        // Over everything (tab bar included): finish the blocking task to get past it.
        .overlay {
            let blocking = blockingTasks
            if !blocking.isEmpty {
                AppBlockView(blocking: blocking, onDone: completeBlockingTask)
                    .appRoot()
                    .transition(.opacity)
            }
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
