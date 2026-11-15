import Foundation

/// Date math for the "app signature expires" reminder (a free Apple ID signature lasts 7 days).
public enum SignatureMath {
    /// Whole days left until `expires` (rounded up, so "6 hours left" reads as 1 day). Zero or less means expired.
    public static func daysLeft(expires: Date, now: Date) -> Int {
        let seconds = expires.timeIntervalSince(now)
        if seconds <= 0 { return 0 }
        return Int((seconds / 86_400).rounded(.up))
    }

    /// When to remind: one day before expiry. `nil` when that moment has already passed (the Settings page
    /// shows the warning instead, and we don't nag on every launch).
    public static func reminderDate(expires: Date, now: Date) -> Date? {
        let reminder = expires.addingTimeInterval(-86_400)
        return reminder > now ? reminder : nil
    }
}
