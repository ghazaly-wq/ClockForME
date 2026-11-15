import Foundation
import Adhan

/// Prayer times for a coordinate using the Umm al-Qura method and the Shafi'i Asr rule.
public struct AdhanPrayerTimes: PrayerTimeProviding, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public func times(for day: DayKey, calendar: Calendar) -> [Prayer: Date]? {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        var params = CalculationMethod.ummAlQura.params
        params.madhab = .shafi
        let components = DateComponents(year: day.year, month: day.month, day: day.day)
        guard let times = PrayerTimes(
            coordinates: Coordinates(latitude: latitude, longitude: longitude),
            date: components,
            calculationParameters: params
        ) else { return nil }
        return [
            .fajr: times.fajr,
            .dhuhr: times.dhuhr,
            .asr: times.asr,
            .maghrib: times.maghrib,
            .isha: times.isha
        ]
    }
}
