import HabitCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.signatureReminderEnabled) private var signatureReminder = true
    @State private var confirmReset = false
    @State private var confirmResetFinal = false
    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.digitStyle) private var digitRaw = DigitStyle.western.rawValue
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @AppStorage(SettingsKey.liveActivityEnabled) private var liveEnabled = true
    @AppStorage(SettingsKey.liveActivityAutoStart) private var liveAutoStart = true
    @AppStorage(SettingsKey.taskShowAllTimes) private var showAllTimes = true
    @AppStorage(SettingsKey.taskFollowsNextRing) private var followsNextRing = true
    @AppStorage(SettingsKey.morningEnabled) private var morningEnabled = false
    @AppStorage(SettingsKey.morningHour) private var morningHour = 7
    @AppStorage(SettingsKey.morningMinute) private var morningMinute = 0
    @AppStorage(SettingsKey.appBlockEnabled) private var appBlockEnabled = true
    @AppStorage(SettingsKey.soundEffectsEnabled) private var soundEffectsEnabled = true

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
                    NavigationLink("تشخيص المنبهات") { AlarmDiagnosticsView() }
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

                Section {
                    Toggle("عرض كل أوقات المهمة", isOn: $showAllTimes)
                    Toggle("المهمة القادمة تتبع الرنة الجاية", isOn: $followsNextRing)
                } header: {
                    Text("المهمات متعددة الصلوات")
                } footer: {
                    Text("لما يكون تنبيه المهمة على أكثر من صلاة (مثلاً الظهر والعصر والعشاء). الأول يعرض كل الأوقات في سطر المهمة بدل الأول بس. والثاني يخلي «المهمة القادمة» في الرئيسية وشاشة القفل والويدجت تنتقل لوقت الصلاة الجاية بعد ما يمر الأول.")
                }

                Section {
                    Toggle("قفل التطبيقات", isOn: $appBlockEnabled)
                    NavigationLink("كيف أفعّل القفل؟") { AppBlockGuideView() }
                } header: {
                    Text("قفل التطبيقات")
                } footer: {
                    Text("لما يكون على مهمة «اقفل التطبيقات لين أخلصها» وفات وقتها، تطلع شاشة تخليك تخلّصها أول لما تفتح التطبيق. تطفيه يوقف كل القفل من غير ما تغيّر المهام.")
                }

                Section {
                    Toggle("المؤثرات الصوتية", isOn: $soundEffectsEnabled)
                } header: {
                    Text("الأصوات")
                } footer: {
                    Text("أصوات قصيرة لما تنجز مهمة، أو تفتح إنجاز، أو تخلص كل مهام اليوم، أو تشتري من المتجر. تتبع زر الصامت في الجوال.")
                }

                Section("المهمات والستريك") {
                    Text(digits.format(String(localized: "إذا أنجزت كل مهماتك الرئيسية في اليوم، يزيد الستريك. وإذا أنجزت جزءاً منها، يثبت. وإذا ما أنجزت شيئاً، تبدأ عدّ 3 أيام، وبعدها ينقص الستريك واحد كل يوم.")))
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                }

                Section {
                    NavigationLink("النسخ الاحتياطي") { BackupView() }
                } header: {
                    Text("بياناتك")
                } footer: {
                    Text("كل بياناتك على الجوال بس. خذ نسخة احتياطية من وقت لوقت.")
                }

                Section {
                    LabeledContent("ينتهي التوقيع") {
                        Text(signatureText)
                            .foregroundStyle(signatureLow ? Theme.danger : Theme.textPrimary)
                    }
                    Toggle("نذكّرني قبل الانتهاء بيوم", isOn: $signatureReminder)
                } header: {
                    Text("توقيع التطبيق")
                } footer: {
                    Text("التطبيق الموقّع بحساب مجاني ينتهي كل 7 أيام. خل AltServer شغال على الكمبيوتر والجوال على نفس الواي فاي عشان AltStore يجدده تلقائي. أو افتح AltStore على الجوال واضغط «تجديد».")
                }

                Section("فحص النظام") {
                    LabeledContent("مجموعة التطبيق (App Group)") {
                        Text(appGroupConnected ? LocalizedStringKey("متصلة") : LocalizedStringKey("غير متصلة"))
                    }
                    LabeledContent("الإصدار") {
                        Text(versionText)
                    }
                }

                Section {
                    Button("إعادة ضبط كل البيانات", role: .destructive) { confirmReset = true }
                        .frame(minHeight: 44)
                } footer: {
                    Text("يحذف كل المهمات والتنبيهات والصفحات والإنجازات والنقاط ويرجع الإعدادات للافتراضي. ما يمديك ترجعها إلا من نسخة احتياطية.")
                }
            }
            .confirmationDialog("تحذف كل بياناتك؟", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("متابعة", role: .destructive) { confirmResetFinal = true }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("بتنحذف المهمات والتنبيهات والصفحات والإنجازات والنقاط.")
            }
            .alert("متأكد 100٪؟", isPresented: $confirmResetFinal) {
                Button("احذف كل شي", role: .destructive) { resetEverything() }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("هذا ما يتراجع عنه. لو عندك نسخة احتياطية ما عليك.")
            }
            .onChange(of: signatureReminder) { _, on in
                Task { await SignatureInfo.rescheduleReminder(askPermission: on) }
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

    private var signatureText: String {
        guard let days = SignatureInfo.daysLeft() else { return String(localized: "غير معروف") }
        if days == 0 { return String(localized: "منتهي، جدّده من AltStore") }
        return digits.format(String(localized: "بعد \(days) يوم"))
    }

    private var signatureLow: Bool {
        guard let days = SignatureInfo.daysLeft() else { return false }
        return days <= 1
    }

    private func resetEverything() {
        do {
            try BackupService.resetAll(context: context)
            Task { await AlarmActions.replan(container: AppEnvironment.shared.container) }
        } catch {
            // Nothing was deleted if the fetch/delete failed before saving; the owner can try again.
        }
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
