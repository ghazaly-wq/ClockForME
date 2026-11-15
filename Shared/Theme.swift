import SwiftUI
import UIKit

/// The accent colors of one shop theme. The default matches the original green look.
struct ThemePalette {
    let primaryLight: UInt32, primaryDark: UInt32
    let strongLight: UInt32, strongDark: UInt32
    let mutedLight: UInt32, mutedDark: UInt32
    let surfaceLight: UInt32
    let cardDark: UInt32

    static let standard = ThemePalette(
        primaryLight: 0x12A96A, primaryDark: 0x1DBF7A, strongLight: 0x0B7A4B, strongDark: 0x5FE0A6,
        mutedLight: 0x6BAA8F, mutedDark: 0x123B2A, surfaceLight: 0xF2FFF9, cardDark: 0x0F1A15
    )

    /// Ids match the shop catalog in HabitCore. Unknown ids fall back to the default.
    static func palette(for id: String) -> ThemePalette {
        switch id {
        case "theme.ocean":
            return ThemePalette(
                primaryLight: 0x1E88E5, primaryDark: 0x42A5F5, strongLight: 0x0D5FA8, strongDark: 0x90CAF9,
                mutedLight: 0x7BA7D1, mutedDark: 0x12304D, surfaceLight: 0xF1F8FF, cardDark: 0x0F1822
            )
        case "theme.violet":
            return ThemePalette(
                primaryLight: 0x7E57C2, primaryDark: 0x9575CD, strongLight: 0x4F2E9A, strongDark: 0xCDB8F5,
                mutedLight: 0x9E8BC9, mutedDark: 0x2A1F45, surfaceLight: 0xF6F2FF, cardDark: 0x161022
            )
        case "theme.sunset":
            return ThemePalette(
                primaryLight: 0xE64A19, primaryDark: 0xF4511E, strongLight: 0xB23A12, strongDark: 0xFFAB91,
                mutedLight: 0xD99C86, mutedDark: 0x4A2217, surfaceLight: 0xFFF5F0, cardDark: 0x1E1410
            )
        case "theme.rose":
            return ThemePalette(
                primaryLight: 0xD81B60, primaryDark: 0xE0245E, strongLight: 0x9C1244, strongDark: 0xF8A5C2,
                mutedLight: 0xD890A8, mutedDark: 0x4A1A2B, surfaceLight: 0xFFF1F6, cardDark: 0x1E1015
            )
        case "theme.graphite":
            return ThemePalette(
                primaryLight: 0x546E7A, primaryDark: 0x607D8B, strongLight: 0x2F4048, strongDark: 0xCFD8DC,
                mutedLight: 0x90A4AE, mutedDark: 0x2A3439, surfaceLight: 0xF3F5F6, cardDark: 0x14181A
            )
        default:
            return .standard
        }
    }
}

/// Design tokens. Views use only these, never raw colors.
/// Each token adapts to light / dark automatically. Accent colors follow the equipped shop
/// theme (read from UserDefaults; the widget extension never sets one, so it stays default).
enum Theme {
    private static var palette: ThemePalette {
        ThemePalette.palette(for: UserDefaults.standard.string(forKey: "equippedTheme") ?? "theme.default")
    }

    static var primary: Color { let p = palette; return dynamic(light: p.primaryLight, dark: p.primaryDark) }
    static var primaryStrong: Color { let p = palette; return dynamic(light: p.strongLight, dark: p.strongDark) }
    static var barMuted: Color { let p = palette; return dynamic(light: p.mutedLight, dark: p.mutedDark) }
    static var surface: Color { dynamic(light: palette.surfaceLight, dark: 0x000000) }
    static var card: Color { dynamic(light: 0xFFFFFF, dark: palette.cardDark) }
    static let textPrimary = dynamic(light: 0x0F1F18, dark: 0xEAF7F0)
    static let textSecondary = dynamic(light: 0x4A5D54, dark: 0x9DB5AA)
    static let danger = Color(uiColor: .systemRed)
    /// Achievements, level-ups and rewards only.
    static let gold = dynamic(light: 0xE3A82B, dark: 0xF2C14E)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
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
