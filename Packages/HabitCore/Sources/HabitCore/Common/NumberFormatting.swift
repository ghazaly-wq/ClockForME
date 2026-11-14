import Foundation

/// How digits are shown in the UI (setting "الأرقام").
public enum DigitStyle: String, Codable, CaseIterable, Sendable {
    case western      // 123
    case arabicIndic  // ١٢٣

    /// Falls back to Western digits for unknown stored values.
    public init(storedValue: String) {
        self = DigitStyle(rawValue: storedValue) ?? .western
    }
}

/// The single place that decides how numbers look.
public enum NumberFormatting {
    private static let western: [Character] = Array("0123456789")
    private static let arabicIndic: [Character] = Array("٠١٢٣٤٥٦٧٨٩")

    /// Rewrites every digit (Western or Arabic-Indic) into the chosen style.
    public static func convertDigits(in text: String, to style: DigitStyle) -> String {
        let target = style == .western ? western : arabicIndic
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            if let index = western.firstIndex(of: character) ?? arabicIndic.firstIndex(of: character) {
                result.append(target[index])
            } else {
                result.append(character)
            }
        }
        return result
    }

    public static func string(_ value: Int, style: DigitStyle) -> String {
        convertDigits(in: String(value), to: style)
    }
}
