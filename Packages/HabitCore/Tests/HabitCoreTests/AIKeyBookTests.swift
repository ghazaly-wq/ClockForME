import XCTest
@testable import HabitCore

final class AIKeyBookTests: XCTestCase {
    private let k1 = "AIzaSyA-1234567890abcdef"
    private let k2 = "sk-proj-abcdefghijklmnop"
    private let k3 = "sk-deepseek-0123456789ab"

    func testAddCleansPastedTextAndKeepsOrder() {
        var book = AIKeyBook()
        XCTAssertTrue(book.add(provider: .google, key: "  \(k1)\n"))
        XCTAssertTrue(book.add(provider: .openai, key: "Bearer \(k2)"))
        XCTAssertEqual(book.entries.map(\.key), [k1, k2])
    }

    func testRejectsEmptyShortSpacedAndDuplicateKeys() {
        var book = AIKeyBook()
        XCTAssertEqual(book.problem(with: "   "), .empty)
        XCTAssertEqual(book.problem(with: "short"), .tooShort)
        XCTAssertEqual(book.problem(with: "abc def ghi jkl mno pqr"), .hasSpaces)
        book.add(provider: .google, key: k1)
        XCTAssertEqual(book.problem(with: k1), .duplicate)
        XCTAssertFalse(book.add(provider: .openai, key: k1))
        XCTAssertEqual(book.entries.count, 1)
    }

    func testRemoveAndMove() {
        var book = AIKeyBook()
        book.add(provider: .google, key: k1)
        book.add(provider: .openai, key: k2)
        book.add(provider: .deepseek, key: k3)
        book.move(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(book.entries.map(\.key), [k3, k1, k2])
        book.move(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(book.entries.map(\.key), [k1, k2, k3])
        book.remove(id: book.entries[1].id)
        XCTAssertEqual(book.entries.map(\.key), [k1, k3])
    }

    func testFallbackOrderPutsPreferredProviderFirst() {
        var book = AIKeyBook()
        book.add(provider: .google, key: k1)
        book.add(provider: .openai, key: k2)
        book.add(provider: .deepseek, key: k3)
        XCTAssertEqual(book.fallbackOrder().map(\.key), [k1, k2, k3])
        XCTAssertEqual(book.fallbackOrder(preferring: .deepseek).map(\.key), [k3, k1, k2])
    }

    func testMaskedHidesTheMiddle() {
        XCTAssertEqual(AIKeyBook.masked(k1), "AIza••••cdef")
        XCTAssertEqual(AIKeyBook.masked("tiny"), "••••")
    }

    func testBookSurvivesCodableRoundTrip() throws {
        var book = AIKeyBook()
        book.add(provider: .kimi, key: k1)
        let back = try JSONDecoder().decode(AIKeyBook.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(back, book)
    }
}
