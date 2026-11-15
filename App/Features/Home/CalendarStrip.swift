import HabitCore
import SwiftUI

/// A scrollable row of days under the Home header: look back at what was done on past days and ahead at what is
/// scheduled. Tapping a day shows its tasks right under the strip; tapping it again (or today) closes it.
struct CalendarStrip: View {
    let tasks: [TaskRecord]
    let completions: [CompletionRecord]
    let today: DayKey

    @Environment(\.digitStyle) private var digits
    @AppStorage(SettingsKey.hasPrayerLocation) private var hasLocation = false
    @AppStorage(SettingsKey.prayerLatitude) private var latitude = 0.0
    @AppStorage(SettingsKey.prayerLongitude) private var longitude = 0.0
    @AppStorage(SettingsKey.taskShowAllTimes) private var showAllTimes = true
    @AppStorage(SettingsKey.taskFollowsNextRing) private var followsNextRing = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: DayKey?

    private let daysBack = 45
    private let daysAhead = 30

    private var calendar: Calendar { Calendar.app }

    private var days: [DayKey] {
        (-daysBack...daysAhead).compactMap { today.adding(days: $0, calendar: calendar) }
    }

    private var specs: [TaskSpec] { tasks.map(\.spec) }

    private var doneByDay: [String: Set<UUID>] {
        var map: [String: Set<UUID>] = [:]
        for c in completions { map[c.dayISO, default: []].insert(c.taskID) }
        return map
    }

    var body: some View {
        let done = doneByDay
        VStack(spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(days, id: \.self) { day in
                            cell(day, done: done)
                                .id(day)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .onAppear { proxy.scrollTo(today, anchor: .center) }
            }
            // The strip runs edge to edge even though the page has side margins.
            .padding(.horizontal, -20)

            if let selected, selected != today {
                detail(for: selected, done: done[selected.isoString] ?? [])
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .smooth(duration: 0.3), value: selected)
    }

    // MARK: - A day cell

    private func cell(_ day: DayKey, done: [String: Set<UUID>]) -> some View {
        let progress = DayProgress.compute(day: day, specs: specs, completedIDs: done[day.isoString] ?? [], calendar: calendar)
        let isToday = day == today
        let isSelected = (selected ?? today) == day
        let isPast = day < today

        return Button {
            selected = (day == today || selected == day) ? nil : day
        } label: {
            VStack(spacing: 6) {
                Text(weekdayName(day))
                    .font(.caption2.bold())
                Text(digits.format(day.day))
                    .font(.title3.bold().monospacedDigit())
                indicator(progress, isPast: isPast, isToday: isToday)
                    .frame(height: 18)
            }
            .foregroundStyle(isToday ? Color.white : Theme.textPrimary)
            .frame(width: 54, height: 92)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isToday ? Theme.primary : Theme.card)
            )
            .overlay {
                if isSelected && !isToday {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.primaryStrong, lineWidth: 2)
                }
            }
            .opacity(isPast && !isSelected ? 0.85 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText(day, progress: progress, isPast: isPast, isToday: isToday)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Symbol plus shape, never color alone: done = check, some = half circle, nothing done on a past day = cross,
    /// future = the number of tasks, no tasks = a dash.
    @ViewBuilder
    private func indicator(_ progress: DayProgress, isPast: Bool, isToday: Bool) -> some View {
        let tint: Color = isToday ? .white : Theme.primaryStrong
        switch progress.state {
        case .noTasks:
            Image(systemName: "minus").font(.caption.bold()).foregroundStyle(tint.opacity(0.5))
        case .complete:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(tint)
        case .partial:
            Image(systemName: "circle.lefthalf.filled").foregroundStyle(tint)
        case .none:
            if isToday {
                Text(digits.format(progress.total)).font(.caption.bold().monospacedDigit())
            } else if isPast {
                Image(systemName: "xmark.circle").foregroundStyle(Theme.textSecondary)
            } else {
                Text(digits.format(progress.total)).font(.caption.bold().monospacedDigit()).foregroundStyle(tint)
            }
        }
    }

    // MARK: - Detail of a chosen day

    private func detail(for day: DayKey, done: Set<UUID>) -> some View {
        let provider: AdhanPrayerTimes? = hasLocation ? AdhanPrayerTimes(latitude: latitude, longitude: longitude) : nil
        let scheduledUnsorted: [TaskRecord] = tasks.filter { $0.spec.isScheduled(on: day, calendar: calendar) }
        let scheduled: [TaskRecord] = scheduledUnsorted.sortedByDueTime(on: day, provider: provider, calendar: calendar)
        let main = scheduled.filter { $0.kind == .main }
        let isPast = day < today
        let doneMain = main.filter { done.contains($0.id) }.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(fullDate(day)).font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("رجوع لليوم") { selected = nil }
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primaryStrong)
                    .frame(minHeight: 44)
            }
            if scheduled.isEmpty {
                Text(isPast ? "ما كان فيه مهمات هذا اليوم." : "ما عندك مهمات مجدولة هذا اليوم.")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                if !main.isEmpty {
                    Text(isPast
                         ? digits.format("أنجزت \(doneMain) من \(main.count) مهمات رئيسية")
                         : digits.format("\(main.count) مهمات رئيسية مجدولة"))
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.primaryStrong)
                }
                ForEach(scheduled) { task in
                    row(task, isDone: done.contains(task.id), isPast: isPast, day: day, provider: provider)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func row(_ task: TaskRecord, isDone: Bool, isPast: Bool, day: DayKey, provider: PrayerTimeProviding?) -> some View {
        let timeText: String? = TaskTimeText.text(
            for: task, on: day, provider: provider, calendar: calendar, now: Date(),
            showAll: showAllTimes, followsNextRing: followsNextRing, digits: digits
        )
        return HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : (isPast ? "xmark.circle" : "circle"))
                .foregroundStyle(isDone ? Theme.primaryStrong : Theme.textSecondary)
                .accessibilityHidden(true)
            Text(task.title)
                .font(task.kind == .main ? .body.bold() : .body)
                .foregroundStyle(Theme.textPrimary)
                .strikethrough(isDone, color: Theme.textSecondary)
            if task.kind == .secondary {
                Text("فرعية").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            if let timeText {
                Text(timeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(task.title + " — " + (isDone ? String(localized: "تمت") : (isPast ? String(localized: "ما تمت") : String(localized: "مجدولة")))))
    }

    // MARK: - Wording

    private func date(_ day: DayKey) -> Date? { calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) }

    private func weekdayName(_ day: DayKey) -> String {
        guard let date = date(day) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func fullDate(_ day: DayKey) -> String {
        guard let date = date(day) else { return day.isoString }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "EEEE d MMMM"
        return digits.format(f.string(from: date))
    }

    private func accessibilityText(_ day: DayKey, progress: DayProgress, isPast: Bool, isToday: Bool) -> String {
        var text = fullDate(day)
        if isToday { text += "، " + String(localized: "اليوم") }
        switch progress.state {
        case .noTasks: text += "، " + String(localized: "بدون مهمات رئيسية")
        case .complete: text += "، " + String(localized: "أنجزت كل المهمات الرئيسية")
        case .partial: text += "، " + digits.format("أنجزت \(progress.completed) من \(progress.total)")
        case .none:
            text += "، " + (isPast && !isToday ? String(localized: "ما أنجزت مهمات") : digits.format("\(progress.total) مهمات رئيسية"))
        }
        return text
    }
}
