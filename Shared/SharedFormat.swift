import Foundation
import SwiftUI

/// Small formatting helpers used by the app-side activity code and the extension
/// (the extension does not link HabitCore).
enum SharedFormat {
    private static let western: [Character] = Array("0123456789")
    private static let arabicIndic: [Character] = Array("٠١٢٣٤٥٦٧٨٩")

    static func digits(_ text: String, arabic: Bool) -> String {
        let target = arabic ? arabicIndic : western
        var result = ""
        for character in text {
            if let index = western.firstIndex(of: character) ?? arabicIndic.firstIndex(of: character) {
                result.append(target[index])
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// "7:30 ص" in the device time zone.
    static func time(_ date: Date, arabic: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "h:mm a"
        return digits(formatter.string(from: date), arabic: arabic)
    }

    static func count(_ done: Int, of total: Int, arabic: Bool) -> String {
        digits("\(done)/\(total)", arabic: arabic)
    }

    static func percent(_ fraction: Double, arabic: Bool) -> String {
        digits("\(Int((fraction * 100).rounded()))%", arabic: arabic)
    }
}

/// Deep links shared by the app, widgets and the Live Activity.
enum DeepLink {
    static let today = URL(string: "habits://today")!
    static let start = URL(string: "habits://start")!
}
