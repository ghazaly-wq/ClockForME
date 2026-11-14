import Foundation

/// In-app appearance setting. Default is following the system.
public enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark

    /// Falls back to `.system` for unknown stored values.
    public init(storedValue: String) {
        self = AppearanceMode(rawValue: storedValue) ?? .system
    }
}
