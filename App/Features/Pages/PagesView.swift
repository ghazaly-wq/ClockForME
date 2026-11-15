import HabitCore
import SwiftData
import SwiftUI

/// "صفحاتي": the list of the owner's custom pages. Opening one shows it in place (with a back button).
struct PagesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.digitStyle) private var digits
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @Query(sort: [SortDescriptor(\PageRecord.sortOrder), SortDescriptor(\PageRecord.createdAt)])
    private var allRecords: [PageRecord]

    @State private var openID: UUID?
    @State private var showNew = false

    private var pages: [PageRecord] { allRecords.filter { !$0.isTemplate } }

    var body: some View {
        Group {
            if let openID, let record = pages.first(where: { $0.id == openID }) {
                PageDetailView(record: record, onBack: { self.openID = nil }, onOpen: { self.openID = $0 })
                    .id(record.id)
            } else {
                list
            }
        }
        // Alarms, tasks and links can ask to open a page.
        .onChange(of: router.openPageID, initial: true) { _, newValue in
            if let newValue {
                openID = newValue
                router.openPageID = nil
            }
        }
        .sheet(isPresented: $showNew) {
            NewPageSheet { id in
                openID = id
            }
            .appRoot()
        }
    }

    // MARK: - List

    private var list: some View {
        CurvedPage(title: "صفحاتي", onAdd: { showNew = true }) {
            if pages.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(pages) { record in
                        pageCard(record.definition)
                    }
                }
            }
        }
    }

    private func pageCard(_ page: PageDefinition) -> some View {
        let calendar = Calendar.app
        let today = DayKey(date: Date(), calendar: calendar, dayStartHour: dayStartHour)
        let accent = PageAccent(name: page.accent).color
        var lines: [String] = []
        if let schedule = page.schedule {
            lines.append(RepetitionText.summary(of: schedule.repetition, digits: digits) + " · " + AlarmText.summary(of: schedule.time, digits: digits))
        } else {
            lines.append("بدون موعد")
        }
        if page.rotatesTabs, let tab = PageLogic.tab(for: today, page: page, calendar: calendar) {
            lines.append("جلسة اليوم: " + tab.name)
        } else if page.tabs.count > 1 {
            lines.append(digits.format("\(page.tabs.count) تبويبات"))
        }
        let isToday = PageLogic.isScheduled(page, on: today, calendar: calendar)

        return Button { openID = page.id } label: {
            HStack(spacing: 14) {
                Text(page.emoji)
                    .font(.system(size: 30))
                    .frame(width: 56, height: 56)
                    .background(accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(page.name)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        if isToday {
                            Label("اليوم", systemImage: "calendar")
                                .font(.caption2.bold())
                                .foregroundStyle(Theme.primaryStrong)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .overlay(Capsule().stroke(Theme.primaryStrong, lineWidth: 1))
                        }
                        if page.isMainTask {
                            Label("مهمة رئيسية", systemImage: "star.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(Theme.primaryStrong)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .overlay(Capsule().stroke(Theme.primaryStrong, lineWidth: 1))
                        }
                    }
                    ForEach(lines, id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(minHeight: 44)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 4).padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundStyle(Theme.primaryStrong)
                .accessibilityHidden(true)
            Text("ما عندك صفحات")
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("ابنِ صفحتك الخاصة (تمارين، قراءة، ماء...) من قطع تركبها بنفسك، وسجّل فيها كل يوم.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button { showNew = true } label: {
                Label("إضافة صفحة", systemImage: "plus")
                    .font(.headline)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}

/// New page: blank, a built-in template, or one of his saved templates.
struct NewPageSheet: View {
    let onCreate: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @Query(sort: \PageRecord.createdAt) private var allRecords: [PageRecord]

    private var today: DayKey {
        DayKey(date: Date(), calendar: Calendar.app, dayStartHour: dayStartHour)
    }

    private func create(_ definition: PageDefinition) {
        let record = PageActions.create(definition, in: context, existing: allRecords.filter { !$0.isTemplate }, today: today)
        dismiss()
        onCreate(record.id)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { create(PageTemplates.blank()) } label: {
                        Label("صفحة فارغة", systemImage: "square.dashed")
                            .foregroundStyle(Theme.textPrimary)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
                Section("قوالب جاهزة") {
                    ForEach(PageTemplates.all) { info in
                        Button {
                            if let page = PageTemplates.make(info.id) { create(page) }
                        } label: {
                            templateRow(emoji: info.emoji, name: info.name, summary: info.summary)
                        }
                    }
                }
                let mine = allRecords.filter { $0.isTemplate }
                if !mine.isEmpty {
                    Section("قوالبي") {
                        ForEach(mine) { record in
                            let page = record.definition
                            Button {
                                create(PageActions.instantiate(page))
                            } label: {
                                templateRow(emoji: page.emoji, name: page.name, summary: "قالب محفوظ")
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(mine[index]) }
                            try? context.save()
                        }
                    }
                }
            }
            .navigationTitle("صفحة جديدة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func templateRow(emoji: String, name: String, summary: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline).foregroundStyle(Theme.textPrimary)
                Text(summary).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44)
    }
}
