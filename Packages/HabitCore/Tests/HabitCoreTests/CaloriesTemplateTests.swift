import XCTest
@testable import HabitCore

final class CaloriesTemplateTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
        return c
    }

    func testTemplateIsRegisteredAndWellFormed() throws {
        XCTAssertNotNil(PageTemplates.all.first { $0.id == "calories" })
        let page = try XCTUnwrap(PageTemplates.make("calories"))
        let blocks = page.tabs[0].blocks.flattened
        XCTAssertEqual(blocks.filter { $0.kind == .container }.count, 4)
        let ids = Set(blocks.map(\.id))
        // Every reference points at a block that exists.
        for block in blocks {
            for term in block.terms { XCTAssertTrue(ids.contains(term.blockID), block.title) }
            if let target = block.targetSourceID { XCTAssertTrue(ids.contains(target), block.title) }
            for source in block.sourceIDs { XCTAssertTrue(ids.contains(source), block.title) }
        }
        XCTAssertEqual(blocks.first { $0.kind == .nutrition }?.sourceIDs.count, 4)
        XCTAssertEqual(blocks.filter { $0.kind == .calc && $0.calcPeriod == .weekAverage }.count, 4)
    }

    func testGoalsTotalsAndRemainingWork() throws {
        let page = try XCTUnwrap(PageTemplates.make("calories"))
        let tab = page.tabs[0]
        let blocks = tab.blocks.flattened
        func block(_ title: String) -> Block { blocks.first { $0.title == title }! }

        var session = PageSession(pageID: page.id, tabID: tab.id, day: DayKey(year: 2026, month: 3, day: 10))
        session.set(.number(2000), for: block("هدف السعرات اليومي").id)
        session.set(.number(30), for: block("نسبة البروتين").id)
        session.set(.number(45), for: block("نسبة الكارب").id)
        session.set(.number(25), for: block("نسبة الدهون").id)
        let tables = blocks.filter { $0.kind == .sets }
        session.set(.rows([SetRow(values: [300, 20, 30, 10])]), for: tables[0].id)
        session.set(.rows([SetRow(values: [500, 40, 50, 15]), SetRow(values: [200, 10, 20, 5])]), for: tables[1].id)

        let lookup = CalcEngine.lookup(for: session, among: [session], blocks: blocks)
        // 2000 kcal × 30% ÷ 4 = 150 g protein; 45% carbs = 225 g; 25% fat ÷ 9 ≈ 55.6 g.
        XCTAssertEqual(CalcEngine.value(of: block("هدف البروتين"), blocks: blocks, lookup: lookup) ?? 0, 150, accuracy: 0.001)
        XCTAssertEqual(CalcEngine.value(of: block("هدف الكارب"), blocks: blocks, lookup: lookup) ?? 0, 225, accuracy: 0.001)
        XCTAssertEqual(CalcEngine.value(of: block("هدف الدهون"), blocks: blocks, lookup: lookup) ?? 0, 55.556, accuracy: 0.01)

        let calories = block("السعرات")
        XCTAssertEqual(CalcEngine.value(of: calories, blocks: blocks, lookup: lookup), 1000)
        XCTAssertEqual(CalcEngine.target(of: calories, blocks: blocks, lookup: lookup), 2000)
        XCTAssertEqual(CalcEngine.value(of: block("البروتين"), blocks: blocks, lookup: lookup), 70)
        XCTAssertEqual(CalcEngine.target(of: block("البروتين"), blocks: blocks, lookup: lookup) ?? 0, 150, accuracy: 0.001)
    }

    func testWeeklyAverageUsesGoalsTypedOnAnEarlierDay() throws {
        let page = try XCTUnwrap(PageTemplates.make("calories"))
        let tab = page.tabs[0]
        let blocks = tab.blocks.flattened
        let goal = blocks.first { $0.title == "هدف السعرات اليومي" }!
        let table = blocks.first { $0.kind == .sets }!
        let average = blocks.first { $0.title == "متوسط السعرات" }!

        func session(_ day: Int, _ rows: [SetRow], goal value: Double? = nil) -> PageSession {
            var s = PageSession(pageID: page.id, tabID: tab.id, day: DayKey(year: 2026, month: 3, day: day),
                                startedAt: cal.date(from: DateComponents(year: 2026, month: 3, day: day, hour: 12))!)
            s.set(.rows(rows), for: table.id)
            if let value { s.set(.number(value), for: goal.id) }
            return s
        }
        let past = [session(8, [SetRow(values: [1800, 0, 0, 0])], goal: 2200), session(9, [SetRow(values: [2200, 0, 0, 0])])]
        let today = session(10, [SetRow(values: [2000, 0, 0, 0])])
        let shown = CalcEngine.displayValue(of: average, blocks: blocks, current: today, sessions: past, calendar: cal)
        XCTAssertEqual(shown, 2000)
        let lookup = CalcEngine.lookup(for: today, among: past + [today], blocks: blocks)
        XCTAssertEqual(CalcEngine.target(of: average, blocks: blocks, lookup: lookup), 2200)
    }
}
