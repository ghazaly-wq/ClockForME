import Foundation

/// Picks one of `count` sounds at random, but never repeats a sound until all the others have played
/// (a "shuffle bag"): every round of `count` plays uses each sound exactly once, and the first sound of a new
/// round is never the one that just played. Pure: the random generator is passed in, and the state is `Codable`
/// so the app can keep it between launches.
public struct ShuffleBag: Codable, Equatable, Sendable {
    public let count: Int
    /// Sounds still to play in the current round, in the order they will play.
    public private(set) var remaining: [Int]
    /// The sound played last (nil before the first play).
    public private(set) var last: Int?

    /// Saved state is sanitised: values outside `0..<count` and duplicates are dropped, so old or damaged data
    /// can never produce an invalid sound number.
    public init(count: Int, remaining: [Int] = [], last: Int? = nil) {
        let size = max(count, 1)
        self.count = size
        var seen = Set<Int>()
        self.remaining = remaining.filter { (0..<size).contains($0) && seen.insert($0).inserted }
        self.last = last.flatMap { (0..<size).contains($0) ? $0 : nil }
    }

    public mutating func next<G: RandomNumberGenerator>(using generator: inout G) -> Int {
        if remaining.isEmpty {
            var order = Array(0..<count).shuffled(using: &generator)
            if count > 1, let last, order.first == last {
                order.swapAt(0, Int.random(in: 1..<count, using: &generator))
            }
            remaining = order
        }
        let value = remaining.removeFirst()
        last = value
        return value
    }
}
