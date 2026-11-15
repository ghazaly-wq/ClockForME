import HabitCore
import SwiftUI

/// Arabic names for weekdays (Sunday first) and short summaries of a repetition.
enum RepetitionText {
    static let weekdayNames: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.weekdaySymbols   // index 0 = Sunday
    }()

    static func name(of weekday: Weekday) -> String {
        weekdayNames[weekday.rawValue - 1]
    }

    /// "كل يوم" / "الأحد، الثلاثاء" / "كل شهر: 1، 15" / "مرة واحدة · 14 نوفمبر"
    static func summary(of repetition: Repetition?, digits: DigitStyle) -> String {
        guard let repetition else { return String(localized: "بدون موعد") }
        switch repetition {
        case .once(let day):
            return digits.format(String(localized: "مرة واحدة · \(dateText(day))"))
        case .weekly(let days):
            if days.count == 7 { return String(localized: "كل يوم") }
            return days.sorted().map { name(of: $0) }.joined(separator: "، ")
        case .monthly(let days):
            let list = days.sorted().map { String($0) }.joined(separator: "، ")
            return digits.format(String(localized: "كل شهر: \(list)"))
        }
    }

    static func dateText(_ day: DayKey) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d MMMM"
        guard let date = Calendar.app.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) else {
            return day.isoString
        }
        return formatter.string(from: date)
    }
}
