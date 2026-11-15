import HabitCore
import SwiftUI

/// The same schedule editor as alarms (clock or prayer-relative time; once / weekly / monthly), bound to a `PageSchedule`.
/// Returns Form sections, so use it inside a `Form`.
struct ScheduleFields: View {
    @Binding var schedule: PageSchedule

    @Environment(\.digitStyle) private var digits
    @AppStorage(SettingsKey.hasPrayerLocation) private var hasLocation = false

    private enum TimeKind: Hashable { case clock, prayer }
    private enum RepeatKind: Hashable { case once, weekly, monthly }

    // MARK: Time

    private var timeKind: Binding<TimeKind> {
        Binding(
            get: { schedule.time.isPrayerBased ? .prayer : .clock },
            set: { newKind in
                if newKind == .prayer, !schedule.time.isPrayerBased {
                    schedule.time = .prayer(.fajr, .before, hours: 0, minutes: 30)
                } else if newKind == .clock, schedule.time.isPrayerBased {
                    schedule.time = .clock(hour: 7, minute: 0)
                }
            }
        )
    }

    private var clockDate: Binding<Date> {
        Binding(
            get: {
                if case let .clock(hour, minute) = schedule.time {
                    return Calendar.app.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
                }
                return Date()
            },
            set: { date in
                let parts = Calendar.app.dateComponents([.hour, .minute], from: date)
                schedule.time = .clock(hour: parts.hour ?? 7, minute: parts.minute ?? 0)
            }
        )
    }

    private var prayerParts: (Prayer, Direction, Int, Int) {
        if case let .prayer(prayer, direction, hours, minutes) = schedule.time { return (prayer, direction, hours, minutes) }
        return (.fajr, .before, 0, 30)
    }

    private func setPrayer(prayer: Prayer? = nil, direction: Direction? = nil, hours: Int? = nil, minutes: Int? = nil) {
        let current = prayerParts
        schedule.time = .prayer(prayer ?? current.0, direction ?? current.1, hours: hours ?? current.2, minutes: minutes ?? current.3)
    }

    // MARK: Repetition

    private var repeatKind: Binding<RepeatKind> {
        Binding(
            get: {
                switch schedule.repetition {
                case .once: return .once
                case .weekly: return .weekly
                case .monthly: return .monthly
                }
            },
            set: { newKind in
                switch newKind {
                case .once: schedule.repetition = .once(DayKey(date: Date(), calendar: Calendar.app))
                case .weekly: schedule.repetition = .weekly(Set(Weekday.allCases))
                case .monthly: schedule.repetition = .monthly([1])
                }
            }
        )
    }

    private var weekdays: Set<Weekday> {
        if case .weekly(let days) = schedule.repetition { return days }
        return []
    }

    private var monthDays: Set<Int> {
        if case .monthly(let days) = schedule.repetition { return days }
        return []
    }

    private var onceDate: Binding<Date> {
        Binding(
            get: {
                if case .once(let day) = schedule.repetition { return PageValueText.date(of: day) }
                return Date()
            },
            set: { schedule.repetition = .once(DayKey(date: $0, calendar: Calendar.app)) }
        )
    }

    // MARK: Body

    var body: some View {
        Section("وقت الجلسة") {
            Picker("نوع التوقيت", selection: timeKind) {
                Text("توقيت عادي").tag(TimeKind.clock)
                Text("الصلاة").tag(TimeKind.prayer)
            }
            .pickerStyle(.segmented)

            if schedule.time.isPrayerBased {
                prayerControls
            } else {
                DatePicker("الوقت", selection: clockDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
            }
        }

        Section("التكرار") {
            Picker("التكرار", selection: repeatKind) {
                Text("مرة واحدة").tag(RepeatKind.once)
                Text("أسبوعي").tag(RepeatKind.weekly)
                Text("شهري").tag(RepeatKind.monthly)
            }
            .pickerStyle(.segmented)
            repeatDetails
        }
    }

    @ViewBuilder
    private var prayerControls: some View {
        let parts = prayerParts
        Picker("الصلاة", selection: Binding(get: { parts.0 }, set: { setPrayer(prayer: $0) })) {
            ForEach(Prayer.allCases, id: \.self) { Text(AlarmText.name(of: $0)).tag($0) }
        }
        Picker("متى", selection: Binding(get: { parts.1 }, set: { setPrayer(direction: $0) })) {
            Text("قبل").tag(Direction.before)
            Text("بعد").tag(Direction.after)
        }
        .pickerStyle(.segmented)
        Picker("الساعات", selection: Binding(get: { parts.2 }, set: { setPrayer(hours: $0) })) {
            ForEach(0...23, id: \.self) { Text(digits.format($0)).tag($0) }
        }
        Picker("الدقائق", selection: Binding(get: { parts.3 }, set: { setPrayer(minutes: $0) })) {
            ForEach(0...59, id: \.self) { Text(digits.format($0)).tag($0) }
        }
        Text(AlarmText.summary(of: schedule.time, digits: digits))
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
        switch schedule.repetition {
        case .once:
            DatePicker("التاريخ", selection: onceDate, displayedComponents: .date)
        case .weekly:
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                    ForEach(Weekday.allCases, id: \.self) { weekday in
                        ChoiceChip(label: RepetitionText.name(of: weekday), isSelected: weekdays.contains(weekday)) {
                            var days = weekdays
                            if days.contains(weekday) { days.remove(weekday) } else { days.insert(weekday) }
                            if !days.isEmpty { schedule.repetition = .weekly(days) }
                        }
                    }
                }
                Button("كل يوم") { schedule.repetition = .weekly(Set(Weekday.allCases)) }
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
                            var days = monthDays
                            if days.contains(number) { days.remove(number) } else { days.insert(number) }
                            if !days.isEmpty { schedule.repetition = .monthly(days) }
                        }
                    }
                }
                Text("إذا الشهر ما فيه اليوم المختار (مثل 31)، تطلع الجلسة في آخر يوم من الشهر.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
