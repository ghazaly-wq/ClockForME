import HabitCore
import SwiftData
import SwiftUI

enum AlarmEditorTarget: Identifiable {
    case new
    case edit(AlarmRecord)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let alarm): return alarm.id.uuidString
        }
    }
}

struct AlarmEditorView: View {
    let target: AlarmEditorTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.digitStyle) private var digits
    @AppStorage(SettingsKey.hasPrayerLocation) private var hasLocation = false
    @Query private var allTasks: [TaskRecord]
    @Query private var completions: [CompletionRecord]

    enum TimeKind: Hashable { case clock, prayer }
    enum RepeatKind: Hashable { case once, weekly, monthly }

    @State private var title = ""
    @State private var note = ""
    @State private var timeKind: TimeKind = .clock
    @State private var clockTime = Date()
    @State private var prayer: Prayer = .fajr
    @State private var direction: Direction = .before
    @State private var offsetHours = 0
    @State private var offsetMinutes = 30
    @State private var repeatKind: RepeatKind = .weekly
    @State private var date = Date()
    @State private var weekdays: Set<Weekday> = Set(Weekday.allCases)
    @State private var monthDays: Set<Int> = [1]
    @State private var isMainTask = false
    @State private var showUnlinkDialog = false

    init(target: AlarmEditorTarget) {
        self.target = target
        let calendar = Calendar.app
        if case .new = target {
            let base = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
            _clockTime = State(initialValue: base)
        }
        guard case .edit(let alarm) = target else { return }
        _title = State(initialValue: alarm.title)
        _note = State(initialValue: alarm.note)
        _isMainTask = State(initialValue: alarm.isMainTask)
        switch alarm.time {
        case let .clock(hour, minute):
            _timeKind = State(initialValue: .clock)
            _clockTime = State(initialValue: calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date())
        case let .prayer(prayer, direction, hours, minutes):
            _timeKind = State(initialValue: .prayer)
            _prayer = State(initialValue: prayer)
            _direction = State(initialValue: direction)
            _offsetHours = State(initialValue: hours)
            _offsetMinutes = State(initialValue: minutes)
        }
        switch alarm.repetition {
        case .once(let day):
            _repeatKind = State(initialValue: .once)
            _date = State(initialValue: calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? Date())
        case .weekly(let days):
            _repeatKind = State(initialValue: .weekly)
            _weekdays = State(initialValue: days)
        case .monthly(let days):
            _repeatKind = State(initialValue: .monthly)
            _monthDays = State(initialValue: days)
        }
    }

    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    private var canSave: Bool {
        switch repeatKind {
        case .weekly: return !weekdays.isEmpty
        case .monthly: return !monthDays.isEmpty
        case .once: return true
        }
    }

    private var timeSpec: TimeSpec {
        switch timeKind {
        case .clock:
            let parts = Calendar.app.dateComponents([.hour, .minute], from: clockTime)
            return .clock(hour: parts.hour ?? 7, minute: parts.minute ?? 0)
        case .prayer:
            return .prayer(prayer, direction, hours: offsetHours, minutes: offsetMinutes)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("نوع التوقيت", selection: $timeKind) {
                        Text("توقيت عادي").tag(TimeKind.clock)
                        Text("الصلاة").tag(TimeKind.prayer)
                    }
                    .pickerStyle(.segmented)

                    switch timeKind {
                    case .clock:
                        DatePicker("الوقت", selection: $clockTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    case .prayer:
                        prayerControls
                    }
                }

                Section("التكرار") {
                    Picker("التكرار", selection: $repeatKind) {
                        Text("مرة واحدة").tag(RepeatKind.once)
                        Text("أسبوعي").tag(RepeatKind.weekly)
                        Text("شهري").tag(RepeatKind.monthly)
                    }
                    .pickerStyle(.segmented)
                    repeatDetails
                }

                Section {
                    TextField("اسم التنبيه", text: $title)
                    TextField("ملاحظة (اختياري)", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    Toggle("هل هذا التنبيه لمهمة رئيسية؟", isOn: $isMainTask)
                } footer: {
                    Text(isMainTask
                         ? "تنضاف مهمة رئيسية بنفس الاسم والتكرار، وفي الإشعار زر \"تم\" يكمّلها لك."
                         : "التنبيه العادي يرن فقط، وما يرتبط بالمهمات.")
                }
            }
            .navigationTitle(isEditing ? "تعديل التنبيه" : "تنبيه جديد")
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
            .confirmationDialog("المهمة المرتبطة بهذا التنبيه", isPresented: $showUnlinkDialog, titleVisibility: .visible) {
                Button("حذف المهمة", role: .destructive) { commit(deleteLinkedTask: true) }
                Button("إبقاؤها كمهمة عادية") { commit(deleteLinkedTask: false) }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("هذا التنبيه كان مرتبطاً بمهمة رئيسية. وش تبي نسوي فيها؟")
            }
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var prayerControls: some View {
        Picker("الصلاة", selection: $prayer) {
            ForEach(Prayer.allCases, id: \.self) { prayer in
                Text(AlarmText.name(of: prayer)).tag(prayer)
            }
        }
        Picker("متى", selection: $direction) {
            Text("قبل").tag(Direction.before)
            Text("بعد").tag(Direction.after)
        }
        .pickerStyle(.segmented)
        Picker("الساعات", selection: $offsetHours) {
            ForEach(0...23, id: \.self) { Text(digits.format($0)).tag($0) }
        }
        Picker("الدقائق", selection: $offsetMinutes) {
            ForEach(0...59, id: \.self) { Text(digits.format($0)).tag($0) }
        }
        Text(AlarmText.summary(of: timeSpec, digits: digits))
            .font(.callout.bold())
            .foregroundStyle(Theme.primaryStrong)
        if !hasLocation {
            NavigationLink {
                PrayerSettingsView()
            } label: {
                Label("حدد موقعك لتُحسب أوقات الصلاة", systemImage: "location.slash")
            }
        }
    }

    @ViewBuilder
    private var repeatDetails: some View {
        switch repeatKind {
        case .once:
            DatePicker(
                "التاريخ",
                selection: $date,
                in: (isEditing ? Date.distantPast : Calendar.app.startOfDay(for: Date()))...Date.distantFuture,
                displayedComponents: .date
            )
        case .weekly:
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                    ForEach(Weekday.allCases, id: \.self) { weekday in
                        ChoiceChip(label: RepetitionText.name(of: weekday), isSelected: weekdays.contains(weekday)) {
                            if weekdays.contains(weekday) { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
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
                            if monthDays.contains(number) { monthDays.remove(number) } else { monthDays.insert(number) }
                        }
                    }
                }
                Text("إذا الشهر ما فيه اليوم المختار (مثل 31)، يرن التنبيه في آخر يوم من الشهر.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: - Saving

    private func save() {
        if case .edit(let alarm) = target, alarm.isMainTask, !isMainTask,
           AlarmActions.hasLinkedTask(alarm, tasks: allTasks) {
            showUnlinkDialog = true
            return
        }
        commit(deleteLinkedTask: nil)
    }

    private func commit(deleteLinkedTask: Bool?) {
        let calendar = Calendar.app
        let today = DayKey(date: Date(), calendar: calendar, dayStartHour: UserDefaults.standard.integer(forKey: SettingsKey.dayStartHour))
        let repetition: Repetition
        switch repeatKind {
        case .once: repetition = .once(DayKey(date: date, calendar: calendar))
        case .weekly: repetition = .weekly(weekdays)
        case .monthly: repetition = .monthly(monthDays)
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var rule = AlarmRule(
            title: trimmed.isEmpty ? String(localized: "تنبيه") : trimmed,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: true,
            repetition: repetition,
            time: timeSpec,
            isMainTask: isMainTask
        )

        let record: AlarmRecord
        switch target {
        case .new:
            record = AlarmRecord(rule: rule)
            context.insert(record)
        case .edit(let alarm):
            rule.id = alarm.id
            alarm.apply(rule)
            record = alarm
        }
        try? context.save()

        if rule.isMainTask {
            AlarmActions.syncLinkedTask(for: record, tasks: allTasks, completions: completions, context: context, today: today)
        } else if let deleteLinkedTask {
            AlarmActions.unlinkTask(of: record, deleteTask: deleteLinkedTask, tasks: allTasks, completions: completions, context: context, today: today)
        }

        Task { @MainActor in await AlarmActions.requestAndReplan() }
        dismiss()
    }
}
