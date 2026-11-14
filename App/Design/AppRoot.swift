import HabitCore
import SwiftUI

/// Keys for settings stored in UserDefaults via @AppStorage.
enum SettingsKey {
    static let appearance = "appearanceMode"
    static let digitStyle = "digitStyle"
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
/// Saudi Arabic locale, the appearance setting and the accent color.
/// Also applied inside sheets so they match the rest of the app.
struct AppRootModifier: ViewModifier {
    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue

    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA"))
            .preferredColorScheme(AppearanceMode(storedValue: appearanceRaw).colorScheme)
            .tint(Theme.primary)
    }
}

extension View {
    func appRoot() -> some View {
        modifier(AppRootModifier())
    }
}
