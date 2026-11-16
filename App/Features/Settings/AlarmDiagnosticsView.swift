import AlarmKit
import HabitCore
import SwiftUI

/// Shows what the alarm system really holds, so a problem ("the chain doesn't ring") can be seen instead of guessed.
struct AlarmDiagnosticsView: View {
    @State private var report = AlarmScheduler.lastReport()
    @State private var alarms: [Alarm] = []
    @State private var ledger = AlarmScheduler.challengeLedger()
    @State private var authorized = false
    @State private var busy = false

    var body: some View {
        List {
            Section("الإذن") {
                LabeledContent("إذن المنبهات") { Text(authorized ? "مفعّل" : "غير مفعّل") }
            }

            Section("آخر جدولة") {
                if let report {
                    LabeledContent("الوقت") { Text(report.date.formatted(date: .omitted, time: .standard)) }
                    LabeledContent("المطلوب") { Text("\(report.wanted)") }
                    LabeledContent("كانت جاهزة") { Text("\(report.alreadyScheduled)") }
                    LabeledContent("انضافت الحين") { Text("\(report.scheduledNow)") }
                    LabeledContent("منها سلسلة تحدي") { Text("\(report.chainScheduledNow) من \(report.chainWanted)") }
                    LabeledContent("أُزيلت لإفساح المجال") { Text("\(report.droppedForRoom)") }
                    LabeledContent("بُدّلت لمنبه عادي") { Text("\(report.fellBackToClassic)") }
                    LabeledContent("وصلنا حد النظام") { Text(report.limitReached ? "نعم" : "لا") }
                    ForEach(Array(report.failures.enumerated()), id: \.offset) { _, text in
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                            .textSelection(.enabled)
                    }
                } else {
                    Text("ما صارت جدولة بعد.")
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Section {
                if ledger.entries.isEmpty {
                    Text("ما فيه رنات تحدي مسجّلة.")
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(ledger.entries) { entry in
                    HStack {
                        Text(entry.fireDate.formatted(date: .abbreviated, time: .standard))
                        Spacer()
                        Text(ledger.isCompleted(entry.key) ? "تم" : "ينتظر")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .font(.caption)
                }
            } header: {
                Text("رنات التحدي")
            }

            Section {
                if alarms.isEmpty {
                    Text("ما فيه منبهات مجدولة في النظام.")
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(alarms.sorted { sortDate($0) < sortDate($1) }) { alarm in
                    HStack {
                        if case .fixed(let date)? = alarm.schedule {
                            Text(date.formatted(date: .abbreviated, time: .standard))
                        } else {
                            Text("بدون وقت ثابت")
                        }
                        Spacer()
                        if AlarmScheduler.occurrenceOwner(of: alarm.id) != nil { Text("تحدي") }
                        Text(String(describing: alarm.state))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .font(.caption)
                }
            } header: {
                Text("المنبهات في النظام (\(alarms.count))")
            }

            Section {
                Button {
                    Task {
                        busy = true
                        await AlarmActions.replan(container: AppEnvironment.shared.container)
                        refresh()
                        busy = false
                    }
                } label: {
                    Text(busy ? "جاري إعادة الجدولة…" : "إعادة الجدولة الآن")
                }
                .disabled(busy)
                .frame(minHeight: 44)
            }
        }
        .navigationTitle("تشخيص المنبهات")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private func sortDate(_ alarm: Alarm) -> Date {
        if case .fixed(let date)? = alarm.schedule { return date }
        return .distantFuture
    }

    private func refresh() {
        report = AlarmScheduler.lastReport()
        ledger = AlarmScheduler.challengeLedger()
        authorized = AlarmManager.shared.authorizationState == .authorized
        alarms = (try? AlarmManager.shared.alarms) ?? []
    }
}
