import HabitCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.digitStyle) private var digitRaw = DigitStyle.western.rawValue

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

    private var appGroupConnected: Bool {
        AppGroup.containerURL != nil
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return NumberFormatting.convertDigits(
            in: "\(version) (\(build))",
            to: DigitStyle(storedValue: digitRaw)
        )
    }
}
