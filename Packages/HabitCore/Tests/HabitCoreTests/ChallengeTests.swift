import XCTest
@testable import HabitCore

/// A generator with a fixed sequence, so random questions are repeatable.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class ChallengeTests: XCTestCase {
    // MARK: Math

    func testMathAnswersAreCorrectAndNeverNegative() {
        var rng = SeededGenerator(state: 42)
        for level in MathLevel.allCases {
            for _ in 0..<300 {
                let q = MathGenerator.question(level: level, using: &rng)
                XCTAssertGreaterThanOrEqual(q.answer, 0, q.text)
                XCTAssertEqual(evaluate(q.text), q.answer, q.text)
            }
        }
    }

    func testMathLevelsUseTheRightSizes() {
        var rng = SeededGenerator(state: 7)
        for _ in 0..<200 {
            let easy = numbers(in: MathGenerator.question(level: .easy, using: &rng).text)
            XCTAssertEqual(easy.count, 2)
            XCTAssertTrue(easy.allSatisfy { (2...20).contains($0) })

            let medium = numbers(in: MathGenerator.question(level: .medium, using: &rng).text)
            XCTAssertEqual(medium.count, 2)
            XCTAssertTrue(medium.allSatisfy { (20...99).contains($0) })

            let hard = numbers(in: MathGenerator.question(level: .hard, using: &rng).text)
            XCTAssertEqual(hard.count, 3)
            XCTAssertTrue(hard.allSatisfy { (50...999).contains($0) })
        }
    }

    func testMathUsesOnlyPlusAndMinus() {
        var rng = SeededGenerator(state: 99)
        for level in MathLevel.allCases {
            for _ in 0..<100 {
                let text = MathGenerator.question(level: level, using: &rng).text
                XCTAssertTrue(text.allSatisfy { "0123456789 +−".contains($0) }, text)
            }
        }
    }

    // MARK: Settings

    func testChallengeNumbersStayInRange() {
        let c = AlarmChallenge(kind: .steps, questionCount: 0, stepCount: 1, shakeCount: 9999, memoryLength: 1)
        XCTAssertEqual(c.stepCount, AlarmChallenge.stepsRange.lowerBound)
        XCTAssertEqual(c.questionCount, AlarmChallenge.questionsRange.lowerBound)
        XCTAssertEqual(c.shakeCount, AlarmChallenge.shakeRange.upperBound)
        XCTAssertEqual(c.memoryLength, AlarmChallenge.memoryRange.lowerBound)
        XCTAssertEqual(AlarmChallenge().stepCount, 50)
    }

    func testChallengeDecodesWithMissingFields() throws {
        let c = try JSONDecoder().decode(AlarmChallenge.self, from: Data(#"{"kind":"steps"}"#.utf8))
        XCTAssertEqual(c.kind, .steps)
        XCTAssertEqual(c.stepCount, 50)
        XCTAssertEqual(c.mathLevel, .easy)
    }

    // MARK: Typing and memory

    func testTypingIgnoresMarksAndSpaces() {
        XCTAssertTrue(TypingChallenge.matches("  سُبحانَ   الله ", phrase: "سبحان الله"))
        XCTAssertFalse(TypingChallenge.matches("سبحان", phrase: "سبحان الله"))
    }

    func testEveryTypingPhraseMatchesItself() {
        for phrase in TypingChallenge.phrases { XCTAssertTrue(TypingChallenge.matches(phrase, phrase: phrase)) }
    }

    func testMemorySequenceLengthAndFirstDigit() {
        var rng = SeededGenerator(state: 5)
        for length in [3, 5, 10, 99] {
            let s = MemoryChallenge.sequence(length: length, using: &rng)
            XCTAssertEqual(s.count, min(length, 10))
            XCTAssertNotEqual(s.first, "0")
        }
    }

    // MARK: Destination

    func testDestinationLinks() {
        XCTAssertEqual(StopDestination(kind: .link, value: "https://example.com/a").url?.absoluteString, "https://example.com/a")
        XCTAssertEqual(StopDestination(kind: .link, value: " example.com ").url?.absoluteString, "https://example.com")
        XCTAssertEqual(StopDestination(kind: .link, value: "whatsapp://send").url?.scheme, "whatsapp")
        XCTAssertNil(StopDestination(kind: .link, value: "").url)
        XCTAssertNil(StopDestination(kind: .link, value: "مرحبا").url)
        XCTAssertNil(StopDestination(kind: .link, value: "javascript://alert(1)").url)
        XCTAssertNil(StopDestination(kind: .link, value: "file:///etc/passwd").url)
    }

    func testDestinationShortcutKeepsTheName() throws {
        let url = try XCTUnwrap(StopDestination(kind: .shortcut, value: "فتح تيك توك").url)
        XCTAssertEqual(url.scheme, "shortcuts")
        XCTAssertEqual(url.host, "run-shortcut")
        let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "name" }?.value
        XCTAssertEqual(name, "فتح تيك توك")
    }

    // MARK: Chain

    func testChainFollowUpsAreOneMinuteApart() {
        let fire = Date(timeIntervalSince1970: 1_000_000)
        let list = ChallengeChain.followUps(after: fire)
        XCTAssertEqual(list.count, 10)
        XCTAssertEqual(list.first?.date, fire.addingTimeInterval(60))
        XCTAssertEqual(list.last?.date, fire.addingTimeInterval(600))
        XCTAssertEqual(list.map(\.index), Array(1...10))
        XCTAssertGreaterThan(ChallengeChain.window, 600)
    }

    // MARK: Ledger

    func testLedgerPendingWindow() {
        let alarm = UUID()
        let fire = Date(timeIntervalSince1970: 2_000_000)
        var ledger = ChallengeLedger()
        ledger.reconcile(planned: [entry(alarm, fire)], now: fire.addingTimeInterval(-3600))
        XCTAssertNil(ledger.pending(now: fire.addingTimeInterval(-1)))
        XCTAssertNotNil(ledger.pending(now: fire))
        XCTAssertNotNil(ledger.pending(now: fire.addingTimeInterval(ChallengeChain.window - 1)))
        XCTAssertNil(ledger.pending(now: fire.addingTimeInterval(ChallengeChain.window)))
    }

    func testLedgerCompletionClearsPending() {
        let alarm = UUID()
        let fire = Date(timeIntervalSince1970: 2_000_000)
        let item = entry(alarm, fire)
        var ledger = ChallengeLedger()
        ledger.reconcile(planned: [item], now: fire.addingTimeInterval(-60))
        ledger.complete(item.key, at: fire.addingTimeInterval(30))
        XCTAssertTrue(ledger.isCompleted(item.key))
        XCTAssertNil(ledger.pending(now: fire.addingTimeInterval(60)))
    }

    func testLedgerReplacesStaleFutureEntriesButKeepsRungOnes() {
        let alarm = UUID()
        let past = Date(timeIntervalSince1970: 3_000_000)
        let oldFuture = past.addingTimeInterval(86_400)
        let newFuture = past.addingTimeInterval(2 * 86_400)
        var ledger = ChallengeLedger()
        ledger.reconcile(planned: [entry(alarm, past), entry(alarm, oldFuture)], now: past.addingTimeInterval(-60))
        // The alarm was edited: tomorrow's ring moved. The ring that already happened stays.
        ledger.reconcile(planned: [entry(alarm, newFuture)], now: past.addingTimeInterval(60))
        XCTAssertEqual(ledger.entries.map(\.fireDate), [past, newFuture])
    }

    func testLedgerForgetsOldEntriesAndCompletions() {
        let alarm = UUID()
        let fire = Date(timeIntervalSince1970: 4_000_000)
        let item = entry(alarm, fire)
        var ledger = ChallengeLedger()
        ledger.reconcile(planned: [item], now: fire.addingTimeInterval(-60))
        ledger.complete(item.key, at: fire)
        ledger.prune(now: fire.addingTimeInterval(3 * 86_400))
        XCTAssertTrue(ledger.entries.isEmpty)
        XCTAssertFalse(ledger.isCompleted(item.key))
    }

    func testLedgerRoundTripsThroughJSON() throws {
        let alarm = UUID()
        let fire = Date(timeIntervalSince1970: 5_000_000)
        var ledger = ChallengeLedger()
        ledger.reconcile(planned: [entry(alarm, fire)], now: fire.addingTimeInterval(-60))
        ledger.complete("x", at: fire)
        let data = try JSONEncoder().encode(ledger)
        XCTAssertEqual(try JSONDecoder().decode(ChallengeLedger.self, from: data), ledger)
    }

    // MARK: Older data keeps working

    func testOldAlarmJSONDecodesWithoutChallenge() throws {
        let rule = AlarmRule(title: "قديم", repetition: .daily, time: .clock(hour: 6, minute: 30))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(rule)) as? [String: Any])
        json.removeValue(forKey: "challenge")
        json.removeValue(forKey: "stopDestination")
        let decoded = try JSONDecoder().decode(AlarmRule.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.challenge)
        XCTAssertNil(decoded.stopDestination)
        XCTAssertFalse(decoded.usesStopOverride)
        XCTAssertEqual(decoded, rule)
    }

    func testAlarmRuleKeepsChallengeAndDestination() throws {
        let rule = AlarmRule(
            title: "تحدي", repetition: .daily, time: .clock(hour: 5, minute: 0),
            challenge: AlarmChallenge(kind: .steps, stepCount: 80),
            stopDestination: StopDestination(kind: .link, value: "example.com")
        )
        let decoded = try JSONDecoder().decode(AlarmRule.self, from: JSONEncoder().encode(rule))
        XCTAssertEqual(decoded, rule)
        XCTAssertTrue(decoded.usesStopOverride)
        XCTAssertTrue(decoded.hasChallenge)
        XCTAssertNotEqual(rule.stopOverrideFingerprint, AlarmRule(title: "x", repetition: .daily, time: .clock(hour: 5, minute: 0)).stopOverrideFingerprint)
    }

    func testStopOverrideIsIgnoredForNotificationOnlyAlarms() {
        let rule = AlarmRule(
            title: "إشعار", repetition: .daily, time: .clock(hour: 5, minute: 0), delivery: .notification,
            challenge: AlarmChallenge()
        )
        XCTAssertFalse(rule.usesStopOverride)
        XCTAssertFalse(rule.hasChallenge)
    }

    func testInvalidDestinationAloneIsNotAnOverride() {
        let rule = AlarmRule(
            title: "x", repetition: .daily, time: .clock(hour: 5, minute: 0),
            stopDestination: StopDestination(kind: .link, value: "javascript://x")
        )
        XCTAssertFalse(rule.usesStopOverride)
    }

    func testOldBackupAlarmDecodesAndNewOneRoundTrips() throws {
        let old = BackupAlarm(
            id: UUID(), title: "t", note: "", isEnabled: true, repetitionData: Data(), timeData: Data(),
            isMainTask: false, createdAt: Date(timeIntervalSince1970: 1), linkedPageID: nil, extraPrayersData: nil,
            endDayISO: nil, deliveryRaw: nil
        )
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json.removeValue(forKey: "challengeData")
        json.removeValue(forKey: "destinationData")
        let decoded = try JSONDecoder().decode(BackupAlarm.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.challengeData)
        XCTAssertNil(decoded.destinationData)

        var withChallenge = old
        withChallenge.challengeData = try JSONEncoder().encode(AlarmChallenge(kind: .math, mathLevel: .hard))
        withChallenge.destinationData = try JSONEncoder().encode(StopDestination(kind: .shortcut, value: "فتح"))
        let again = try JSONDecoder().decode(BackupAlarm.self, from: JSONEncoder().encode(withChallenge))
        XCTAssertEqual(again, withChallenge)
    }

    func testPageScheduleCarriesChallengeToItsAlarm() {
        var page = PageDefinition(id: UUID(), name: "ورد", tabs: [PageTab(name: "أ")])
        page.schedule = PageSchedule(
            repetition: .daily, time: .clock(hour: 6, minute: 0),
            challenge: AlarmChallenge(kind: .typing), stopDestination: StopDestination(kind: .link, value: "example.com")
        )
        let rule = PageLogic.alarmRule(for: page)
        XCTAssertEqual(rule?.challenge?.kind, .typing)
        XCTAssertEqual(rule?.stopDestination?.value, "example.com")
    }

    // MARK: Helpers

    private func entry(_ alarm: UUID, _ fire: Date) -> ChallengeLedger.Entry {
        ChallengeLedger.Entry(key: "alarm.\(alarm.uuidString).\(Int(fire.timeIntervalSince1970))", alarmID: alarm, fireDate: fire)
    }

    private func numbers(in text: String) -> [Int] {
        text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }

    /// Evaluates "a + b − c" from left to right.
    private func evaluate(_ text: String) -> Int {
        let parts = text.split(separator: " ").map(String.init)
        var total = Int(parts[0]) ?? 0
        var index = 1
        while index + 1 < parts.count {
            let value = Int(parts[index + 1]) ?? 0
            total += parts[index] == "+" ? value : -value
            index += 2
        }
        return total
    }
}
