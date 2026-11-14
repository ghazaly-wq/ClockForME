import Foundation

/// Resolves the shared App Group container at runtime.
/// Sideloading tools may rename the group, so we read what they wrote
/// into Info.plist first and fall back to the compiled default.
/// Never crashes: callers must handle a nil container gracefully.
enum AppGroup {
    static let defaultIdentifier = "group.com.ghazaly.habits"

    static var identifier: String {
        if let groups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String],
           let first = groups.first {
            return first
        }
        return defaultIdentifier
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
