import HabitCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.digitStyle) private var digitRaw = DigitStyle.western.rawValue
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @AppStorage(SettingsKey.liveActivityEnabled) private var liveEnabled = true
    @AppStorage(SettingsKey.liveActivityAutoStart) private var liveAutoStart = true
    @AppStorage(SettingsKey.morningEnabled) private var morningEnabled = false
    @AppStorage(SettingsKey.morningHour) private var morningHour = 7
    @AppStorage(SettingsKey.morningMinute) private var morningMinute = 0

    private var digits: DigitStyle { DigitStyle(storedValue: digitRaw) }

    var body: some View {
        NavigationStack {
            Form {
                Section("المظهر") {
                    Picker("المظهر", selection: $appearanceRaw) {
                        Text("تلقائي").tag(AppearanceMode.system.rawValue)
                        Text("فاتح").tag(AppearanceMode.light.rawValue)
                        Text("داكن").tag(AppearanceMode.dark.rawValue)
                    }
                    .pickerStyle(.segmented)
                }

                Section("الأرقام") {
                    Picker("الأرقام", selection: $digitRaw) {
                        Text("123").tag(DigitStyle.western.rawValue)
                        Text("١٢٣").tag(DigitStyle.arabicIndic.rawValue)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker("بداية اليوم", selection: $dayStartHour) {
                        ForEach(0...8, id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                } header: {
                    Text("اليوم")
                } footer: {
                    Text(digits.format(String(localized: "الساعة اللي يبدأ فيها يومك الجديد. مثلاً لو اخترت 03:00، المهمات اللي تنجزها بعد منتصف الليل تحسب لليوم السابق.")))
                }

                Section("المنبه") {
                    NavigationLink("صوت المنبه") { AlarmSoundView() }
                }

                Section {
                    NavigationLink("الصلاة والموقع") { PrayerSettingsView() }
                    TodayPrayersRows()
                } header: {
                    Text("أوقات الصلاة اليوم")
                }

                Section {
                    Toggle("عرض المهمات على شاشة القفل", isOn: $liveEnabled)
                    Toggle("يبدأ تلقائياً عند فتح التطبيق", isOn: $liveAutoStart)
                        .disabled(!liveEnabled)
                    Toggle("تذكير «ابدأ يومك» كل صباح", isOn: $morningEnabled)
                    if morningEnabled {
                        DatePicker("وقت التذكير", selection: morningTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("شاشة القفل والتذكير")
                } footer: {
                    Text("عرض شاشة القفل يتحدث لما تفتح التطبيق أو تنجز مهمة، ويظل ظاهر حوالي 8 ساعات. نذكرك قبل ما ينتهي عشان تفتح التطبيق وتجدده.")
                }

                Section("المهمات والستريك") {
                    Text(digits.format(String(localized: "إذا أنجزت كل مهماتك الرئيسية في اليوم، يزيد الستريك. وإذا أنجزت جزءاً منها، يثبت. وإذا ما أنجزت شيئاً، تبدأ عدّ 3 أيام، وبعدها ينقص الستريك واحد كل يوم.")))
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                }

                Section("فحص النظام") {
                    LabeledContent("مجموعة التطبيق (App Group)") {
                        Text(appGroupConnected ? LocalizedStringKey("متصلة") : LocalizedStringKey("غير متصلة"))
                    }
                    LabeledContent("الإصدار") {
                        Text(versionText)
                    }
                }
            }
            .onChange(of: morningEnabled) { _, _ in refreshMorning() }
            .onChange(of: morningHour) { _, _ in refreshMorning() }
            .onChange(of: morningMinute) { _, _ in refreshMorning() }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                }
            }
        }
        .appRoot()
    }

    private func refreshMorning() {
        Task { await LiveActivityController.shared.updateMorningReminder() }
    }

    private var morningTime: Binding<Date> {
        Binding(
            get: { Calendar.app.date(from: DateComponents(hour: morningHour, minute: morningMinute)) ?? Date() },
            set: { date in
                let parts = Calendar.app.dateComponents([.hour, .minute], from: date)
                morningHour = parts.hour ?? 7
                morningMinute = parts.minute ?? 0
            }
        )
    }

    private func hourLabel(_ hour: Int) -> String {
        let text = hour < 10 ? "0\(hour):00" : "\(hour):00"
        return digits.format(text)
    }

    private var appGroupConnected: Bool {
        AppGroup.containerURL != nil
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return digits.format("\(version) (\(build))")
    }
}
