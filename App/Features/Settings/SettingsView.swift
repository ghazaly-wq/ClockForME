import HabitCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.digitStyle) private var digitRaw = DigitStyle.western.rawValue
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0

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
