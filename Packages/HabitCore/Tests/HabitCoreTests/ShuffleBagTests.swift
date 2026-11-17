import XCTest
@testable import HabitCore

/// A small seedable generator so the tests are repeatable.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class ShuffleBagTests: XCTestCase {
    func testEveryRoundOfFourPlaysEachSoundOnce() {
        var rng = SplitMix64(state: 42)
        var bag = ShuffleBag(count: 4)
        for _ in 0..<50 {
            let round = (0..<4).map { _ in bag.next(using: &rng) }
            XCTAssertEqual(Set(round), [0, 1, 2, 3])
        }
    }

    func testNeverRepeatsBackToBackEvenAcrossRounds() {
        for seed in UInt64(1)...UInt64(30) {
            var rng = SplitMix64(state: seed)
            var bag = ShuffleBag(count: 4)
            var previous: Int?
            for _ in 0..<200 {
                let value = bag.next(using: &rng)
                XCTAssertNotEqual(value, previous)
                previous = value
            }
        }
    }

    func testEverySoundCanComeFirst() {
        var firsts = Set<Int>()
        for seed in UInt64(1)...UInt64(60) {
            var rng = SplitMix64(state: seed)
            var bag = ShuffleBag(count: 4)
            firsts.insert(bag.next(using: &rng))
        }
        XCTAssertEqual(firsts, [0, 1, 2, 3])
    }

    func testSavedStateResumesTheSameRound() throws {
        var rng = SplitMix64(state: 7)
        var bag = ShuffleBag(count: 4)
        let firstTwo = [bag.next(using: &rng), bag.next(using: &rng)]
        var restored = try JSONDecoder().decode(ShuffleBag.self, from: try JSONEncoder().encode(bag))
        XCTAssertEqual(restored, bag)
        let lastTwo = [restored.next(using: &rng), restored.next(using: &rng)]
        XCTAssertEqual(Set(firstTwo + lastTwo), [0, 1, 2, 3])
    }

    func testDamagedSavedStateIsCleaned() {
        let bag = ShuffleBag(count: 4, remaining: [9, 1, 1, -2, 3], last: 12)
        XCTAssertEqual(bag.remaining, [1, 3])
        XCTAssertNil(bag.last)
    }

    func testASingleSoundAlwaysPlays() {
        var rng = SplitMix64(state: 3)
        var bag = ShuffleBag(count: 1)
        XCTAssertEqual((0..<5).map { _ in bag.next(using: &rng) }, [0, 0, 0, 0, 0])
    }
}
