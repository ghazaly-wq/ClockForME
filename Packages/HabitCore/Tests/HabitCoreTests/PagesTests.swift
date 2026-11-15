import XCTest
@testable import HabitCore

final class PagesTests: XCTestCase {
    let cal = TestSupport.calendar
    func d(_ y: Int, _ m: Int, _ day: Int) -> DayKey { TestSupport.day(y, m, day) }

    // MARK: Schema

    func testPageRoundTripsThroughJSON() throws {
        var page = PageTemplates.workout()
        page.schedule = PageSchedule(repetition: .weekly([.sunday, .tuesday]), time: .clock(hour: 18, minute: 0))
        page.isMainTask = true
        let data = try JSONEncoder().encode(page)
        let back = try JSONDecoder().decode(PageDefinition.self, from: data)
        XCTAssertEqual(page, back)
    }

    func testOldDataWithMissingFieldsStillDecodes() throws {
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","kind":"number"}"#
        let block = try JSONDecoder().decode(Block.self, from: Data(json.utf8))
        XCTAssertEqual(block.kind, .number)
        XCTAssertEqual(block.step, 1)
        XCTAssertTrue(block.showLast)
        let page = try JSONDecoder().decode(PageDefinition.self, from: Data(#"{"name":"x"}"#.utf8))
        XCTAssertEqual(page.name, "x")
        XCTAssertEqual(page.schemaVersion, 1)
        XCTAssertTrue(page.tabs.isEmpty)
    }

    func testBlockValuesRoundTrip() throws {
        let values: [BlockValue] = [
            .text("hi"), .number(3.5), .bool(true), .rows([SetRow(values: [60, nil, 8])]),
            .flags([true, false]), .choices([1, 2]), .date(Date(timeIntervalSince1970: 1000)), .duration(90)
        ]
        for v in values {
            let back = try JSONDecoder().decode(BlockValue.self, from: JSONEncoder().encode(v))
            XCTAssertEqual(v, back)
        }
    }

    func testEveryKindHasADefaultBlockAndName() {
        for kind in BlockKind.allCases {
            let b = Block.make(kind)
            XCTAssertEqual(b.kind, kind)
            XCTAssertFalse(kind.arabicName.isEmpty)
        }
        XCTAssertEqual(Set(BlockKind.categories.flatMap(\.kinds)), Set(BlockKind.allCases))
    }

    func testValueEmptiness() {
        XCTAssertTrue(BlockValue.text("  ").isEmpty)
        XCTAssertFalse(BlockValue.number(0).isEmpty)
        XCTAssertTrue(BlockValue.bool(false).isEmpty)
        XCTAssertTrue(BlockValue.rows([SetRow(values: [nil, nil])]).isEmpty)
        XCTAssertFalse(BlockValue.rows([SetRow(values: [nil, 5])]).isEmpty)
        XCTAssertTrue(BlockValue.flags([false, false]).isEmpty)
        XCTAssertTrue(BlockValue.duration(0).isEmpty)
    }

    // MARK: Tree

    func tree() -> (blocks: [Block], box: Block, inner: Block, outer: Block) {
        let inner = Block.make(.number)
        var box = Block.make(.container)
        box.children = [inner]
        let outer = Block.make(.text)
        return ([box, outer], box, inner, outer)
    }

    func testFlattenFindAndParent() {
        let t = tree()
        XCTAssertEqual(t.blocks.flattened.count, 3)
        XCTAssertEqual(t.blocks.block(withID: t.inner.id)?.id, t.inner.id)
        XCTAssertEqual(t.blocks.parentID(of: t.inner.id), t.box.id)
        XCTAssertNil(t.blocks.parentID(of: t.outer.id))
    }

    func testUpdateRemoveInsert() {
        let t = tree()
        let renamed = t.blocks.updating(t.inner.id) { $0.title = "جديد" }
        XCTAssertEqual(renamed.block(withID: t.inner.id)?.title, "جديد")
        let removed = t.blocks.removing(t.inner.id)
        XCTAssertEqual(removed.flattened.count, 2)
        let extra = Block.make(.counter)
        let inserted = t.blocks.inserting(extra, into: t.box.id, at: 0)
        XCTAssertEqual(inserted[0].children.first?.id, extra.id)
        let top = t.blocks.inserting(extra, into: nil, at: 1)
        XCTAssertEqual(top[1].id, extra.id)
        // Inserting into a non-container is ignored by that block (falls through harmlessly).
        let ignored = t.blocks.inserting(extra, into: t.outer.id)
        XCTAssertEqual(ignored.flattened.count, 3)
    }

    func testMoveIntoAndOutOfContainer() {
        let t = tree()
        let into = t.blocks.moving(t.outer.id, into: t.box.id)
        XCTAssertEqual(into.count, 1)
        XCTAssertEqual(into[0].children.count, 2)
        let out = into.moving(t.inner.id, into: nil, at: 0)
        XCTAssertEqual(out[0].id, t.inner.id)
        // A container can't move into itself.
        XCTAssertEqual(t.blocks.moving(t.box.id, into: t.box.id), t.blocks)
    }

    func testDuplicateGetsNewIDsAndSitsAfterOriginal() {
        let t = tree()
        let dup = t.blocks.duplicating(t.box.id)
        XCTAssertEqual(dup.count, 3)
        XCTAssertNotEqual(dup[1].id, t.box.id)
        XCTAssertNotEqual(dup[1].children[0].id, t.inner.id)
        XCTAssertEqual(Set(dup.flattened.map(\.id)).count, dup.flattened.count)
    }

    func testReorderWithin() {
        let a = Block.make(.text), b = Block.make(.number), c = Block.make(.counter)
        let moved = [a, b, c].movingWithin(nil, from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(moved.map(\.id), [b.id, c.id, a.id])
        let moved2 = [a, b, c].movingWithin(nil, from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(moved2.map(\.id), [c.id, a.id, b.id])
    }

    func testCloneKeepsSourcesPointingAtCopies() {
        let page = PageTemplates.reading()
        let blocks = page.tabs[0].blocks
        let clone = blocks.clonedWithNewIDs()
        let oldIDs = Set(blocks.flattened.map(\.id))
        XCTAssertTrue(oldIDs.isDisjoint(with: Set(clone.flattened.map(\.id))))
        let bar = clone.first { $0.kind == .progress }!
        let counter = clone.first { $0.kind == .counter }!
        XCTAssertEqual(bar.sourceIDs, [counter.id])
    }

    // MARK: Rotation

    func rotatingPage() -> PageDefinition {
        var p = PageTemplates.workout()
        p.schedule = PageSchedule(repetition: .weekly([.sunday, .tuesday, .thursday]), time: .clock(hour: 18, minute: 0))
        p.anchorDay = d(2026, 11, 1)   // a Sunday
        return p
    }

    func testRotationCyclesAThroughC() {
        let p = rotatingPage()
        func name(_ day: DayKey) -> String { PageLogic.tab(for: day, page: p, calendar: cal)!.name }
        XCTAssertEqual(name(d(2026, 11, 1)), "Full Body A")   // Sun
        XCTAssertEqual(name(d(2026, 11, 3)), "Full Body B")   // Tue
        XCTAssertEqual(name(d(2026, 11, 5)), "Full Body C")   // Thu
        XCTAssertEqual(name(d(2026, 11, 8)), "Full Body A")   // next Sun
        // A day without a session gets the next session's tab.
        XCTAssertEqual(name(d(2026, 11, 2)), "Full Body B")   // Mon -> Tue's tab
    }

    func testNoRotationUsesFirstTab() {
        var p = rotatingPage()
        p.rotatesTabs = false
        XCTAssertEqual(PageLogic.tabIndex(for: d(2026, 11, 5), page: p, calendar: cal), 0)
        p.rotatesTabs = true
        p.schedule = nil
        XCTAssertEqual(PageLogic.tabIndex(for: d(2026, 11, 5), page: p, calendar: cal), 0)
        XCTAssertEqual(PageLogic.tabIndex(for: d(2020, 1, 1), page: rotatingPage(), calendar: cal), 0)
    }

    func testRotationAcrossMonthBoundary() {
        let p = rotatingPage()
        // Nov: Sun1 A, Tue3 B, Thu5 C, Sun8 A, Tue10 B, Thu12 C, Sun15 A, Tue17 B, Thu19 C, Sun22 A, Tue24 B, Thu26 C, Sun29 A, Tue Dec1 B
        XCTAssertEqual(PageLogic.tab(for: d(2026, 12, 1), page: p, calendar: cal)?.name, "Full Body B")
    }

    // MARK: History

    func session(_ page: PageDefinition, day: DayKey, hour: Int = 10, finished: Bool = true, _ values: [(UUID, BlockValue)]) -> PageSession {
        var s = PageSession(pageID: page.id, tabID: page.tabs[0].id, day: day, startedAt: Date(timeIntervalSince1970: TimeInterval(day.day * 86400 + hour * 3600)))
        if finished { s.finishedAt = s.startedAt.addingTimeInterval(600) }
        for (id, v) in values { s.set(v, for: id) }
        return s
    }

    func testLastValueSkipsUnfinishedAndEmpty() {
        let page = PageTemplates.reading()
        let counter = page.tabs[0].blocks.first { $0.kind == .counter }!
        let s1 = session(page, day: d(2026, 11, 1), [(counter.id, .number(10))])
        let s2 = session(page, day: d(2026, 11, 2), [(counter.id, .number(0)), ])
        var s3 = session(page, day: d(2026, 11, 3), finished: false, [(counter.id, .number(99))])
        s3.finishedAt = nil
        let sessions = [s1, s2, s3]
        let last = PageLogic.lastValue(of: counter.id, in: sessions, pageID: page.id, before: nil)
        XCTAssertEqual(last, .number(0))   // number(0) is a real value (not "empty")
        let beforeS2 = PageLogic.lastValue(of: counter.id, in: sessions, pageID: page.id, before: s2)
        XCTAssertEqual(beforeS2, .number(10))
        XCTAssertNil(PageLogic.lastValue(of: counter.id, in: sessions, pageID: page.id, before: s1))
    }

    func testSeriesMetricsForSets() {
        let page = PageTemplates.workout()
        let sets = page.tabs[0].blocks.flattened.first { $0.kind == .sets }!
        let rows = BlockValue.rows([SetRow(values: [60, 8]), SetRow(values: [70, 5]), SetRow(values: [nil, nil])])
        let s = session(page, day: d(2026, 11, 1), [(sets.id, rows)])
        XCTAssertEqual(PageLogic.series(of: sets.id, metric: .setsMax, in: [s], pageID: page.id).first?.value, 70)
        XCTAssertEqual(PageLogic.series(of: sets.id, metric: .setsVolume, in: [s], pageID: page.id).first?.value, 60 * 8 + 70 * 5)
        XCTAssertEqual(PageLogic.series(of: sets.id, metric: .setsTotal, in: [s], pageID: page.id).first?.value, 13)
        XCTAssertTrue(PageLogic.series(of: sets.id, metric: .value, in: [s], pageID: page.id).isEmpty)
    }

    func testSeriesIsSortedByDayAndIgnoresOtherPages() {
        let page = PageTemplates.water()
        let cups = page.tabs[0].blocks[0]
        let later = session(page, day: d(2026, 11, 5), [(cups.id, .number(6))])
        let earlier = session(page, day: d(2026, 11, 2), [(cups.id, .number(4))])
        var other = session(page, day: d(2026, 11, 3), [(cups.id, .number(100))])
        other.pageID = UUID()
        let series = PageLogic.series(of: cups.id, metric: .value, in: [later, other, earlier], pageID: page.id)
        XCTAssertEqual(series.map(\.value), [4, 6])
    }

    func testPlaceholderRowsAndProgress() {
        XCTAssertEqual(PageLogic.placeholderRows(from: .rows([SetRow(values: [1, 2])])).count, 1)
        XCTAssertTrue(PageLogic.placeholderRows(from: .number(3)).isEmpty)
        XCTAssertEqual(PageLogic.progress(value: 4, target: 8), 0.5)
        XCTAssertEqual(PageLogic.progress(value: 12, target: 8), 1)
        XCTAssertEqual(PageLogic.progress(value: 4, target: nil), 0)
        XCTAssertEqual(PageLogic.progress(value: 4, target: 0), 0)
    }

    // MARK: Sessions

    func testPrunedDropsValuesOfDeletedBlocks() {
        var page = PageTemplates.water()
        let cups = page.tabs[0].blocks[0]
        var s = session(page, day: d(2026, 11, 1), [(cups.id, .number(3)), (UUID(), .text("gone"))])
        XCTAssertEqual(s.values.count, 2)
        s = PageLogic.pruned(s, keeping: page)
        XCTAssertEqual(s.values.count, 1)
        page.tabs[0].blocks = page.tabs[0].blocks.removing(cups.id)
        XCTAssertTrue(PageLogic.pruned(s, keeping: page).values.isEmpty)
        XCTAssertTrue(PageLogic.cleared(s).values.isEmpty)
    }

    func testHasNoData() {
        let page = PageTemplates.water()
        var s = session(page, day: d(2026, 11, 1), finished: false, [])
        XCTAssertTrue(s.hasNoData)
        s.set(.bool(false), for: UUID())
        XCTAssertTrue(s.hasNoData)
        s.set(.number(1), for: UUID())
        XCTAssertFalse(s.hasNoData)
    }

    // MARK: Scheduling + templates

    func testAlarmRuleFollowsPageSchedule() {
        var page = PageTemplates.reading()
        XCTAssertNil(PageLogic.alarmRule(for: page))
        page.schedule = PageSchedule(repetition: .weekly([.monday]), time: .prayer(.isha, .after, hours: 0, minutes: 30))
        let rule = PageLogic.alarmRule(for: page)!
        XCTAssertEqual(rule.title, "قراءة")
        XCTAssertEqual(rule.repetition, .weekly([.monday]))
        XCTAssertEqual(rule.time, .prayer(.isha, .after, hours: 0, minutes: 30))
        XCTAssertFalse(rule.isMainTask)   // the page owns its task
        XCTAssertTrue(PageLogic.isScheduled(page, on: d(2026, 11, 2), calendar: cal))   // Monday
        XCTAssertFalse(PageLogic.isScheduled(page, on: d(2026, 11, 3), calendar: cal))
    }

    func testTemplatesAreValidAndFresh() {
        for info in PageTemplates.all {
            let a = PageTemplates.make(info.id)!
            let b = PageTemplates.make(info.id)!
            XCTAssertNotEqual(a.id, b.id)
            XCTAssertFalse(a.tabs.isEmpty)
            let ids = a.allBlocks.map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "duplicate block ids in \(info.id)")
            // Every chart/progress source exists and is a chartable/numeric block.
            for block in a.allBlocks where block.kind == .chart || block.kind == .progress {
                XCTAssertFalse(block.sourceIDs.isEmpty)
                for src in block.sourceIDs {
                    let found = ids.contains(src)
                    XCTAssertTrue(found, "\(info.id): missing source")
                }
            }
        }
        XCTAssertNil(PageTemplates.make("nope"))
        XCTAssertEqual(PageTemplates.workout().tabs.count, 3)
        XCTAssertTrue(PageTemplates.workout().rotatesTabs)
        XCTAssertEqual(PageTemplates.blank().tabs.count, 1)
    }
}
