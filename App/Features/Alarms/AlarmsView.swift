import HabitCore
import SwiftData
import SwiftUI
import UIKit
import AlarmKit

struct AlarmsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.digitStyle) private var digits
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.hasPrayerLocation) private var hasLocation = false
    @AppStorage(SettingsKey.prayerLatitude) private var latitude = 0.0
    @AppStorage(SettingsKey.prayerLongitude) private var longitude = 0.0
    @Query(sort: \AlarmRecord.createdAt) private var alarms: [AlarmRecord]

    @State private var now = Date()
    @State private var editor: AlarmEditorTarget?
    @State private var authStatus: AlarmManager.AuthorizationState?
    @State private var undoToken: DeletedAlarmSnapshot?
    @State private var undoDismiss: Task<Void, Never>?

    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var provider: AdhanPrayerTimes? {
        hasLocation ? AdhanPrayerTimes(latitude: latitude, longitude: longitude) : nil
    }

    var body: some View {
        let calendar = Calendar.app
        let today = DayKey(date: now, calendar: calendar)
        let entries = alarms.map { Entry(alarm: $0, shownAt: shownTime(of: $0, calendar: calendar), todayFire: todayFire(of: $0, today: today, calendar: calendar)) }
        let todayEntries = entries
            .filter { $0.alarm.isEnabled && $0.todayFire != nil }
            .sorted { ($0.todayFire ?? .distantFuture) < ($1.todayFire ?? .distantFuture) }
        let allEntries = entries.sorted { sortKey($0.shownAt, calendar) < sortKey($1.shownAt, calendar) }
        let needsLocation = !hasLocation && alarms.contains { $0.isEnabled && $0.time.isPrayerBased }

        CurvedPage(title: "التنبيهات", scrollable: false, onAdd: { editor = .new }) {
            List {
                if authStatus == .denied {
                    banner(
                        text: "إذن المنبهات متوقف، فما راح ترن تنبيهاتك.",
                        button: "فتح إعدادات الجهاز"
                    ) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                if needsLocation {
                    banner(
                        text: "عندك تنبيهات مرتبطة بالصلاة، لكن ما حددت موقعك.",
                        button: "تحديد الموقع"
                    ) { router.showSettings = true }
                }

                if alarms.isEmpty {
                    Section {
                        emptyState
                    }
                    .listRowBackground(Color.clear)
                } else {
                    if !todayEntries.isEmpty {
                        Section("اليوم") {
                            ForEach(todayEntries, id: \.alarm.id) { row($0) }
                        }
                        .listRowBackground(Theme.card)
                    }
                    Section("كل التنبيهات") {
                        ForEach(allEntries, id: \.alarm.id) { row($0) }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, Metrics.homeRingDiameter / 2 + 8, for: .scrollContent)
        }
        .overlay(alignment: .bottom) {
            if let undoToken { undoToast(undoToken) }
        }
        .animation(.spring(duration: 0.3), value: undoToken != nil)
        .sheet(item: $editor) { target in
            AlarmEditorView(target: target)
                .appRoot()
        }
        .task(id: scenePhase) {
            authStatus = AlarmScheduler.authorizationState
            AlarmActions.expireFinished(context: context)
        }
        .onReceive(ticker) { date in
            now = date
            authStatus = AlarmScheduler.authorizationState
            AlarmActions.expireFinished(context: context, now: date)
        }
    }

    // MARK: - Rows

    private struct Entry {
        let alarm: AlarmRecord
        /// The time shown large (a prayer alarm's time depends on the location). Nil = unknown.
        let shownAt: Date?
        /// When it rings today, if it does.
        let todayFire: Date?
    }

    private func row(_ entry: Entry) -> some View {
        let alarm = entry.alarm
        let timeText: String
        switch alarm.time {
        case let .clock(hour, minute):
            timeText = AlarmText.clockText(hour: hour, minute: minute, digits: digits)
        case .prayer:
            timeText = entry.shownAt.map { AlarmText.time($0, digits: digits) } ?? "—"
        }
        let detail = alarm.time.isPrayerBased
            ? AlarmText.summary(of: alarm.time, digits: digits) + " · " + RepetitionText.summary(of: alarm.repetition, digits: digits)
            : RepetitionText.summary(of: alarm.repetition, digits: digits)

        return HStack(spacing: 8) {
            Button { editor = .edit(alarm) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeText)
                        .font(.system(size: 38, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 6) {
                        Text(alarm.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.textPrimary)
                        if alarm.isMainTask {
                            Label("مهمة رئيسية", systemImage: "star.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(Theme.primaryStrong)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .overlay(Capsule().stroke(Theme.primaryStrong, lineWidth: 1))
                        }
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    if alarm.time.isPrayerBased, alarm.isEnabled, let next = nextRing(of: alarm) {
                        Text(String(localized: "الرنة القادمة: ") + nextRingText(next))
                            .font(.caption)
                            .foregroundStyle(Theme.primaryStrong)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("اضغط للتعديل"))

            Toggle(alarm.title, isOn: enabledBinding(alarm))
                .labelsHidden()
        }
        .opacity(alarm.isEnabled ? 1 : 0.45)
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                showUndo(AlarmActions.delete(alarm, context: context))
            } label: {
                Label("حذف", systemImage: "trash")
            }
            Button { editor = .edit(alarm) } label: {
                Label("تعديل", systemImage: "pencil")
            }
            .tint(Theme.textSecondary)
        }
    }

    private func enabledBinding(_ alarm: AlarmRecord) -> Binding<Bool> {
        Binding(
            get: { alarm.isEnabled },
            set: { newValue in
                alarm.isEnabled = newValue
                try? context.save()
                Task { @MainActor in await AlarmActions.requestAndReplan() }
            }
        )
    }

    private func banner(text: LocalizedStringKey, button: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(Theme.textPrimary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.gold)
                }
                Button(button, action: action)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primaryStrong)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
        .listRowBackground(Theme.card)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "alarm")
                .font(.largeTitle)
                .foregroundStyle(Theme.primaryStrong)
                .accessibilityHidden(true)
            Text("ما عندك تنبيهات — أضف أول تنبيه")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
            Button("إضافة تنبيه") { editor = .new }
                .buttonStyle(.borderedProminent)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Times

    /// The time of day an alarm shows in the list (ignores which days it repeats on).
    private func shownTime(of alarm: AlarmRecord, calendar: Calendar) -> Date? {
        var rule = alarm.rule
        rule.repetition = .daily
        return NotificationPlanner.fireDate(of: rule, on: DayKey(date: now, calendar: calendar), provider: provider, calendar: calendar)
    }

    private func todayFire(of alarm: AlarmRecord, today: DayKey, calendar: Calendar) -> Date? {
        NotificationPlanner.fireDate(of: alarm.rule, on: today, provider: provider, calendar: calendar)
    }

    /// The next moment this alarm will ring (prayer alarms move a little every day).
    private func nextRing(of alarm: AlarmRecord) -> Date? {
        NotificationPlanner.plan(alarms: [alarm.rule], from: now, limit: 1, provider: provider, calendar: Calendar.app).first?.fireDate
    }

    private func nextRingText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = Calendar.app.timeZone
        formatter.dateFormat = "EEEE h:mm a"
        return digits.format(formatter.string(from: date))
    }

    private func sortKey(_ date: Date?, _ calendar: Calendar) -> Int {
        guard let date else { return Int.max }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    // MARK: - Undo

    private func undoToast(_ token: DeletedAlarmSnapshot) -> some View {
        HStack(spacing: 12) {
            Text("تم حذف التنبيه")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary)
            Button("تراجع") {
                AlarmActions.undoDelete(token, context: context)
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

    private func showUndo(_ token: DeletedAlarmSnapshot) {
        undoToken = token
        AccessibilityNotification.Announcement(String(localized: "تم حذف التنبيه")).post()
        undoDismiss?.cancel()
        undoDismiss = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { undoToken = nil }
        }
    }
}
