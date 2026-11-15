import HabitCore
import SwiftUI

private struct DigitStyleKey: EnvironmentKey {
    static let defaultValue: DigitStyle = .western
}

extension EnvironmentValues {
    /// The user's digit style ("الأرقام" setting). Set once at the root.
    var digitStyle: DigitStyle {
        get { self[DigitStyleKey.self] }
        set { self[DigitStyleKey.self] = newValue }
    }
}

extension DigitStyle {
    func format(_ number: Int) -> String {
        NumberFormatting.string(number, style: self)
    }

    /// Converts every digit inside a finished string.
    func format(_ text: String) -> String {
        NumberFormatting.convertDigits(in: text, to: self)
    }
}
