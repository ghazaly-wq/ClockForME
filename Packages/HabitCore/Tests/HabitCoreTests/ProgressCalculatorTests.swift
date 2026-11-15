import XCTest
@testable import HabitCore

final class ProgressCalculatorTests: XCTestCase {
    func testXPRequiredPerLevel() {
        XCTAssertEqual(ProgressCalculator.xpRequired(fromLevel: 1), 100)
        XCTAssertEqual(ProgressCalculator.xpRequired(fromLevel: 2), 125)
        XCTAssertEqual(ProgressCalculator.xpRequired(fromLevel: 10), 325)
    }

    func testLevelBoundaries() {
        let a = ProgressCalculator.summary(totalXP: 99, points: 0)
        XCTAssertEqual(a.level, 1)
        XCTAssertEqual(a.xpIntoLevel, 99)
        XCTAssertEqual(a.xpForNextLevel, 100)

        let b = ProgressCalculator.summary(totalXP: 100, points: 0)
        XCTAssertEqual(b.level, 2)
        XCTAssertEqual(b.xpIntoLevel, 0)
        XCTAssertEqual(b.xpForNextLevel, 125)

        let c = ProgressCalculator.summary(totalXP: 224, points: 0)
        XCTAssertEqual(c.level, 2)
        XCTAssertEqual(c.xpIntoLevel, 124)

        XCTAssertEqual(ProgressCalculator.summary(totalXP: 225, points: 0).level, 3)
    }

    func testFractionAndNegativeInput() {
        XCTAssertEqual(ProgressCalculator.summary(totalXP: 50, points: 0).levelFraction, 0.5, accuracy: 0.0001)
        let negative = ProgressCalculator.summary(totalXP: -20, points: -3)
        XCTAssertEqual(negative.totalXP, 0)
        XCTAssertEqual(negative.points, 0)
        XCTAssertEqual(negative.level, 1)
    }

    func testTitleRanges() {
        let expected: [(Int, LevelTitle)] = [
            (1, .beginner), (4, .beginner), (5, .persistent), (9, .persistent),
            (10, .disciplined), (19, .disciplined), (20, .master), (34, .master),
            (35, .roleModel), (49, .roleModel), (50, .legend), (120, .legend)
        ]
        for (level, title) in expected {
            XCTAssertEqual(LevelTitle.title(forLevel: level), title, "level \(level)")
        }
    }

    func testXPAndPointsFromHistory() {
        // 3 tasks (30 XP, 3 pts) + 1 complete day (20 XP, 3 pts), no milestone yet.
        let s = ProgressCalculator.summary(completedTasks: 3, completeDays: 1, bestStreak: 1)
        XCTAssertEqual(s.totalXP, 50)
        XCTAssertEqual(s.points, 6)
    }

    func testMilestonesAreAddedOncePerReachedMilestone() {
        let seven = ProgressCalculator.summary(completedTasks: 3, completeDays: 1, bestStreak: 7)
        XCTAssertEqual(seven.totalXP, 100)   // 30 + 20 + 50
        XCTAssertEqual(seven.points, 11)     // 3 + 3 + 5
        XCTAssertEqual(seven.level, 2)

        let six = ProgressCalculator.summary(completedTasks: 3, completeDays: 1, bestStreak: 6)
        XCTAssertEqual(six.totalXP, 50)

        let fourteen = ProgressCalculator.summary(completedTasks: 0, completeDays: 0, bestStreak: 14)
        XCTAssertEqual(fourteen.totalXP, 150)   // 7-day + 14-day bonuses
    }

    func testUndoingATaskRevokesItsXP() {
        let before = ProgressCalculator.summary(completedTasks: 5, completeDays: 1, bestStreak: 1)
        let after = ProgressCalculator.summary(completedTasks: 4, completeDays: 0, bestStreak: 0)
        XCTAssertEqual(before.totalXP - after.totalXP, ProgressRules.xpPerTask + ProgressRules.xpPerCompleteDay)
        XCTAssertEqual(before.points - after.points, ProgressRules.pointsPerTask + ProgressRules.pointsPerCompleteDay)
    }

    func testSpendingPointsNeverLowersTheLevel() {
        let rich = ProgressCalculator.summary(completedTasks: 30, completeDays: 5, bestStreak: 5)
        let spent = ProgressCalculator.summary(completedTasks: 30, completeDays: 5, bestStreak: 5, spentPoints: 20)
        XCTAssertEqual(rich.level, spent.level)
        XCTAssertEqual(rich.totalXP, spent.totalXP)
        XCTAssertEqual(spent.points, max(0, rich.points - 20))
    }
}
