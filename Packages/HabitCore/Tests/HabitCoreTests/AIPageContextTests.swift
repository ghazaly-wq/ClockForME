import XCTest
@testable import HabitCore

final class AIPageContextTests: XCTestCase {
    func testSummaryKeepsHeadingsAndContainerNamesAroundValues() {
        let weight = Block(kind: .number, title: "الوزن", unit: "كجم")
        let sets = Block(kind: .sets, title: "المجموعات", columns: ["الوزن", "العدّات"])
        let empty = Block(kind: .textField, title: "ملاحظات")
        let note = Block(kind: .text, text: "ابدأ بتسخين")
        let ask = Block(kind: .ai, title: "اسأل")
        let chest = Block(kind: .container, title: "تمرين الصدر", children: [sets, empty])
        let heading = Block(kind: .heading, title: "يوم الدفع")
        var session = PageSession(pageID: UUID(), tabID: UUID(), day: DayKey(year: 2026, month: 3, day: 10))
        session.set(.number(80), for: weight.id)
        session.set(.rows([SetRow(values: [60, 10]), SetRow(values: [nil, nil])]), for: sets.id)
        session.set(.text("  "), for: empty.id)
        let text = AIPageContext.summary(blocks: [heading, note, weight, chest, ask], session: session)
        XCTAssertEqual(text, "[يوم الدفع]\nابدأ بتسخين\nالوزن: 80 كجم\n[تمرين الصدر]\n  المجموعات: (1) 60 × 10")
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
