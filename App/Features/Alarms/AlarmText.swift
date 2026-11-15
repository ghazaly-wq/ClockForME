import HabitCore
import SwiftUI

/// Arabic wording for prayers, offsets and times.
enum AlarmText {
    static func name(of prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return String(localized: "الفجر")
        case .dhuhr: return String(localized: "الظهر")
        case .asr: return String(localized: "العصر")
        case .maghrib: return String(localized: "المغرب")
        case .isha: return String(localized: "العشاء")
        }
    }

    /// "قبل الفجر بساعة و30 دقيقة" / "بعد العشاء بـ 45 دقيقة" / "عند الظهر".
    static func summary(of time: TimeSpec, digits: DigitStyle) -> String {
        switch time {
        case let .clock(hour, minute):
            return clockText(hour: hour, minute: minute, digits: digits)
        case let .prayer(prayer, direction, hours, minutes):
            let name = name(of: prayer)
            let duration = durationText(hours: hours, minutes: minutes)
            if duration.isEmpty { return String(localized: "عند \(name)") }
            let text = direction == .before
                ? String(localized: "قبل \(name) بـ \(duration)")
                : String(localized: "بعد \(name) بـ \(duration)")
            return digits.format(text)
        }
    }

    static func durationText(hours: Int, minutes: Int) -> String {
        var parts: [String] = []
        if hours > 0 { parts.append(unit(hours, one: "ساعة", two: "ساعتين", few: "ساعات", many: "ساعة")) }
        if minutes > 0 { parts.append(unit(minutes, one: "دقيقة", two: "دقيقتين", few: "دقائق", many: "دقيقة")) }
        return parts.joined(separator: " و")
    }

    private static func unit(_ n: Int, one: String, two: String, few: String, many: String) -> String {
        switch n {
        case 1: return one
        case 2: return two
        case 3...10: return "\(n) \(few)"
        default: return "\(n) \(many)"
        }
    }

    static func clockText(hour: Int, minute: Int, digits: DigitStyle) -> String {
        var calendar = Calendar.app
        calendar.timeZone = .current
        guard let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour, minute: minute)) else { return "" }
        return time(date, digits: digits)
    }

    /// "7:30 ص" in the chosen digit style, in the device time zone.
    static func time(_ date: Date, digits: DigitStyle) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = Calendar.app.timeZone
        formatter.dateFormat = "h:mm a"
        return digits.format(formatter.string(from: date))
    }
}
