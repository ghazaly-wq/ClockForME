import HabitCore
import SwiftUI
import UIKit

/// Where prayer times are computed for: GPS once, a Saudi city, or typed coordinates.
struct PrayerSettingsView: View {
    @Environment(\.digitStyle) private var digits
    @AppStorage(SettingsKey.hasPrayerLocation) private var hasLocation = false
    @AppStorage(SettingsKey.prayerLatitude) private var latitude = 0.0
    @AppStorage(SettingsKey.prayerLongitude) private var longitude = 0.0
    @AppStorage(SettingsKey.prayerPlaceName) private var placeName = ""

    @State private var locator = LocationService()
    @State private var manualLatitude = ""
    @State private var manualLongitude = ""
    @State private var manualError = false

    var body: some View {
        Form {
            Section {
                LabeledContent("الموقع الحالي") {
                    Text(hasLocation ? placeName : String(localized: "غير محدد"))
                        .foregroundStyle(hasLocation ? Theme.textPrimary : Theme.textSecondary)
                }
                Button {
                    locator.requestOnce()
                } label: {
                    Label("تحديد موقعي الحالي", systemImage: "location.fill")
                        .frame(minHeight: 44, alignment: .leading)
                }
                locatorMessage
            } header: {
                Text("الموقع")
            } footer: {
                Text("يُستخدم الموقع مرة واحدة فقط لحساب الأوقات، وما يتتبعك.")
            }

            Section("مدينة سعودية") {
                Picker("اختيار مدينة", selection: citySelection) {
                    ForEach(SaudiCity.all) { city in
                        Text(city.name).tag(Optional(city.name))
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                TextField("خط العرض (مثال 24.7136)", text: $manualLatitude)
                    .keyboardType(.numbersAndPunctuation)
                TextField("خط الطول (مثال 46.6753)", text: $manualLongitude)
                    .keyboardType(.numbersAndPunctuation)
                Button("حفظ الإحداثيات") { saveManual() }
                    .frame(minHeight: 44, alignment: .leading)
                if manualError {
                    Text("الإحداثيات غير صحيحة: العرض بين -90 و90، والطول بين -180 و180.")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            } header: {
                Text("إدخال يدوي")
            }

            Section {
                Text("حساب أم القرى، والعصر على المذهب الشافعي.")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .navigationTitle("الصلاة والموقع")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locator.onLocation = { lat, lon in
                save(PrayerLocation(latitude: lat, longitude: lon, name: String(localized: "موقعك الحالي")))
            }
        }
    }

    @ViewBuilder
    private var locatorMessage: some View {
        switch locator.state {
        case .locating:
            HStack(spacing: 8) {
                ProgressView()
                Text("جاري تحديد الموقع...")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
            }
        case .denied:
            VStack(alignment: .leading, spacing: 6) {
                Text("ما عندي إذن الموقع. اختر مدينتك من القائمة، أو فعّل الإذن من إعدادات الجهاز.")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                Button("فتح إعدادات الجهاز") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .frame(minHeight: 44, alignment: .leading)
            }
        case .failed:
            Text("تعذر تحديد الموقع. جرب مرة ثانية أو اختر مدينتك.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
        case .idle:
            EmptyView()
        }
    }

    private var citySelection: Binding<String?> {
        Binding(
            get: {
                guard hasLocation else { return nil }
                return SaudiCity.all.first { $0.name == placeName }?.name
            },
            set: { name in
                guard let city = SaudiCity.all.first(where: { $0.name == name }) else { return }
                save(PrayerLocation(latitude: city.latitude, longitude: city.longitude, name: city.name))
            }
        )
    }

    private func save(_ location: PrayerLocation) {
        latitude = location.latitude
        longitude = location.longitude
        placeName = location.name
        hasLocation = true
    }

    private func saveManual() {
        func parse(_ text: String) -> Double? {
            let western = NumberFormatting.convertDigits(in: text, to: .western)
                .replacingOccurrences(of: "٫", with: ".")
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespaces)
            return Double(western)
        }
        guard let lat = parse(manualLatitude), let lon = parse(manualLongitude),
              (-90...90).contains(lat), (-180...180).contains(lon) else {
            manualError = true
            return
        }
        manualError = false
        save(PrayerLocation(latitude: lat, longitude: lon, name: String(localized: "إحداثيات يدوية")))
    }
}

/// The five prayers today, in the Settings list.
struct TodayPrayersRows: View {
    @Environment(\.digitStyle) private var digits
    @AppStorage(SettingsKey.hasPrayerLocation) private var hasLocation = false
    @AppStorage(SettingsKey.prayerLatitude) private var latitude = 0.0
    @AppStorage(SettingsKey.prayerLongitude) private var longitude = 0.0

    var body: some View {
        if hasLocation {
            let calendar = Calendar.app
            let today = DayKey(date: Date(), calendar: calendar)
            let times = AdhanPrayerTimes(latitude: latitude, longitude: longitude).times(for: today, calendar: calendar)
            ForEach(Prayer.allCases, id: \.self) { prayer in
                LabeledContent(AlarmText.name(of: prayer)) {
                    Text(times?[prayer].map { AlarmText.time($0, digits: digits) } ?? "—")
                        .monospacedDigit()
                }
            }
        } else {
            Text("حدد موقعك لتظهر أوقات الصلاة.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
