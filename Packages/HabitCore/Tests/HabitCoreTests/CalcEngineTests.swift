import XCTest
@testable import HabitCore

final class CalcEngineTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
        return c
    }
    private func day(_ d: Int) -> DayKey { DayKey(year: 2026, month: 3, day: d) }
    private func session(_ tab: UUID, _ d: Int, _ values: [UUID: BlockValue]) -> PageSession {
        var s = PageSession(pageID: UUID(), tabID: tab, day: day(d), startedAt: cal.date(from: DateComponents(year: 2026, month: 3, day: d, hour: 9))!)
        for (id, value) in values { s.set(value, for: id) }
        return s
    }

    func testCaloriesFromMacrosUsesWeights() {
        let p = Block(kind: .number, title: "P"), c = Block(kind: .number, title: "C"), f = Block(kind: .number, title: "F")
        let calc = Block(kind: .calc, terms: [CalcTerm(blockID: p.id, weight: 4), CalcTerm(blockID: c.id, weight: 4), CalcTerm(blockID: f.id, weight: 9)])
        let s = session(UUID(), 10, [p.id: .number(30), c.id: .number(50), f.id: .number(10)])
        let v = CalcEngine.value(of: calc, blocks: [p, c, f, calc], lookup: { s.value(for: $0) })
        XCTAssertEqual(v, 410)
    }

    func testSumsOneColumnAcrossSeveralSetsTables() {
        let a = Block(kind: .sets, title: "أ", columns: ["سعرات", "بروتين"]), b = Block(kind: .sets, title: "ب", columns: ["سعرات", "بروتين"])
        let calc = Block(kind: .calc, terms: [CalcTerm(blockID: a.id, column: 1), CalcTerm(blockID: b.id, column: 1)])
        let s = session(UUID(), 10, [
            a.id: .rows([SetRow(values: [200, 10]), SetRow(values: [100, nil])]),
            b.id: .rows([SetRow(values: [300, 25])])
        ])
        XCTAssertEqual(CalcEngine.value(of: calc, blocks: [a, b, calc], lookup: { s.value(for: $0) }), 35)
    }

    func testOperationsAndMissingValues() {
        let a = Block(kind: .number), b = Block(kind: .number)
        let s = session(UUID(), 10, [a.id: .number(10), b.id: .number(4)])
        let look: CalcEngine.Lookup = { s.value(for: $0) }
        func calc(_ op: CalcOp, scale: Double = 1) -> Block {
            Block(kind: .calc, terms: [CalcTerm(blockID: a.id), CalcTerm(blockID: b.id)], calcOp: op, calcScale: scale)
        }
        XCTAssertEqual(CalcEngine.value(of: calc(.sum), blocks: [a, b], lookup: look), 14)
        XCTAssertEqual(CalcEngine.value(of: calc(.average), blocks: [a, b], lookup: look), 7)
        XCTAssertEqual(CalcEngine.value(of: calc(.difference), blocks: [a, b], lookup: look), 6)
        XCTAssertEqual(CalcEngine.value(of: calc(.product), blocks: [a, b], lookup: look), 40)
        XCTAssertEqual(CalcEngine.value(of: calc(.ratio, scale: 100), blocks: [a, b], lookup: look), 250)
        let empty = session(UUID(), 11, [:])
        XCTAssertNil(CalcEngine.value(of: calc(.sum), blocks: [a, b], lookup: { empty.value(for: $0) }))
        let zero = session(UUID(), 12, [a.id: .number(5), b.id: .number(0)])
        XCTAssertNil(CalcEngine.value(of: calc(.ratio), blocks: [a, b], lookup: { zero.value(for: $0) }))
    }

    func testGoalCarriesForwardFromAnEarlierDay() {
        let tab = UUID()
        var goal = Block(kind: .number, title: "هدف"); goal.carryForward = true
        let calc = Block(kind: .calc, target: nil, targetSourceID: goal.id)
        let earlier = session(tab, 8, [goal.id: .number(2000)])
        let today = session(tab, 10, [:])
        let lookup = CalcEngine.lookup(for: today, among: [earlier, today], blocks: [goal, calc])
        XCTAssertEqual(CalcEngine.target(of: calc, blocks: [goal, calc], lookup: lookup), 2000)
        goal.carryForward = false
        let strict = CalcEngine.lookup(for: today, among: [earlier, today], blocks: [goal, calc])
        XCTAssertNil(CalcEngine.target(of: calc, blocks: [goal, calc], lookup: strict))
    }

    func testWeekAverageSkipsEmptyDaysAndUsesCurrentSession() {
        let tab = UUID()
        let n = Block(kind: .number, title: "n")
        var calc = Block(kind: .calc, terms: [CalcTerm(blockID: n.id)])
        calc.calcPeriod = .weekAverage
        let stored = [
            session(tab, 5, [n.id: .number(1000)]),
            session(tab, 7, [n.id: .number(2000)]),
            session(tab, 1, [n.id: .number(9999)])      // older than 7 days: ignored
        ]
        let current = session(tab, 10, [n.id: .number(3000)])
        let avg = CalcEngine.displayValue(of: calc, blocks: [n, calc], current: current, sessions: stored, calendar: cal)
        XCTAssertEqual(avg, 2000)
        calc.calcPeriod = .weekTotal
        let total = CalcEngine.displayValue(of: calc, blocks: [n, calc], current: current, sessions: stored, calendar: cal)
        XCTAssertEqual(total, 6000)
    }

    func testNestedCalcAndCycleGuard() {
        let n = Block(kind: .number)
        let inner = Block(kind: .calc, terms: [CalcTerm(blockID: n.id, weight: 2)])
        let outer = Block(kind: .calc, terms: [CalcTerm(blockID: inner.id, weight: 3)])
        let s = session(UUID(), 10, [n.id: .number(5)])
        XCTAssertEqual(CalcEngine.value(of: outer, blocks: [n, inner, outer], lookup: { s.value(for: $0) }), 30)
        var a = Block(kind: .calc), b = Block(kind: .calc)
        a.terms = [CalcTerm(blockID: b.id)]; b.terms = [CalcTerm(blockID: a.id)]
        XCTAssertNil(CalcEngine.value(of: a, blocks: [a, b], lookup: { _ in nil }))
    }

    func testCalcBlockRoundTripsAndOldBlocksDefault() throws {
        var block = Block.make(.calc)
        block.terms = [CalcTerm(blockID: UUID(), column: 2, weight: 4)]
        block.calcPeriod = .weekAverage
        let back = try JSONDecoder().decode(Block.self, from: JSONEncoder().encode(block))
        XCTAssertEqual(back, block)
        let old = try JSONDecoder().decode(Block.self, from: Data(#"{"kind":"number"}"#.utf8))
        XCTAssertEqual(old.calcOp, .sum)
        XCTAssertFalse(old.carryForward)
    }
}
