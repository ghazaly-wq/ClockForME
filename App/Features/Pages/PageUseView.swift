import HabitCore
import SwiftData
import SwiftUI

/// "استخدام" mode: the owner fills the page in during a session. Values are saved as he types;
/// "إنهاء الجلسة" marks the session finished and completes the page's linked main task for today.
struct PageUseView: View {
    let page: PageDefinition
    let tab: PageTab
    let sessionRecords: [PageSessionRecord]

    @Environment(\.modelContext) private var context
    @Environment(\.digitStyle) private var digits
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @Query private var tasks: [TaskRecord]
    @Query private var completions: [CompletionRecord]
    @Query private var alarms: [AlarmRecord]
    @State private var runtime: PageRuntime
    @State private var savedFlash = false
    @State private var finishNote: String?

    init(page: PageDefinition, tab: PageTab, sessionRecords: [PageSessionRecord]) {
        self.page = page
        self.tab = tab
        self.sessionRecords = sessionRecords
        let hour = UserDefaults.standard.integer(forKey: SettingsKey.dayStartHour)
        let today = DayKey(date: Date(), calendar: Calendar.app, dayStartHour: hour)
        let existing = PageActions.latestSession(pageID: page.id, tabID: tab.id, day: today, records: sessionRecords)
        let session = existing ?? PageSession(pageID: page.id, tabID: tab.id, day: today)
        _runtime = State(initialValue: PageRuntime(
            session: session,
            history: PageActions.finishedSessions(pageID: page.id, records: sessionRecords)
        ))
    }

    private var finishedKey: Int {
        sessionRecords.filter { $0.pageID == page.id && $0.isFinished }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                statusBar
                if tab.blocks.isEmpty {
                    emptyState
                } else {
                    ForEach(tab.blocks) { block in
                        BlockUseView(block: block, page: page, runtime: runtime, perform: perform)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, Metrics.homeRingDiameter / 2 + 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .bottom) {
            if let finishNote {
                Text(finishNote)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: finishNote)
        .onChange(of: runtime.session) { _, newValue in
            PageActions.upsert(newValue, records: sessionRecords, context: context)
        }
        .onChange(of: finishedKey) { _, _ in
            runtime.history = PageActions.finishedSessions(pageID: page.id, records: sessionRecords)
        }
        .onDisappear {
            runtime.flushStopwatches(now: Date())
            PageActions.upsert(runtime.session, records: sessionRecords, context: context)
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var statusBar: some View {
        let finished = runtime.session.isFinished
        HStack(spacing: 8) {
            Image(systemName: finished ? "checkmark.seal.fill" : "pencil.and.list.clipboard")
                .foregroundStyle(Theme.primaryStrong)
                .accessibilityHidden(true)
            Text(finished ? "الجلسة منتهية ومحفوظة" : "جلسة اليوم (تنحفظ تلقائياً)")
                .font(.footnote.bold())
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if finished {
                Button("جلسة جديدة") { startNewSession() }
                    .font(.footnote.bold())
                    .foregroundStyle(Theme.primaryStrong)
                    .frame(minHeight: 44)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.dashed")
                .font(.largeTitle)
                .foregroundStyle(Theme.primaryStrong)
                .accessibilityHidden(true)
            Text("هذا التبويب فاضي")
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("اضغط القلم فوق لتعديل الصفحة وإضافة قطع.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Actions

    private func startNewSession() {
        let day = DayKey(date: Date(), calendar: Calendar.app, dayStartHour: dayStartHour)
        runtime.session = PageSession(pageID: page.id, tabID: tab.id, day: day)
    }

    private func perform(_ action: ButtonAction) {
        switch action {
        case .finishSession:
            finishSession()
        case .completeTask(let taskID):
            completeTask(taskID)
        case .startTimer(let blockID):
            if let block = page.allBlocks.first(where: { $0.id == blockID }) { runtime.startTimer(block) }
        case .openPage(let pageID):
            router.openPageID = pageID
        case .openAlarm:
            router.selectedTab = .alarms
        case .addSecondaryTask(let title):
            let today = DayKey(date: Date(), calendar: Calendar.app, dayStartHour: dayStartHour)
            PageActions.addSecondaryTask(title: title, tasks: tasks, context: context, today: today)
        case .clearFields:
            runtime.session = PageLogic.cleared(runtime.session)
        }
    }

    private func finishSession() {
        let now = Date()
        runtime.flushStopwatches(now: now)
        var session = PageLogic.pruned(runtime.session, keeping: page)
        if session.finishedAt == nil { session.finishedAt = now }
        runtime.session = session
        PageActions.upsert(session, records: sessionRecords, context: context)
        let note = PageActions.finishNote(pageID: page.id, tasks: tasks, completions: completions, now: now, dayStartHour: dayStartHour)
        switch note {
        case .completed: showFinishNote("انحفظت الجلسة وتمّت المهمة ✓")
        case .alreadyDone: showFinishNote("انحفظت الجلسة. المهمة مكتملة من قبل.")
        case .noLinkedTask: showFinishNote("انحفظت الجلسة. ما فيه مهمة رئيسية مربوطة بالصفحة اليوم.")
        }
        if let outcome = PageActions.completeLinkedTask(
            pageID: page.id, tasks: tasks, completions: completions, context: context, now: now, dayStartHour: dayStartHour
        ) {
            router.celebrate(outcome)
        }
    }

    private func showFinishNote(_ text: String) {
        finishNote = text
        Task {
            try? await Task.sleep(for: .seconds(3))
            if finishNote == text { finishNote = nil }
        }
    }

    private func completeTask(_ taskID: UUID) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        let now = Date()
        let today = DayKey(date: now, calendar: Calendar.app, dayStartHour: dayStartHour)
        if completions.contains(where: { $0.taskID == taskID && $0.day == today }) { return }
        let outcome = TaskActions.toggle(task, on: today, tasks: tasks, completions: completions, context: context, now: now, dayStartHour: dayStartHour)
        router.celebrate(outcome)
    }
}
