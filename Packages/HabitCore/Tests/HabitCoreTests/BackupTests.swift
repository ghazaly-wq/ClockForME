import XCTest
@testable import HabitCore

final class BackupTests: XCTestCase {
    private func sample() -> BackupDocument {
        let taskID = UUID()
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        return BackupDocument(
            createdAt: created, appVersion: "0.1.0 (12)",
            tasks: [BackupTask(
                id: taskID, title: "قراءة", kindRaw: "main", repetitionData: Data([1, 2, 3]), startDayISO: "2026-11-01",
                endDayISO: nil, notes: "", createdAt: created, sortOrder: 2, alarmID: nil, timeData: nil, pageID: nil,
                routineEndISO: nil, extraPrayersData: nil
            )],
            completions: [BackupCompletion(id: UUID(), taskID: taskID, dayISO: "2026-11-02", completedAt: created)],
            alarms: [BackupAlarm(
                id: UUID(), title: "فجر", note: "", isEnabled: true, repetitionData: Data([9]), timeData: Data([8]),
                isMainTask: true, createdAt: created, linkedPageID: nil, extraPrayersData: nil, endDayISO: nil,
                deliveryRaw: "notification"
            )],
            pages: [
                BackupPage(id: UUID(), definitionData: Data([4]), createdAt: created, sortOrder: 0, isTemplate: false),
                BackupPage(id: UUID(), definitionData: Data([5]), createdAt: created, sortOrder: 1, isTemplate: true)
            ],
            unlocks: [BackupUnlock(achievementID: "tasks.1", unlockedAt: created)],
            purchases: [BackupPurchase(itemID: "theme.ocean", price: 30, purchasedAt: created)],
            settings: ["digitStyle": .string("arabicIndic"), "dayStartHour": .int(3), "prayerLatitude": .double(21.4225), "liveActivityEnabled": .bool(false)],
            images: ["a.jpg": Data([0xFF, 0xD8])]
        )
    }

    func testRoundTripKeepsEverything() throws {
        let original = sample()
        let decoded = try BackupCoding.decode(try BackupCoding.encode(original))
        XCTAssertEqual(decoded, original)
    }

    func testSettingTypesSurviveTheRoundTrip() throws {
        let decoded = try BackupCoding.decode(try BackupCoding.encode(sample()))
        XCTAssertEqual(decoded.settings["liveActivityEnabled"], .bool(false))
        XCTAssertEqual(decoded.settings["dayStartHour"], .int(3))
        XCTAssertEqual(decoded.settings["prayerLatitude"], .double(21.4225))
        XCTAssertEqual(decoded.settings["digitStyle"], .string("arabicIndic"))
    }

    func testRejectsGarbageAndNewerVersions() throws {
        XCTAssertThrowsError(try BackupCoding.decode(Data("not json".utf8))) { XCTAssertEqual($0 as? BackupError, .unreadable) }
        XCTAssertThrowsError(try BackupCoding.decode(Data("{\"hello\":1}".utf8))) { XCTAssertEqual($0 as? BackupError, .unreadable) }
        var future = sample()
        future.schemaVersion = BackupDocument.currentVersion + 1
        let data = try BackupCoding.encode(future)
        XCTAssertThrowsError(try BackupCoding.decode(data)) {
            XCTAssertEqual($0 as? BackupError, .newerVersion(found: BackupDocument.currentVersion + 1))
        }
    }

    func testRejectsDuplicateIDs() throws {
        var doc = sample()
        doc.tasks.append(doc.tasks[0])
        XCTAssertThrowsError(try BackupCoding.decode(try BackupCoding.encode(doc))) {
            guard case .invalid? = $0 as? BackupError else { return XCTFail("expected invalid") }
        }
    }

    func testSummaryIgnoresTemplates() {
        let summary = BackupCoding.summary(of: sample())
        XCTAssertEqual(summary.tasks, 1)
        XCTAssertEqual(summary.completions, 1)
        XCTAssertEqual(summary.alarms, 1)
        XCTAssertEqual(summary.pages, 1)
        XCTAssertEqual(summary.achievements, 1)
    }

    func testPruneKeepsTheNewestFour() {
        let names = ["habits-backup-2026-10-01.json", "habits-backup-2026-10-08.json", "habits-backup-2026-10-15.json",
                     "habits-backup-2026-10-22.json", "habits-backup-2026-10-29.json", "notes.txt", "habits-backup-2026-11-05.json"]
        XCTAssertEqual(BackupCoding.filesToPrune(names, keep: 4), ["habits-backup-2026-10-01.json", "habits-backup-2026-10-08.json"])
        XCTAssertEqual(BackupCoding.filesToPrune(Array(names.prefix(3)), keep: 4), [])
    }

    func testAutoBackupDueAfterAWeek() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(BackupCoding.isAutoBackupDue(last: nil, now: now))
        XCTAssertFalse(BackupCoding.isAutoBackupDue(last: now.addingTimeInterval(-6 * 86_400), now: now))
        XCTAssertTrue(BackupCoding.isAutoBackupDue(last: now.addingTimeInterval(-7 * 86_400), now: now))
    }
}

final class SignatureMathTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testDaysLeftRoundsUp() {
        XCTAssertEqual(SignatureMath.daysLeft(expires: now.addingTimeInterval(7 * 86_400), now: now), 7)
        XCTAssertEqual(SignatureMath.daysLeft(expires: now.addingTimeInterval(6 * 3_600), now: now), 1)
        XCTAssertEqual(SignatureMath.daysLeft(expires: now.addingTimeInterval(-10), now: now), 0)
    }

    func testReminderIsOneDayBeforeAndNeverInThePast() {
        let expires = now.addingTimeInterval(3 * 86_400)
        XCTAssertEqual(SignatureMath.reminderDate(expires: expires, now: now), expires.addingTimeInterval(-86_400))
        XCTAssertNil(SignatureMath.reminderDate(expires: now.addingTimeInterval(20 * 3_600), now: now))
        XCTAssertNil(SignatureMath.reminderDate(expires: now.addingTimeInterval(-1), now: now))
    }
}
