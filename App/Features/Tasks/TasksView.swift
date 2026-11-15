import HabitCore
import SwiftData
import SwiftUI

enum EditorTarget: Identifiable {
    case new(TaskKind)
    case edit(TaskRecord)

    var id: String {
        switch self {
        case .new(let kind): return "new-\(kind.rawValue)"
        case .edit(let task): return task.id.uuidString
        }
    }
}

/// Narrows the lists on the Tasks page by kind.
enum TaskFilter: Hashable {
    case all, main, secondary

    func matches(_ task: TaskRecord) -> Bool {
        switch self {
        case .all: return true
        case .main: return task.kind == .main
        case .secondary: return task.kind == .secondary
        }
    }
}

struct TasksView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.digitStyle) private var digits
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @AppStorage(SettingsKey.taskShowAllTimes) private var showAllTimes = true
    @AppStorage(SettingsKey.taskFollowsNextRing) private var followsNextRing = true
    @AppStorage(SettingsKey.hasPrayerLocation) private var hasLocation = false
    @AppStorage(SettingsKey.prayerLatitude) private var latitude = 0.0
    @AppStorage(SettingsKey.prayerLongitude) private var longitude = 0.0
    @Query(sort: [SortDescriptor(\TaskRecord.sortOrder), SortDescriptor(\TaskRecord.createdAt)])
    private var tasks: [TaskRecord]
    @Query private var completions: [CompletionRecord]
    @Query private var alarms: [AlarmRecord]
    @Query private var unlocks: [AchievementUnlockRecord]
    @Query private var purchases: [PurchaseRecord]
    @Query private var rewards: [RewardRecord]

    /// A task that belongs to a custom page opens that page; any other task opens its editor.
    private func openEditor(_ task: TaskRecord) {
        if let pageID = task.pageID {
            router.openPageID = pageID
            router.selectedTab = .pages
        } else {
            editor = .edit(task)
        }
    }

    @State private var filter: TaskFilter = .all
    @State private var now = Date()
    @State private var editor: EditorTarget?
    @State private var upcomingExpanded = false
    @State private var undoToken: TaskDeletion?
    @State private var undoDismiss: Task<Void, Never>?

    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let calendar = Calendar.app
        let snapshot = ProgressSnapshot.make(
            tasks: tasks, completions: completions, now: now, dayStartHour: dayStartHour, calendar: calendar,
            extras: ProgressExtras(unlocks: unlocks, purchases: purchases, rewards: rewards)
        )
        let doneToday = Set(completions.filter { $0.day == snapshot.today }.map(\.taskID))
        let doneEver = Set(completions.map(\.taskID))
        let provider: AdhanPrayerTimes? = hasLocation ? AdhanPrayerTimes(latitude: latitude, longitude: longitude) : nil
        let mainToday = todayTasks(.main, today: snapshot.today, doneToday: doneToday, doneEver: doneEver, calendar: calendar)
        let secondaryToday = todayTasks(.secondary, today: snapshot.today, doneToday: doneToday, doneEver: doneEver, calendar: calendar)
        let combined: [TaskRecord] = (mainToday + secondaryToday).filter(filter.matches)
        let list: [TaskRecord] = combined.sortedByDueTime(on: snapshot.today, provider: provider, calendar: calendar)
        let upcomingAll: [TaskRecord] = upcomingTasks(.main, today: snapshot.today) + upcomingTasks(.secondary, today: snapshot.today)
        let upcoming: [TaskRecord] = upcomingAll.filter(filter.matches).sorted { $0.startDay < $1.startDay }
        let newKind: TaskKind = filter == .secondary ? .secondary : .main

        CurvedPage(title: "المهمات", scrollable: false, onAdd: { editor = .new(newKind) }) {
            VStack(spacing: 0) {
            Picker("تصفية المهمات", selection: $filter) {
                Text("الكل").tag(TaskFilter.all)
                Text("المهمات الرئيسية").tag(TaskFilter.main)
                Text("المهمات الفرعية").tag(TaskFilter.secondary)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            List {
                Section {
                    TodayCard(
                        progress: snapshot.todayMain,
                        segments: mainToday.map { doneToday.contains($0.id) },
                        streak: snapshot.streak.current
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    LevelCard(summary: snapshot.summary)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    if list.isEmpty {
                        emptyState
                    } else {
                        ForEach(list) { task in
                            row(task, isDone: doneToday.contains(task.id), snapshot: snapshot)
                        }
                    }
                } header: {
                    Text(headerTitle)
                }
                .listRowBackground(Theme.card)

                if !upcoming.isEmpty {
                    Section {
                        DisclosureGroup(
                            isExpanded: $upcomingExpanded,
                            content: {
                                ForEach(upcoming) { task in
                                    TaskRow(
                                        title: task.title,
                                        subtitle: RepetitionText.summary(of: task.repetition, digits: digits),
                                        isDone: false,
                                        showsCheck: false,
                                        alarmTime: alarmTimeText(task),
                                        onToggle: {},
                                        onEdit: { openEditor(task) }
                                    )
                                }
                            },
                            label: {
                                Text(digits.format(String(localized: "قادمة (\(upcoming.count))")))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        )
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, Metrics.homeRingDiameter / 2 + 8, for: .scrollContent)
            }
        }
        .overlay(alignment: .bottom) {
            if let undoToken {
                undoToast(undoToken)
            }
        }
        .animation(.spring(duration: 0.3), value: undoToken != nil)
        .sheet(item: $editor) { target in
            TaskEditorView(target: target)
                .appRoot()
        }
        .sensoryFeedback(.success, trigger: doneToday.count) { old, new in new > old }
        .onReceive(ticker) { now = $0 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
    }

    // MARK: - Rows

    private func row(_ task: TaskRecord, isDone: Bool, snapshot: ProgressSnapshot) -> some View {
        TaskRow(
            title: task.title,
            subtitle: RepetitionText.summary(of: task.repetition, digits: digits),
            isDone: isDone,
            alarmTime: alarmTimeText(task),
            onToggle: { toggle(task, snapshot: snapshot) },
            onEdit: { openEditor(task) }
        )
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggle(task, snapshot: snapshot)
            } label: {
                Label(isDone ? "إلغاء" : "تم", systemImage: isDone ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(Theme.primary)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                showUndo(AlarmActions.deleteTask(task, alarms: alarms, completions: completions, context: context, today: snapshot.today))
            } label: {
                Label("حذف", systemImage: "trash")
            }
            Button {
                openEditor(task)
            } label: {
                Label("تعديل", systemImage: "pencil")
            }
            .tint(Theme.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(filter == .secondary ? "ما عندك مهمات فرعية اليوم" : (filter == .main ? "ما عندك مهمات رئيسية اليوم — أضف أول مهمة" : "ما عندك مهمات اليوم — أضف أول مهمة"))
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("إضافة مهمة") { editor = .new(filter == .secondary ? .secondary : .main) }
                .buttonStyle(.borderedProminent)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    /// "7:30 ص" for a clock alarm; for a prayer alarm today's resolved time(s), or its wording without a location.
    private func alarmTimeText(_ task: TaskRecord) -> String? {
        let calendar = Calendar.app
        let provider: AdhanPrayerTimes? = hasLocation ? AdhanPrayerTimes(latitude: latitude, longitude: longitude) : nil
        return TaskTimeText.text(
            for: task, on: DayKey(date: now, calendar: calendar), provider: provider, calendar: calendar,
            now: now, showAll: showAllTimes, followsNextRing: followsNextRing, digits: digits
        )
    }

    // MARK: - Undo

    private func undoToast(_ token: TaskDeletion) -> some View {
        HStack(spacing: 12) {
            Text("تم حذف المهمة")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary)
            Button("تراجع") {
                AlarmActions.undoDeleteTask(token, context: context)
                undoDismiss?.cancel()
                undoToken = nil
            }
            .font(.subheadline.bold())
            .foregroundStyle(Theme.primaryStrong)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 18)
        .background(Theme.card, in: Capsule())
        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
        .padding(.bottom, 56)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func showUndo(_ token: TaskDeletion) {
        undoToken = token
        AccessibilityNotification.Announcement(String(localized: "تم حذف المهمة")).post()
        undoDismiss?.cancel()
        undoDismiss = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { undoToken = nil }
        }
    }

    // MARK: - Data

    private func toggle(_ task: TaskRecord, snapshot: ProgressSnapshot) {
        let outcome = TaskActions.toggle(
            task,
            on: snapshot.today,
            tasks: tasks,
            completions: completions,
            context: context,
            now: Date(),
            dayStartHour: dayStartHour
        )
        router.celebrate(outcome)
    }

    /// Tasks shown today: scheduled ones, plus "anytime" secondary tasks that are not finished yet.
    private func todayTasks(
        _ kind: TaskKind,
        today: DayKey,
        doneToday: Set<UUID>,
        doneEver: Set<UUID>,
        calendar: Calendar
    ) -> [TaskRecord] {
        tasks.filter { task in
            guard task.kind == kind else { return false }
            if task.repetition == nil {
                if let end = task.endDay, today >= end { return false }
                return !doneEver.contains(task.id) || doneToday.contains(task.id)
            }
            return task.spec.isScheduled(on: today, calendar: calendar)
        }
    }

    private var headerTitle: LocalizedStringKey {
        switch filter {
        case .all: return "مهمات اليوم"
        case .main: return "مهمات اليوم الرئيسية"
        case .secondary: return "مهمات اليوم الفرعية"
        }
    }

    /// One-off tasks dated after today.
    private func upcomingTasks(_ kind: TaskKind, today: DayKey) -> [TaskRecord] {
        tasks
            .filter { task in
                guard task.kind == kind, task.endDay == nil, case .once(let day)? = task.repetition else { return false }
                return day > today
            }
            .sorted { $0.startDay < $1.startDay }
    }
}
