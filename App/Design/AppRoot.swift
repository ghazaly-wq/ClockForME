import HabitCore
import SwiftUI

/// Keys for settings stored in UserDefaults via @AppStorage.
enum SettingsKey {
    static let appearance = "appearanceMode"
    static let digitStyle = "digitStyle"
    static let dayStartHour = "dayStartHour"
    static let hasPrayerLocation = "prayerHasLocation"
    static let prayerLatitude = "prayerLatitude"
    static let prayerLongitude = "prayerLongitude"
    static let prayerPlaceName = "prayerPlaceName"
    /// Shop selections. The theme key is also read by `Theme` (keep the two in step).
    static let equippedTheme = "equippedTheme"
    static let equippedFrame = "equippedFrame"
    static let equippedEffect = "equippedEffect"
    static let equippedLiveStyle = "equippedLiveStyle"
    static let equippedIcon = "equippedIcon"
    static let liveActivityEnabled = "liveActivityEnabled"
    static let liveActivityAutoStart = "liveActivityAutoStart"
    static let morningEnabled = "morningReminderEnabled"
    static let morningHour = "morningReminderHour"
    static let morningMinute = "morningReminderMinute"
    /// File name of the imported alarm sound in Library/Sounds; empty = system default.
    static let alarmSound = "alarmSoundName"
    /// Multi-prayer tasks: list every time in the task row (default on).
    static let taskShowAllTimes = "taskShowAllTimes"
    /// Multi-prayer tasks: the "next task" follows the task's next ring, not its first (default on).
    static let taskFollowsNextRing = "taskFollowsNextRing"
    /// Master switch for "block apps until the task is done" (default on; each task has its own switch, default off).
    static let appBlockEnabled = "appBlockEnabled"
}

extension AppearanceMode {
    /// `nil` means "follow the system".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Applies what must hold for the whole app: right-to-left layout,
/// Saudi Arabic locale, the appearance setting, the digit style and the accent color.
/// Also applied inside sheets so they match the rest of the app.
struct AppRootModifier: ViewModifier {
    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.digitStyle) private var digitRaw = DigitStyle.western.rawValue
    @AppStorage(SettingsKey.equippedTheme) private var themeRaw = ShopCatalog.defaultTheme

    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA"))
            .environment(\.digitStyle, DigitStyle(storedValue: digitRaw))
            .preferredColorScheme(AppearanceMode(storedValue: appearanceRaw).colorScheme)
            .tint(Theme.primary)
            // Theme colors are read when views are built, so a new theme rebuilds the tree.
            .id(themeRaw)
    }
}

extension View {
    func appRoot() -> some View {
        modifier(AppRootModifier())
    }
}
