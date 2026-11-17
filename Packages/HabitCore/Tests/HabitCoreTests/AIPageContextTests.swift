import XCTest
@testable import HabitCore

final class AIPageContextTests: XCTestCase {
    func testSummaryListsOnlyFilledInputBlocks() {
        var weight = Block(kind: .number, title: "الوزن", unit: "كجم")
        weight.id = UUID()
        let notes = Block(kind: .textField, title: "ملاحظات")
        let heading = Block(kind: .heading, title: "عنوان")
        let ask = Block(kind: .ai, title: "اسأل")
        var session = PageSession(pageID: UUID(), tabID: UUID(), day: DayKey(year: 2026, month: 3, day: 10))
        session.set(.number(80), for: weight.id)
        session.set(.text("  "), for: notes.id)
        let text = AIPageContext.summary(blocks: [weight, notes, heading, ask], session: session)
        XCTAssertEqual(text, "الوزن: 80 كجم")
    }

    func testChecklistAndChoiceUseOptionNames() {
        let list = Block(kind: .checklist, title: "قائمة", options: ["أ", "ب", "ج"])
        let pick = Block(kind: .choice, title: "اختيار", options: ["س", "ص"])
        var session = PageSession(pageID: UUID(), tabID: UUID(), day: DayKey(year: 2026, month: 3, day: 10))
        session.set(.flags([true, false, true]), for: list.id)
        session.set(.choices([1]), for: pick.id)
        let text = AIPageContext.summary(blocks: [list, pick], session: session)
        XCTAssertEqual(text, "قائمة: أ، ج\nاختيار: ص")
    }

    func testAIBlockKindRoundTripsAndOldBlocksDecode() throws {
        var block = Block.make(.ai)
        block.text = "كن مختصراً"
        block.aiIncludesPageData = true
        let back = try JSONDecoder().decode(Block.self, from: JSONEncoder().encode(block))
        XCTAssertEqual(back, block)
        let old = try JSONDecoder().decode(Block.self, from: Data(#"{"kind":"text","text":"x"}"#.utf8))
        XCTAssertFalse(old.aiIncludesPageData)
    }
}
