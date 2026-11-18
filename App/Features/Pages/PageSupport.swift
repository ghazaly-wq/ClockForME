import HabitCore
import Observation
import SwiftUI
import UserNotifications

/// Accent colors a page can have (stored by name in `PageDefinition.accent`).
enum PageAccent: String, CaseIterable, Identifiable {
    case green, blue, purple, orange, pink, gray

    var id: String { rawValue }

    init(name: String) { self = PageAccent(rawValue: name) ?? .green }

    var color: Color {
        switch self {
        case .green: return Color(red: 0.07, green: 0.66, blue: 0.42)
        case .blue: return Color(red: 0.15, green: 0.45, blue: 0.85)
        case .purple: return Color(red: 0.52, green: 0.33, blue: 0.85)
        case .orange: return Color(red: 0.90, green: 0.52, blue: 0.10)
        case .pink: return Color(red: 0.87, green: 0.30, blue: 0.55)
        case .gray: return Color(red: 0.42, green: 0.47, blue: 0.50)
        }
    }

    var arabicName: String {
        switch self {
        case .green: return "أخضر"
        case .blue: return "أزرق"
        case .purple: return "بنفسجي"
        case .orange: return "برتقالي"
        case .pink: return "وردي"
        case .gray: return "رمادي"
        }
    }
}

/// Turns saved values into short Arabic text (hints, history list).
enum PageValueText {
    static func text(_ value: BlockValue, block: Block, digits: DigitStyle) -> String {
        switch value {
        case .text(let s): return s
        case .number(let n):
            return join(NumberFormatting.string(n, style: digits), block.unit)
        case .duration(let d):
            return NumberFormatting.convertDigits(in: NumberFormatting.clock(seconds: d), to: digits)
        case .bool(let b): return b ? "✓" : "—"
        case .rows(let rows):
            let parts = rows.compactMap { row -> String? in
                let cells = row.values.map { $0.map { NumberFormatting.string($0, style: digits) } ?? "–" }
                return cells.allSatisfy({ $0 == "–" }) ? nil : cells.joined(separator: "×")
            }
            return parts.joined(separator: " · ")
        case .flags(let flags):
            return "\(digits.format(flags.filter { $0 }.count))/\(digits.format(flags.count))"
        case .choices(let indexes):
            return indexes.compactMap { block.options.indices.contains($0) ? block.options[$0] : nil }.joined(separator: "، ")
        case .date(let date):
            return digits.format(date.formatted(date: .abbreviated, time: .shortened))
        }
    }

    static func join(_ number: String, _ unit: String) -> String {
        unit.isEmpty ? number : number + " " + unit
    }

    static func date(of day: DayKey) -> Date {
        Calendar.app.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? Date()
    }
}

/// Local notification for a page timer block ("انتهى المؤقت"), so it works with the app in the background.
enum PageTimerNotifier {
    private static func identifier(_ id: UUID) -> String { "com.ghazaly.habits.pagetimer.\(id.uuidString)" }

    static func schedule(id: UUID, seconds: Int, title: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "انتهى المؤقت")
            content.body = title
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(seconds, 1)), repeats: false)
            center.add(UNNotificationRequest(identifier: identifier(id), content: content, trigger: trigger))
        }
    }

    static func cancel(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(id)])
    }
}

/// The live state of a page being used: the session's values plus running timers and stopwatches.
@MainActor
@Observable
final class PageRuntime {
    var session: PageSession
    /// Finished sessions of this page (for "last time" hints, charts and the history list).
    var history: [PageSession]
    /// Every stored session of this page (any state), for calc blocks that look back over the week.
    var allSessions: [PageSession] = []
    var timerEnds: [UUID: Date] = [:]
    private var stopwatchStarts: [UUID: Date] = [:]
    private var stopwatchBase: [UUID: Double] = [:]

    init(session: PageSession, history: [PageSession]) {
        self.session = session
        self.history = history
    }

    func value(_ id: UUID) -> BlockValue? { session.value(for: id) }

    func set(_ value: BlockValue?, for id: UUID) {
        session.set(value, for: id)
    }

    func number(_ id: UUID) -> Double { PageLogic.number(of: id, in: session) }

    /// What he entered for this block last time (nil if never).
    func last(_ id: UUID) -> BlockValue? {
        PageLogic.lastValue(of: id, in: history, pageID: session.pageID, before: session)
    }

    // MARK: Timers

    func startTimer(_ block: Block) {
        timerEnds[block.id] = Date().addingTimeInterval(TimeInterval(block.seconds))
        PageTimerNotifier.schedule(id: block.id, seconds: block.seconds, title: block.title)
    }

    func stopTimer(_ id: UUID) {
        timerEnds[id] = nil
        PageTimerNotifier.cancel(id: id)
    }

    func remaining(_ id: UUID, now: Date) -> Double? {
        guard let end = timerEnds[id] else { return nil }
        return max(0, end.timeIntervalSince(now))
    }

    // MARK: Stopwatches

    func isRunning(_ id: UUID) -> Bool { stopwatchStarts[id] != nil }

    func elapsed(_ id: UUID, now: Date) -> Double {
        let base = stopwatchBase[id] ?? number(id)
        guard let start = stopwatchStarts[id] else { return base }
        return base + max(0, now.timeIntervalSince(start))
    }

    func toggleStopwatch(_ id: UUID, now: Date) {
        if let start = stopwatchStarts[id] {
            let total = (stopwatchBase[id] ?? 0) + max(0, now.timeIntervalSince(start))
            stopwatchStarts[id] = nil
            stopwatchBase[id] = nil
            set(.duration(total), for: id)
        } else {
            stopwatchBase[id] = number(id)
            stopwatchStarts[id] = now
        }
    }

    func resetStopwatch(_ id: UUID) {
        stopwatchStarts[id] = nil
        stopwatchBase[id] = nil
        set(nil, for: id)
    }

    /// Writes running stopwatches into the session (before saving).
    func flushStopwatches(now: Date) {
        for id in Array(stopwatchStarts.keys) {
            let total = elapsed(id, now: now)
            stopwatchBase[id] = total
            stopwatchStarts[id] = now
            set(.duration(total), for: id)
        }
    }
}

/// A text field for numbers: accepts Arabic or Western digits, keeps what he is typing,
/// and writes a parsed value (or nothing when empty).
struct NumberInput: View {
    let placeholder: String
    let allowDecimal: Bool
    @Binding var value: Double?
    @Environment(\.digitStyle) private var digits
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(allowDecimal ? .decimalPad : .numberPad)
            .focused($focused)
            .multilineTextAlignment(.leading)
            .monospacedDigit()
            .onAppear { text = display(value) }
            .onChange(of: text) { _, newText in
                let parsed = NumberFormatting.parse(newText)
                if parsed != value { value = parsed }
            }
            .onChange(of: value) { _, newValue in
                // Only rewrite the text when the change came from elsewhere (not from typing).
                if !focused { text = display(newValue) }
            }
    }

    private func display(_ number: Double?) -> String {
        number.map { NumberFormatting.string($0, style: digits) } ?? ""
    }
}
