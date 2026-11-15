import HabitCore
import SwiftData
import SwiftUI

/// One custom page: header with the use / edit toggle, tab chips, and the matching content.
struct PageDetailView: View {
    let record: PageRecord
    let onBack: () -> Void
    /// Called with the id of a page that was just created (duplicate) so the list can open it.
    let onOpen: (UUID) -> Void

    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @Query private var alarms: [AlarmRecord]
    @Query private var tasks: [TaskRecord]
    @Query private var completions: [CompletionRecord]
    @Query private var sessions: [PageSessionRecord]
    @Query private var pageRecords: [PageRecord]

    private enum Mode { case use, edit }

    @State private var mode: Mode = .use
    @State private var selectedTabID: UUID?
    @State private var showSettings = false

    private var pageBinding: Binding<PageDefinition> {
        Binding(get: { record.definition }, set: { record.definition = $0 })
    }

    private var today: DayKey {
        DayKey(date: Date(), calendar: Calendar.app, dayStartHour: dayStartHour)
    }

    var body: some View {
        let page = record.definition
        let rotationTab = page.rotatesTabs ? PageLogic.tab(for: today, page: page, calendar: Calendar.app) : nil
        let validSelected = selectedTabID.flatMap { id in page.tabs.contains { $0.id == id } ? id : nil }
        let activeTabID = validSelected ?? rotationTab?.id ?? page.tabs.first?.id

        CurvedPage(
            title: LocalizedStringKey(page.name),
            subtitle: page.emoji,
            scrollable: false,
            onBack: onBack,
            extraButtons: [
                HeaderButton(symbol: mode == .use ? "pencil" : "checkmark", label: mode == .use ? "تعديل" : "تم") {
                    mode = mode == .use ? .edit : .use
                },
                HeaderButton(symbol: "slider.horizontal.3", label: "إعدادات الصفحة") { showSettings = true }
            ]
        ) {
            VStack(spacing: 0) {
                if page.tabs.count > 1 { tabBar(page: page, activeID: activeTabID, rotationID: rotationTab?.id) }
                if let activeTabID, let tab = page.tab(withID: activeTabID) {
                    switch mode {
                    case .use:
                        PageUseView(page: page, tab: tab, sessionRecords: sessions.filter { $0.pageID == page.id })
                            .id(tab.id)
                            .transition(.opacity)
                    case .edit:
                        PageEditView(page: pageBinding, tabID: tab.id)
                            .id(tab.id)
                            .transition(.opacity)
                    }
                }
            }
            .appAnimation(value: mode)
            .appAnimation(value: activeTabID)
        }
        .sheet(isPresented: $showSettings, onDismiss: saveLinks) {
            PageSettingsView(
                page: pageBinding,
                onDuplicate: duplicate,
                onSaveTemplate: { PageActions.saveAsTemplate(record.definition, in: context) },
                onDelete: delete
            )
            .appRoot()
        }
    }

    private func tabBar(page: PageDefinition, activeID: UUID?, rotationID: UUID?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(page.tabs) { tab in
                    ChoiceChip(
                        label: tab.id == rotationID ? tab.name + " · اليوم" : tab.name,
                        isSelected: tab.id == activeID
                    ) { selectedTabID = tab.id }
                    .frame(minWidth: 110)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Actions

    /// After the settings sheet: keep the page's alarm and main task in step with its schedule.
    private func saveLinks() {
        PageActions.save(
            record.definition, record: record,
            alarms: alarms, tasks: tasks, completions: completions, context: context, today: today
        )
    }

    private func duplicate() {
        var copy = PageActions.instantiate(record.definition)
        copy.name = record.definition.name + " (نسخة)"
        let created = PageActions.create(copy, in: context, existing: pageRecords.filter { !$0.isTemplate }, today: today)
        onOpen(created.id)
    }

    private func delete(everything: Bool) {
        let id = record.id
        let day = today
        showSettings = false
        onBack()
        // Let the list replace this view before the record disappears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let alarms = (try? context.fetch(FetchDescriptor<AlarmRecord>())) ?? []
            let tasks = (try? context.fetch(FetchDescriptor<TaskRecord>())) ?? []
            let completions = (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? []
            let sessions = (try? context.fetch(FetchDescriptor<PageSessionRecord>())) ?? []
            let records = (try? context.fetch(FetchDescriptor<PageRecord>())) ?? []
            guard let target = records.first(where: { $0.id == id }) else { return }
            PageActions.delete(
                target, everything: everything,
                alarms: alarms, tasks: tasks, completions: completions, sessions: sessions,
                context: context, today: day
            )
        }
    }
}
