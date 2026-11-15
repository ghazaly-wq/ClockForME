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

struct TasksView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.digitStyle) private var digits
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @Query(sort: [SortDescriptor(\TaskRecord.sortOrder), SortDescriptor(\TaskRecord.createdAt)])
    private var tasks: [TaskRecord]
    @Query private var completions: [CompletionRecord]

    @State private var segment: TaskKind = .main
    @State private var now = Date()
    @State private var editor: EditorTarget?
    @State private var upcomingExpanded = false
    @State private var editMode: EditMode = .inactive
    @State private var undoToken: DeleteUndo?
    @State private var undoDismiss: Task<Void, Never>?

    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let calendar = Calendar.app
        let snapshot = ProgressSnapshot.make(
            tasks: tasks, completions: completions, now: now, dayStartHour: dayStartHour, calendar: calendar
        )
        let doneToday = Set(completions.filter { $0.day == snapshot.today }.map(\.taskID))
        let doneEver = Set(completions.map(\.taskID))
        let mainToday = todayTasks(.main, today: snapshot.today, doneToday: doneToday, doneEver: doneEver, calendar: calendar)
        let list = segment == .main
            ? mainToday
            : todayTasks(.secondary, today: snapshot.today, doneToday: doneToday, doneEver: doneEver, calendar: calendar)
        let upcoming = upcomingTasks(segment, today: snapshot.today)

        CurvedPage(title: "المهمات", scrollable: false, onAdd: { editor = .new(segment) }) {
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
                    Picker("نوع المهمات", selection: $segment) {
                        Text("رئيسية").tag(TaskKind.main)
                        Text("فرعية").tag(TaskKind.secondary)
                    }
                    .pickerStyle(.segmented)
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
                        .onMove { source, destination in
                            TaskActions.move(displayed: list, from: source, to: destination, allTasks: tasks, context: context)
                        }
                    }
                } header: {
                    HStack {
                        Text(segment == .main ? "مهمات اليوم الرئيسية" : "مهمات اليوم الفرعية")
                        Spacer()
                        if list.count > 1 {
                            Button(editMode.isEditing ? "تم" : "ترتيب") {
                                withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.primaryStrong)
                            .textCase(nil)
                            .frame(minHeight: 44)
                        }
                    }
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
                                        onToggle: {},
                                        onEdit: { editor = .edit(task) }
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
            .environment(\.editMode, $editMode)
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
            onToggle: { toggle(task, snapshot: snapshot) },
            onEdit: { editor = .edit(task) }
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
                showUndo(TaskActions.delete(task, completions: completions, context: context, today: snapshot.today))
            } label: {
                Label("حذف", systemImage: "trash")
            }
            Button {
                editor = .edit(task)
            } label: {
                Label("تعديل", systemImage: "pencil")
            }
            .tint(Theme.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(segment == .main ? "ما عندك مهمات رئيسية اليوم — أضف أول مهمة" : "ما عندك مهمات فرعية اليوم")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("إضافة مهمة") { editor = .new(segment) }
                .buttonStyle(.borderedProminent)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Undo

    private func undoToast(_ token: DeleteUndo) -> some View {
        HStack(spacing: 12) {
            Text("تم حذف المهمة")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary)
            Button("تراجع") {
                TaskActions.undoDelete(token, context: context)
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

    private func showUndo(_ token: DeleteUndo) {
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
