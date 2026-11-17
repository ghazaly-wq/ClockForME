import XCTest
@testable import HabitCore

final class AppBlockTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func at(_ offset: TimeInterval) -> Date { now.addingTimeInterval(offset) }

    func testBlocksOnceItsTimeHasPassedAndItIsNotDone() {
        let task = BlockCandidate(id: UUID(), blocksApps: true, isDone: false, dueTimes: [at(-60)])
        XCTAssertEqual(AppBlockRule.blockingIDs([task], now: now), [task.id])
    }

    func testBlocksExactlyAtItsTime() {
        let task = BlockCandidate(id: UUID(), blocksApps: true, isDone: false, dueTimes: [now])
        XCTAssertEqual(AppBlockRule.blockingIDs([task], now: now), [task.id])
    }

    func testDoesNotBlockBeforeItsTime() {
        let task = BlockCandidate(id: UUID(), blocksApps: true, isDone: false, dueTimes: [at(60)])
        XCTAssertTrue(AppBlockRule.blockingIDs([task], now: now).isEmpty)
    }

    func testDoneTaskNeverBlocks() {
        let task = BlockCandidate(id: UUID(), blocksApps: true, isDone: true, dueTimes: [at(-3600)])
        XCTAssertTrue(AppBlockRule.blockingIDs([task], now: now).isEmpty)
    }

    func testSwitchOffNeverBlocks() {
        let task = BlockCandidate(id: UUID(), blocksApps: false, isDone: false, dueTimes: [at(-3600)])
        XCTAssertTrue(AppBlockRule.blockingIDs([task], now: now).isEmpty)
    }

    func testTaskWithoutATimeNeverBlocks() {
        let task = BlockCandidate(id: UUID(), blocksApps: true, isDone: false, dueTimes: [])
        XCTAssertTrue(AppBlockRule.blockingIDs([task], now: now).isEmpty)
    }

    func testSeveralPrayersBlockFromTheEarliestTime() {
        // Dhuhr passed, Asr and Isha still ahead: it already blocks.
        let task = BlockCandidate(id: UUID(), blocksApps: true, isDone: false, dueTimes: [at(7200), at(-600), at(30_000)])
        XCTAssertEqual(AppBlockRule.blockingIDs([task], now: now), [task.id])
    }

    func testOnlyTheBlockingTasksAreReturned() {
        let blocking = BlockCandidate(id: UUID(), blocksApps: true, isDone: false, dueTimes: [at(-10)])
        let waiting = BlockCandidate(id: UUID(), blocksApps: true, isDone: false, dueTimes: [at(10)])
        let plain = BlockCandidate(id: UUID(), blocksApps: false, isDone: false, dueTimes: [at(-10)])
        XCTAssertEqual(AppBlockRule.blockingIDs([plain, blocking, waiting], now: now), [blocking.id])
    }
}
