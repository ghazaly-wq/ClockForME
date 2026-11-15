import Foundation
import HabitCore
import UserNotifications

/// Reads the expiry of the signature AltStore / Sideloadly put on the app (`embedded.mobileprovision`).
/// A free Apple ID signature lasts 7 days. Everything here handles a missing profile gracefully.
enum SignatureInfo {
    static let reminderID = "com.ghazaly.habits.signature"

    static var expirationDate: Date? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)),
              start.lowerBound < end.upperBound else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let object = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
              let dictionary = object as? [String: Any] else { return nil }
        return dictionary["ExpirationDate"] as? Date
    }

    static func daysLeft(now: Date = Date()) -> Int? {
        expirationDate.map { SignatureMath.daysLeft(expires: $0, now: now) }
    }

    static var reminderEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.signatureReminderEnabled) as? Bool ?? true
    }

    /// Schedules (or clears) the "renew from AltStore" notification, one day before expiry.
    /// Only schedules when notifications are already allowed; `askPermission` is true when the owner just
    /// switched the reminder on.
    static func rescheduleReminder(askPermission: Bool = false, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        guard reminderEnabled, let expires = expirationDate,
              let fireDate = SignatureMath.reminderDate(expires: expires, now: now) else { return }

        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined, askPermission {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            settings = await center.notificationSettings()
        }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "تجديد التطبيق")
        content.body = String(localized: "جدّد التطبيق من AltStore قبل لا يوقف")
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
    }
}
