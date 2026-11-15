import HabitCore
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.digitStyle) private var digits
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @AppStorage(SettingsKey.hasPrayerLocation) private var hasLocation = false
    @AppStorage(SettingsKey.prayerLatitude) private var latitude = 0.0
    @AppStorage(SettingsKey.prayerLongitude) private var longitude = 0.0
    @Query(sort: [SortDescriptor(\TaskRecord.sortOrder), SortDescriptor(\TaskRecord.createdAt)])
    private var tasks: [TaskRecord]
    @Query private var completions: [CompletionRecord]
    @Query(sort: \AlarmRecord.createdAt) private var alarms: [AlarmRecord]
    @Query private var unlocks: [AchievementUnlockRecord]
    @Query private var purchases: [PurchaseRecord]
    @Query private var pageSessions: [PageSessionRecord]
    @Query private var rewards: [RewardRecord]
    @Query private var pageRecords: [PageRecord]
    @AppStorage(SettingsKey.equippedLiveStyle) private var liveStyle = ShopCatalog.defaultLiveStyle
    private let live = LiveActivityController.shared

    @State private var now = Date()
    @State private var taskSheet: EditorTarget?
    @State private var alarmSheet: AlarmEditorTarget?

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let calendar = Calendar.app
        let snapshot = ProgressSnapshot.make(
            tasks: tasks, completions: completions, now: now, dayStartHour: dayStartHour, calendar: calendar,
            extras: ProgressExtras(unlocks: unlocks, purchases: purchases, rewards: rewards, pages: pageRecords, sessions: pageSessions)
        )
        let provider: AdhanPrayerTimes? = hasLocation ? AdhanPrayerTimes(latitude: latitude, longitude: longitude) : nil
        let doneToday = Set(completions.filter { $0.day == snapshot.today }.map(\.taskID))
        let mainToday = tasks.filter {
            $0.kind == .main && $0.repetition != nil && $0.spec.isScheduled(on: snapshot.today, calendar: calendar)
        }
        let nextTask = nextTaskInfo(mainToday, doneToday: doneToday, today: snapshot.today, provider: provider, calendar: calendar)
        let upcomingAlarms = upcomingAlarmsToday(provider: provider, calendar: calendar)

        CurvedPage(
            title: LocalizedStringKey(greeting(calendar)),
            subtitle: headerSubtitle(provider: provider, calendar: calendar)
        ) {
            VStack(spacing: 16) {
                TodayCard(
                    progress: snapshot.todayMain,
                    segments: mainToday.map { doneToday.contains($0.id) },
                    streak: snapshot.streak.current,
                    nextLine: nextTask
                )

                if !hasLocation { locationPrompt }

                upcomingCard(upcomingAlarms)
                mainTasksCard(mainToday, doneToday: doneToday, snapshot: snapshot, provider: provider, calendar: calendar)
                LevelCard(summary: snapshot.summary)
                HomeGoalsCard(snapshot: snapshot, rewards: rewards)
                RecentAchievementsCard(unlocks: unlocks)
                quickActions
                liveActivityCard(snapshot: snapshot, provider: provider)
            }
        }
        .sheet(item: $taskSheet) { target in
            TaskEditorView(target: target)
                .appRoot()
        }
        .sheet(item: $alarmSheet) { target in
            AlarmEditorView(target: target)
                .appRoot()
        }
        .sensoryFeedback(.success, trigger: doneToday.count) { old, new in new > old }
        .onReceive(ticker) { now = $0 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
    }

    // MARK: - Header

    private func greeting(_ calendar: Calendar) -> String {
        Greeting.kind(at: now, calendar: calendar) == .morning
            ? String(localized: "صباح الخير")
            : String(localized: "مساء الخير")
    }

    /// Date line, plus the next prayer with a countdown when a location is set.
    private func headerSubtitle(provider: AdhanPrayerTimes?, calendar: Calendar) -> String {
        var lines = [DateLine.text(for: now, style: digits)]
        if let provider, let next = NextPrayer.find(provider: provider, now: now, calendar: calendar) {
            let parts = Countdown.parts(from: now, to: next.date)
            let name = AlarmText.name(of: next.prayer)
            let duration = AlarmText.durationText(hours: parts.hours, minutes: parts.minutes)
            let text = duration.isEmpty
                ? String(localized: "حان وقت \(name)")
                : String(localized: "\(name) بعد \(duration)")
            lines.append(digits.format(text) + " · " + AlarmText.time(next.date, digits: digits))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Next main task

    private func nextTaskInfo(
        _ mainToday: [TaskRecord],
        doneToday: Set<UUID>,
        today: DayKey,
        provider: AdhanPrayerTimes?,
        calendar: Calendar
    ) -> String? {
        let items = mainToday.map {
            TodayTaskItem(id: $0.id, isDone: doneToday.contains($0.id), time: $0.dueDate(on: today, provider: provider, calendar: calendar))
        }
        switch NextMainTask.pick(items, now: now) {
        case .noTasks:
            return nil
        case .allDone:
            return String(localized: "أنجزت كل مهماتك 🎉")
        case .task(let id):
            guard let task = mainToday.first(where: { $0.id == id }) else { return nil }
            if let due = items.first(where: { $0.id == id })?.time {
                return String(localized: "التالية: \(task.title)") + " · " + AlarmText.time(due, digits: digits)
            }
            return String(localized: "التالية: \(task.title)")
        }
    }

    // MARK: - Cards

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var locationPrompt: some View {
        card {
            Label {
                Text("حدد موقعك لتظهر الصلاة الجاية هنا.")
                    .font(.callout)
                    .foregroundStyle(Theme.textPrimary)
            } icon: {
                Image(systemName: "location.slash")
                    .foregroundStyle(Theme.primaryStrong)
            }
            Button("تحديد الموقع") { router.showSettings = true }
                .font(.subheadline.bold())
                .foregroundStyle(Theme.primaryStrong)
                .frame(minHeight: 44, alignment: .leading)
        }
    }

    private struct UpcomingAlarm: Identifiable {
        let alarm: AlarmRecord
        let fire: Date
        var id: UUID { alarm.id }
    }

    private func upcomingAlarmsToday(provider: AdhanPrayerTimes?, calendar: Calendar) -> [UpcomingAlarm] {
        let day = DayKey(date: now, calendar: calendar)
        return alarms
            .filter(\.isEnabled)
            .compactMap { alarm -> UpcomingAlarm? in
                guard let fire = NotificationPlanner.fireDate(of: alarm.rule, on: day, provider: provider, calendar: calendar),
                      fire > now else { return nil }
                return UpcomingAlarm(alarm: alarm, fire: fire)
            }
            .sorted { $0.fire < $1.fire }
    }

    private func upcomingCard(_ upcoming: [UpcomingAlarm]) -> some View {
        card {
            HStack {
                Text("قادم اليوم")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("عرض الكل") { router.selectedTab = .alarms }
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primaryStrong)
                    .frame(minHeight: 44)
            }
            if upcoming.isEmpty {
                Text("ما عندك تنبيهات قادمة اليوم.")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(upcoming.prefix(4)) { item in
                    HStack(spacing: 12) {
                        Text(AlarmText.time(item.fire, digits: digits))
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                            .frame(minWidth: 84, alignment: .leading)
                        Text(item.alarm.title)
                            .font(.body)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 0)
                        if item.alarm.isMainTask {
                            Image(systemName: "star.fill")
                                .foregroundStyle(Theme.primaryStrong)
                                .accessibilityLabel(Text("مهمة رئيسية"))
                        }
                    }
                    .frame(minHeight: 36)
                }
            }
        }
    }

    private func mainTasksCard(
        _ mainToday: [TaskRecord],
        doneToday: Set<UUID>,
        snapshot: ProgressSnapshot,
        provider: AdhanPrayerTimes?,
        calendar: Calendar
    ) -> some View {
        card {
            HStack {
                Text("المهمات الرئيسية")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("كل المهمات") { router.selectedTab = .tasks }
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primaryStrong)
                    .frame(minHeight: 44)
            }
            if mainToday.isEmpty {
                Text("ما عندك مهمات رئيسية اليوم — أضف أول مهمة")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                Button("إضافة مهمة") { taskSheet = .new(.main) }
                    .buttonStyle(.borderedProminent)
                    .font(.headline)
            } else {
                ForEach(mainToday) { task in
                    TaskRow(
                        title: task.title,
                        subtitle: RepetitionText.summary(of: task.repetition, digits: digits),
                        isDone: doneToday.contains(task.id),
                        alarmTime: task.dueDate(on: snapshot.today, provider: provider, calendar: calendar)
                            .map { AlarmText.time($0, digits: digits) },
                        onToggle: { toggle(task, snapshot: snapshot) },
                        onEdit: { taskSheet = .edit(task) }
                    )
                    if task.id != mainToday.last?.id { Divider() }
                }
            }
        }
    }

    private var pinnedPages: [PageDefinition] {
        pageRecords.filter { !$0.isTemplate }.map(\.definition).filter(\.pinnedToHome)
    }

    private var quickActions: some View {
        VStack(spacing: 12) {
            quickActionRow
            ForEach(pinnedPages) { page in
                Button {
                    router.openPageID = page.id
                    router.selectedTab = .pages
                } label: {
                    Label(page.emoji + " " + page.name, systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .font(.subheadline.bold())
                .tint(Theme.primaryStrong)
            }
        }
    }

    private var quickActionRow: some View {
        HStack(spacing: 12) {
            Button { taskSheet = .new(.main) } label: {
                Label("مهمة جديدة", systemImage: "checklist")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            Button { alarmSheet = .new } label: {
                Label("تنبيه جديد", systemImage: "alarm")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .buttonStyle(.bordered)
        .font(.subheadline.bold())
        .tint(Theme.primaryStrong)
    }

    // MARK: - Live Activity

    @ViewBuilder
    private func liveActivityCard(snapshot: ProgressSnapshot, provider: AdhanPrayerTimes?) -> some View {
        if snapshot.todayMain.total > 0 {
            card {
                if live.isRunning {
                    Label("مهماتك ظاهرة على شاشة القفل", systemImage: "lock.iphone")
                        .font(.callout)
                        .foregroundStyle(Theme.textPrimary)
                    Button {
                        Task { await live.stopForToday(dayKey: snapshot.today.isoString) }
                    } label: {
                        Text("إيقاف لليوم")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.primaryStrong)
                } else {
                    Button {
                        startDay(provider: provider)
                    } label: {
                        Label("ابدأ يومك", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func startDay(provider: AdhanPrayerTimes?) {
        let now = Date()
        let output = WidgetSnapshotBuilder.make(
            tasks: tasks, completions: completions, alarms: alarms,
            extras: ProgressExtras(unlocks: unlocks, purchases: purchases, rewards: rewards, pages: pageRecords, sessions: pageSessions),
            now: now, dayStartHour: dayStartHour, provider: provider,
            styleID: liveStyle, arabicDigits: digits == .arabicIndic
        )
        Task { await live.startManually(output, now: now) }
    }

    // MARK: - Data

    private func toggle(_ task: TaskRecord, snapshot: ProgressSnapshot) {
        let outcome = TaskActions.toggle(
            task, on: snapshot.today, tasks: tasks, completions: completions,
            context: context, now: Date(), dayStartHour: dayStartHour
        )
        router.celebrate(outcome)
    }
}

/// "14 نوفمبر 2026 · 2 جمادى الأولى 1448": Gregorian first, Hijri (Umm al-Qura) beside it.
enum DateLine {
    static func text(for date: Date, style: DigitStyle) -> String {
        let locale = Locale(identifier: "ar_SA")

        let gregorian = DateFormatter()
        gregorian.locale = locale
        gregorian.calendar = Calendar(identifier: .gregorian)
        gregorian.dateFormat = "d MMMM yyyy"

        let hijri = DateFormatter()
        hijri.locale = locale
        hijri.calendar = Calendar(identifier: .islamicUmmAlQura)
        hijri.dateFormat = "d MMMM yyyy"

        let raw = "\(gregorian.string(from: date)) · \(hijri.string(from: date))"
        return NumberFormatting.convertDigits(in: raw, to: style)
    }
}
