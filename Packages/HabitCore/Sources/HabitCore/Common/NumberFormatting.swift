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

    /// Reads a number typed in either digit style; accepts "," and "٫" as the decimal mark.
    public static func parse(_ text: String) -> Double? {
        let western = convertDigits(in: text, to: .western)
            .replacingOccurrences(of: "٫", with: ".")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !western.isEmpty else { return nil }
        return Double(western)
    }

    /// A number without useless trailing zeros ("12", "12.5"), in the chosen digit style.
    public static func string(_ value: Double, style: DigitStyle, decimals: Int = 2) -> String {
        let factor = pow(10.0, Double(max(decimals, 0)))
        let rounded = (value * factor).rounded() / factor
        var text: String
        if rounded == rounded.rounded() {
            text = String(Int(rounded))
        } else {
            text = String(rounded)
        }
        if text.contains("e") { text = String(format: "%.\(decimals)f", rounded) }
        return convertDigits(in: text, to: style)
    }

    /// "mm:ss" (or "h:mm:ss" from an hour up) for timers and stopwatches. Western digits; callers convert.
    public static func clock(seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        func two(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        return h > 0 ? "\(h):\(two(m)):\(two(s))" : "\(two(m)):\(two(s))"
    }
}
