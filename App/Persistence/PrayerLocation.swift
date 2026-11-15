import Foundation
import HabitCore

/// Where prayer times are computed for. Stored in UserDefaults (also via @AppStorage in views).
struct PrayerLocation: Equatable {
    var latitude: Double
    var longitude: Double
    var name: String

    var provider: AdhanPrayerTimes { AdhanPrayerTimes(latitude: latitude, longitude: longitude) }

    static func load(_ defaults: UserDefaults = .standard) -> PrayerLocation? {
        guard defaults.bool(forKey: SettingsKey.hasPrayerLocation) else { return nil }
        return PrayerLocation(
            latitude: defaults.double(forKey: SettingsKey.prayerLatitude),
            longitude: defaults.double(forKey: SettingsKey.prayerLongitude),
            name: defaults.string(forKey: SettingsKey.prayerPlaceName) ?? ""
        )
    }

    func save(_ defaults: UserDefaults = .standard) {
        defaults.set(latitude, forKey: SettingsKey.prayerLatitude)
        defaults.set(longitude, forKey: SettingsKey.prayerLongitude)
        defaults.set(name, forKey: SettingsKey.prayerPlaceName)
        defaults.set(true, forKey: SettingsKey.hasPrayerLocation)
    }
}

/// Saudi cities for the manual picker (no default: the owner chooses).
struct SaudiCity: Identifiable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double
    var id: String { name }

    static let all: [SaudiCity] = [
        SaudiCity(name: "الرياض", latitude: 24.7136, longitude: 46.6753),
        SaudiCity(name: "جدة", latitude: 21.4858, longitude: 39.1925),
        SaudiCity(name: "مكة المكرمة", latitude: 21.3891, longitude: 39.8579),
        SaudiCity(name: "المدينة المنورة", latitude: 24.5247, longitude: 39.5692),
        SaudiCity(name: "الدمام", latitude: 26.4207, longitude: 50.0888),
        SaudiCity(name: "الخبر", latitude: 26.2172, longitude: 50.1971),
        SaudiCity(name: "الطائف", latitude: 21.2703, longitude: 40.4158),
        SaudiCity(name: "تبوك", latitude: 28.3835, longitude: 36.5662),
        SaudiCity(name: "أبها", latitude: 18.2164, longitude: 42.5053),
        SaudiCity(name: "بريدة", latitude: 26.3260, longitude: 43.9750),
        SaudiCity(name: "حائل", latitude: 27.5114, longitude: 41.7208),
        SaudiCity(name: "نجران", latitude: 17.4917, longitude: 44.1322),
        SaudiCity(name: "جازان", latitude: 16.8892, longitude: 42.5511),
        SaudiCity(name: "الجبيل", latitude: 27.0046, longitude: 49.6460),
        SaudiCity(name: "ينبع", latitude: 24.0895, longitude: 38.0618),
        SaudiCity(name: "الباحة", latitude: 20.0129, longitude: 41.4677),
        SaudiCity(name: "سكاكا", latitude: 29.9697, longitude: 40.2064),
        SaudiCity(name: "عرعر", latitude: 30.9753, longitude: 41.0381),
        SaudiCity(name: "الهفوف", latitude: 25.3648, longitude: 49.5878),
        SaudiCity(name: "خميس مشيط", latitude: 18.3000, longitude: 42.7333)
    ]
}
