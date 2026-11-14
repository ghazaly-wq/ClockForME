import SwiftUI
import UIKit

/// Design tokens. Views use only these, never raw colors.
/// Each token adapts to light / dark automatically.
enum Theme {
    static let primary = dynamic(light: 0x12A96A, dark: 0x1DBF7A)
    static let primaryStrong = dynamic(light: 0x0B7A4B, dark: 0x5FE0A6)
    static let barMuted = dynamic(light: 0x6BAA8F, dark: 0x123B2A)
    static let surface = dynamic(light: 0xF2FFF9, dark: 0x000000)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x0F1A15)
    static let textPrimary = dynamic(light: 0x0F1F18, dark: 0xEAF7F0)
    static let textSecondary = dynamic(light: 0x4A5D54, dark: 0x9DB5AA)
    static let danger = Color(uiColor: .systemRed)
    /// Achievements, level-ups and rewards only.
    static let gold = dynamic(light: 0xE3A82B, dark: 0xF2C14E)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
