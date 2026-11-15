import HabitCore
import SwiftData
import SwiftUI

struct TaskEditorView: View {
    let target: EditorTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.digitStyle) private var digits
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @Query private var completions: [CompletionRecord]
    @Query private var allTasks: [TaskRecord]

    enum ScheduleType: Hashable {
        case once, weekly, monthly, anytime
    }

    @State private var title = ""
    @State private var kind: TaskKind = .main
    @State private var scheduleType: ScheduleType = .once
    @State private var date = Date()
    @State private var weekdays: Set<Weekday> = Set(Weekday.allCases)
    @State private var monthDays: Set<Int> = [1]
    @State private var notes = ""

    init(target: EditorTarget) {
        self.target = target
        switch target {
        case .new(let kind):
            _kind = State(initialValue: kind)
        case .edit(let task):
            _title = State(initialValue: task.title)
            _kind = State(initialValue: task.kind)
            _notes = State(initialValue: task.notes)
            switch task.repetition {
            case nil:
                _scheduleType = State(initialValue: .anytime)
            case .once(let day)?:
                _scheduleType = State(initialValue: .once)
                let parts = DateComponents(year: day.year, month: day.month, day: day.day)
                _date = State(initialValue: Calendar.app.date(from: parts) ?? Date())
            case .weekly(let days)?:
                _scheduleType = State(initialValue: .weekly)
                _weekdays = State(initialValue: days)
            case .monthly(let days)?:
                _scheduleType = State(initialValue: .monthly)
                _monthDays = State(initialValue: days)
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    private var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch scheduleType {
        case .weekly: return !weekdays.isEmpty
        case .monthly: return !monthDays.isEmpty
        case .once, .anytime: return true
        }
    }

    /// New one-off tasks can't be dated in the past.
    private var dateRange: ClosedRange<Date> {
        let lower = isEditing ? Date.distantPast : Calendar.app.startOfDay(for: Date())
        return lower...Date.distantFuture
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("اسم المهمة", text: $title)
                }

                Section("النوع") {
                    Picker("النوع", selection: $kind) {
                        Text("رئيسية").tag(TaskKind.main)
                        Text("فرعية").tag(TaskKind.secondary)
                    }
                    .pickerStyle(.segmented)
                    Text(kind == .main
                         ? "الرئيسية تحسب في الستريك وتظهر في شريط يومك."
                         : "الفرعية تعطي نفس الخبرة، لكن ما تأثر على الستريك.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Section("التكرار") {
                    Picker("التكرار", selection: $scheduleType) {
                        Text("مرة واحدة").tag(ScheduleType.once)
                        Text("أسبوعي").tag(ScheduleType.weekly)
                        Text("شهري").tag(ScheduleType.monthly)
                        if kind == .secondary {
                            Text("بدون موعد").tag(ScheduleType.anytime)
                        }
                    }
                    .pickerStyle(.segmented)
                    scheduleDetails
                }

                Section("ملاحظات") {
                    TextField("ملاحظات (اختياري)", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(isEditing ? "تعديل المهمة" : "مهمة جديدة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: kind) { _, newKind in
                if newKind == .main && scheduleType == .anytime { scheduleType = .once }
            }
        }
    }

    // MARK: - Schedule details

    @ViewBuilder
    private var scheduleDetails: some View {
        switch scheduleType {
        case .once:
            DatePicker("التاريخ", selection: $date, in: dateRange, displayedComponents: .date)
        case .weekly:
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                    ForEach(Weekday.allCases, id: \.self) { weekday in
                        ChoiceChip(label: RepetitionText.name(of: weekday), isSelected: weekdays.contains(weekday)) {
                            if weekdays.contains(weekday) {
                                weekdays.remove(weekday)
                            } else {
                                weekdays.insert(weekday)
                            }
                        }
                    }
                }
                Button("كل يوم") { weekdays = Set(Weekday.allCases) }
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primaryStrong)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            }
        case .monthly:
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(1...31, id: \.self) { number in
                        ChoiceChip(label: digits.format(number), isSelected: monthDays.contains(number)) {
                            if monthDays.contains(number) {
                                monthDays.remove(number)
                            } else {
                                monthDays.insert(number)
                            }
                        }
                    }
                }
                Text("إذا الشهر ما فيه اليوم المختار (مثل 31)، تنفذ المهمة في آخر يوم من الشهر.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        case .anytime:
            Text("تظهر المهمة لين تنجزها، وما تأثر على الستريك.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Saving

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.app
        let today = DayKey(date: Date(), calendar: calendar, dayStartHour: dayStartHour)

        let repetition: Repetition?
        switch scheduleType {
        case .once: repetition = .once(DayKey(date: date, calendar: calendar))
        case .weekly: repetition = .weekly(weekdays)
        case .monthly: repetition = .monthly(monthDays)
        case .anytime: repetition = nil
        }

        var start = today
        if case .once(let day)? = repetition { start = day }
        let nextOrder = (allTasks.map(\.sortOrder).max() ?? -1) + 1

        switch target {
        case .new:
            context.insert(TaskRecord(title: trimmed, kind: kind, repetition: repetition, startDay: start, notes: notes, sortOrder: nextOrder))
        case .edit(let task):
            let hasHistory = completions.contains { $0.taskID == task.id }
            let scheduleChanged = task.kind != kind || task.repetition != repetition
            if hasHistory && scheduleChanged {
                // Keep past days exactly as they were: stop the old task today and start a new one.
                task.endDay = today
                context.insert(TaskRecord(title: trimmed, kind: kind, repetition: repetition, startDay: start, notes: notes, sortOrder: task.sortOrder))
            } else {
                task.title = trimmed
                task.kind = kind
                task.repetition = repetition
                task.notes = notes
                if case .once(let day)? = repetition {
                    task.startDay = day
                } else {
                    task.startDay = min(task.startDay, today)
                }
            }
        }
        try? context.save()
        dismiss()
    }
}
