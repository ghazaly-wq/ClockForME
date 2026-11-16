import Foundation

// MARK: - Challenge settings

/// What the owner has to do before a challenge alarm stops ringing.
public enum ChallengeKind: String, Codable, CaseIterable, Equatable, Sendable {
    /// Addition and subtraction questions.
    case math
    /// Walk a number of steps (counted by the phone's pedometer).
    case steps
    /// Type a sentence exactly.
    case typing
    /// Shake the phone a number of times.
    case shake
    /// Look at digits for a few seconds, then type them from memory.
    case memory
}

public enum MathLevel: String, Codable, CaseIterable, Equatable, Sendable {
    case easy, medium, hard
}

/// A challenge attached to an alarm. Every number is kept inside a sensible range, so a bad value
/// (from a backup, say) can never make a challenge impossible or empty.
public struct AlarmChallenge: Codable, Equatable, Sendable {
    public static let defaultSteps = 50
    public static let stepsRange = 10...2000
    public static let questionsRange = 1...10
    public static let shakeRange = 10...200
    public static let memoryRange = 3...10

    public var kind: ChallengeKind
    public var mathLevel: MathLevel
    /// How many questions must be answered correctly (math).
    public var questionCount: Int
    public var stepCount: Int
    public var shakeCount: Int
    /// How many digits to remember (memory).
    public var memoryLength: Int

    public init(
        kind: ChallengeKind = .math,
        mathLevel: MathLevel = .easy,
        questionCount: Int = 3,
        stepCount: Int = AlarmChallenge.defaultSteps,
        shakeCount: Int = 30,
        memoryLength: Int = 5
    ) {
        self.kind = kind
        self.mathLevel = mathLevel
        self.questionCount = Self.clamp(questionCount, Self.questionsRange)
        self.stepCount = Self.clamp(stepCount, Self.stepsRange)
        self.shakeCount = Self.clamp(shakeCount, Self.shakeRange)
        self.memoryLength = Self.clamp(memoryLength, Self.memoryRange)
    }

    private enum CodingKeys: String, CodingKey {
        case kind, mathLevel, questionCount, stepCount, shakeCount, memoryLength
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try c.decodeIfPresent(ChallengeKind.self, forKey: .kind) ?? .math,
            mathLevel: try c.decodeIfPresent(MathLevel.self, forKey: .mathLevel) ?? .easy,
            questionCount: try c.decodeIfPresent(Int.self, forKey: .questionCount) ?? 3,
            stepCount: try c.decodeIfPresent(Int.self, forKey: .stepCount) ?? AlarmChallenge.defaultSteps,
            shakeCount: try c.decodeIfPresent(Int.self, forKey: .shakeCount) ?? 30,
            memoryLength: try c.decodeIfPresent(Int.self, forKey: .memoryLength) ?? 5
        )
    }

    private static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// The same challenge with a number set from the editor (kept inside its range).
    public func settingSteps(_ value: Int) -> AlarmChallenge {
        var copy = self
        copy.stepCount = Self.clamp(value, Self.stepsRange)
        return copy
    }
}

// MARK: - Where the stop button leads

public enum StopDestinationKind: String, Codable, CaseIterable, Equatable, Sendable {
    /// A website or a link of an app (`https://…`, `whatsapp://…`).
    case link
    /// A shortcut of the owner's, by name. It can open any app.
    case shortcut
}

/// Where the owner lands after the alarm is done (and its challenge, if any), instead of this app.
public struct StopDestination: Codable, Equatable, Sendable {
    public var kind: StopDestinationKind
    public var value: String

    public init(kind: StopDestinationKind, value: String) {
        self.kind = kind
        self.value = value
    }

    /// Schemes we never open from a stop button.
    private static let blockedSchemes: Set<String> = ["javascript", "file", "data", "vbscript"]

    /// The URL to open, or nil when the text isn't usable.
    public var url: URL? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        switch kind {
        case .shortcut:
            var components = URLComponents()
            components.scheme = "shortcuts"
            components.host = "run-shortcut"
            components.queryItems = [URLQueryItem(name: "name", value: text)]
            return components.url
        case .link:
            let candidate: String
            if text.contains("://") || text.lowercased().hasPrefix("mailto:") || text.lowercased().hasPrefix("tel:") {
                candidate = text
            } else if text.contains(" ") || !text.contains(".") {
                return nil
            } else {
                candidate = "https://" + text
            }
            guard let url = URL(string: candidate), let scheme = url.scheme?.lowercased(),
                  !Self.blockedSchemes.contains(scheme) else { return nil }
            return url
        }
    }

    public var isValid: Bool { url != nil }
}

// MARK: - Questions

public struct MathQuestion: Equatable, Sendable {
    /// For example `47 + 38`. Numbers and operators only (always shown left to right).
    public let text: String
    public let answer: Int

    public init(text: String, answer: Int) {
        self.text = text
        self.answer = answer
    }
}

/// Addition and subtraction only. The answer is never negative, so it is always a plain number to type.
public enum MathGenerator {
    public static func question<G: RandomNumberGenerator>(level: MathLevel, using rng: inout G) -> MathQuestion {
        let terms: Int
        let range: ClosedRange<Int>
        switch level {
        case .easy: terms = 2; range = 2...20
        case .medium: terms = 2; range = 20...99
        case .hard: terms = 3; range = 50...999
        }
        for _ in 0..<50 {
            let numbers = (0..<terms).map { _ in Int.random(in: range, using: &rng) }
            var ops = (1..<terms).map { _ in Bool.random(using: &rng) }   // true = plus
            if level == .hard, !ops.contains(true) { ops[0] = true }
            var total = numbers[0]
            var text = String(numbers[0])
            for index in 1..<terms {
                if ops[index - 1] {
                    total += numbers[index]
                    text += " + \(numbers[index])"
                } else {
                    total -= numbers[index]
                    text += " − \(numbers[index])"
                }
            }
            if total >= 0 { return MathQuestion(text: text, answer: total) }
        }
        // Practically unreachable: fall back to a plain sum.
        let a = Int.random(in: range, using: &rng), b = Int.random(in: range, using: &rng)
        return MathQuestion(text: "\(a) + \(b)", answer: a + b)
    }

    public static func question(level: MathLevel) -> MathQuestion {
        var rng = SystemRandomNumberGenerator()
        return question(level: level, using: &rng)
    }
}

public enum TypingChallenge {
    public static let phrases: [String] = [
        "سبحان الله وبحمده سبحان الله العظيم",
        "لا إله إلا الله وحده لا شريك له",
        "اللهم أعني على ذكرك وشكرك وحسن عبادتك",
        "قم الآن وابدأ يومك بنشاط",
        "من جد وجد ومن زرع حصد",
        "الصبر مفتاح الفرج",
        "لا تؤجل عمل اليوم إلى الغد",
        "خطوة صغيرة اليوم أفضل من حلم كبير بكرة"
    ]

    public static func phrase<G: RandomNumberGenerator>(using rng: inout G) -> String {
        phrases[Int.random(in: 0..<phrases.count, using: &rng)]
    }

    /// Ignores vowel marks, stretching letters and extra spaces, so typing on a phone isn't a trap.
    public static func normalized(_ text: String) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
            let value = scalar.value
            if (0x064B...0x065F).contains(value) || value == 0x0670 || value == 0x0640 { return false }
            return true
        }
        let cleaned = String(String.UnicodeScalarView(scalars))
        return cleaned.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    public static func matches(_ input: String, phrase: String) -> Bool {
        normalized(input) == normalized(phrase)
    }
}

public enum MemoryChallenge {
    /// Digits to remember, never starting with zero.
    public static func sequence<G: RandomNumberGenerator>(length: Int, using rng: inout G) -> String {
        let count = min(max(length, AlarmChallenge.memoryRange.lowerBound), AlarmChallenge.memoryRange.upperBound)
        var digits = [String(Int.random(in: 1...9, using: &rng))]
        while digits.count < count { digits.append(String(Int.random(in: 0...9, using: &rng))) }
        return digits.joined()
    }
}

// MARK: - The ringing chain

/// A challenge alarm rings again every minute until the challenge is done: the system's stop button
/// can't be blocked, so the app schedules a few extra alarms after the main one and cancels them
/// all when the challenge is completed.
public enum ChallengeChain {
    public static let followUpCount = 10
    public static let interval: TimeInterval = 60
    /// How many coming occurrences of a challenge alarm get their chain scheduled.
    public static let plannedOccurrences = 2
    /// How long after the main ring a challenge still waits to be done (the chain plus a minute of margin).
    public static var window: TimeInterval { interval * Double(followUpCount) + 120 }

    public struct FollowUp: Equatable, Sendable {
        public let index: Int
        public let date: Date
    }

    /// The extra rings after `fire`: one per minute, `followUpCount` of them.
    public static func followUps(after fire: Date) -> [FollowUp] {
        (1...followUpCount).map { FollowUp(index: $0, date: fire.addingTimeInterval(interval * Double($0))) }
    }

    /// A stable name for one extra ring (`<occurrence>.c<index>`).
    public static func identifier(occurrence: String, index: Int) -> String {
        "\(occurrence).c\(index)"
    }
}

/// Remembers which rings of challenge alarms are waiting for their challenge, and which are done.
/// The app keeps one in UserDefaults; the rules live here so they can be tested.
public struct ChallengeLedger: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable, Identifiable {
        /// The planner's identifier of the ring: `alarm.<alarm id>.<yyyyMMddHHmm>`.
        public let key: String
        public let alarmID: UUID
        public let fireDate: Date
        public var id: String { key }

        public init(key: String, alarmID: UUID, fireDate: Date) {
            self.key = key
            self.alarmID = alarmID
            self.fireDate = fireDate
        }
    }

    public private(set) var entries: [Entry]
    /// Completed rings and when they were completed.
    public private(set) var completed: [String: Date]

    public init(entries: [Entry] = [], completed: [String: Date] = [:]) {
        self.entries = entries
        self.completed = completed
    }

    public func isCompleted(_ key: String) -> Bool { completed[key] != nil }

    public func entry(for key: String) -> Entry? { entries.first { $0.key == key } }

    public mutating func complete(_ key: String, at date: Date = Date()) {
        completed[key] = date
    }

    /// Replaces the future rings with the freshly planned ones (so an edited alarm leaves no stale ring behind),
    /// keeps the rings that already happened while they can still be completed, and forgets old ones.
    public mutating func reconcile(planned: [Entry], now: Date) {
        var kept = entries.filter { $0.fireDate <= now }
        for entry in planned where !kept.contains(where: { $0.key == entry.key }) { kept.append(entry) }
        entries = kept.sorted { $0.fireDate < $1.fireDate }
        prune(now: now)
    }

    public mutating func prune(now: Date) {
        entries.removeAll { $0.fireDate.addingTimeInterval(ChallengeChain.window) < now }
        let cutoff = now.addingTimeInterval(-2 * 86_400)
        completed = completed.filter { $0.value >= cutoff }
    }

    /// Rings that have happened, are still inside their window and are not completed, latest first.
    public func pendingEntries(now: Date) -> [Entry] {
        entries
            .filter { $0.fireDate <= now && now < $0.fireDate.addingTimeInterval(ChallengeChain.window) && !isCompleted($0.key) }
            .sorted { $0.fireDate > $1.fireDate }
    }

    /// The latest of them.
    public func pending(now: Date) -> Entry? { pendingEntries(now: now).first }
}
