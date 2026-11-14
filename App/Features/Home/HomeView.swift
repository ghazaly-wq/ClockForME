import HabitCore
import SwiftUI

struct HomeView: View {
    @AppStorage(SettingsKey.digitStyle) private var digitRaw = DigitStyle.western.rawValue

    var body: some View {
        CurvedPage(title: "الرئيسية", subtitle: DateLine.text(for: Date(), style: DigitStyle(storedValue: digitRaw))) {
            PlaceholderContent(symbol: "house", message: "ملخص يومك يظهر هنا")
        }
    }
}

/// "14 نوفمبر 2026 · 2 جمادى الأولى 1448": Gregorian first, Hijri (Umm al-Qura) beside it.
enum DateLine {
    static func text(for date: Date, style: DigitStyle) -> String {
        let locale = Locale(identifier: "ar_SA")

        let gregorian = DateFormatter()
        gregorian.locale = locale
        gregorian.calendar = Calendar(identifier: .gregorian)
        gregorian.dateFormat = "d MMMM yyyy"

        let hijri = DateFormatter()
        hijri.locale = locale
        hijri.calendar = Calendar(identifier: .islamicUmmAlQura)
        hijri.dateFormat = "d MMMM yyyy"

        let raw = "\(gregorian.string(from: date)) · \(hijri.string(from: date))"
        return NumberFormatting.convertDigits(in: raw, to: style)
    }
}
