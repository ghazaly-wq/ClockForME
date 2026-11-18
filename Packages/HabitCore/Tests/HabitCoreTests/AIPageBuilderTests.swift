import XCTest
@testable import HabitCore

final class AIPageBuilderTests: XCTestCase {
    private func build(_ json: String) -> PageDefinition? {
        if case .success(let page) = AIPageBuilder.page(from: json) { return page }
        return nil
    }

    func testBuildsPageFromFencedJSONWithChatter() {
        let reply = """
        هذي الصفحة:
        ```json
        {"name":"تمرين الصدر","emoji":"🏋️","accent":"blue","tabs":[{"name":"يوم 1","blocks":[
          {"type":"container","title":"بنش","children":[
            {"type":"sets","title":"المجموعات","columns":["الوزن","العدّات"]},
            {"type":"timer","title":"راحة","seconds":90}]},
          {"type":"chart","title":"تطور البنش","sources":["المجموعات"],"metric":"setsMax"},
          {"type":"button","title":"إنهاء","action":"finishSession"}]}]}
        ```
        """
        let page = build(reply)
        XCTAssertEqual(page?.name, "تمرين الصدر")
        XCTAssertEqual(page?.accent, "blue")
        let blocks = page?.tabs.first?.blocks ?? []
        XCTAssertEqual(blocks.map(\.kind), [.container, .chart, .button])
        let sets = blocks[0].children.first { $0.kind == .sets }
        XCTAssertEqual(blocks[1].sourceIDs, [sets?.id].compactMap { $0 })
        XCTAssertEqual(blocks[1].metric, .setsMax)
        XCTAssertEqual(blocks[2].action, .finishSession)
    }

    func testUnknownTypesImagesAndLinksAreDropped() {
        let page = build(#"{"name":"x","tabs":[{"name":"a","blocks":[{"type":"hologram"},{"type":"image"},{"type":"link","title":"l"},{"type":"text","text":"hi"}]}]}"#)
        XCTAssertEqual(page?.tabs.first?.blocks.map(\.kind), [.text])
    }

    func testChartWithoutValidSourceIsDropped() {
        let page = build(#"{"name":"x","tabs":[{"name":"a","blocks":[{"type":"number","title":"وزن"},{"type":"chart","title":"c","sources":["غير موجود"]},{"type":"chart","title":"c2","sources":["وزن"],"metric":"setsMax"}]}]}"#)
        let blocks = page?.tabs.first?.blocks ?? []
        XCTAssertEqual(blocks.map(\.kind), [.number, .chart])
        XCTAssertEqual(blocks[1].metric, .value)   // a number block can't use a sets metric
    }

    func testValuesAreClampedAndDefaultsApplied() {
        let page = build(#"{"name":"  ","accent":"neon","tabs":[{"name":"","blocks":[{"type":"timer","seconds":99999},{"type":"rating","maxRating":50},{"type":"checklist","title":"فاضي","options":[]},{"type":"counter","target":-5}]}]}"#)
        XCTAssertEqual(page?.name, "صفحة جديدة")
        XCTAssertEqual(page?.accent, "green")
        XCTAssertEqual(page?.tabs.first?.name, "الرئيسية")
        let blocks = page?.tabs.first?.blocks ?? []
        XCTAssertEqual(blocks.map(\.kind), [.timer, .rating, .counter])
        XCTAssertEqual(blocks[0].seconds, 7200)
        XCTAssertEqual(blocks[1].maxRating, 10)
        XCTAssertNil(blocks[2].target)
    }

    func testNestedContainersAreFlattenedOutAndEmptyOnesRemoved() {
        let page = build(#"{"name":"x","tabs":[{"name":"a","blocks":[{"type":"container","title":"outer","children":[{"type":"container","title":"inner","children":[{"type":"number","title":"n"}]},{"type":"number","title":"m"}]},{"type":"container","title":"empty","children":[]}]}]}"#)
        let blocks = page?.tabs.first?.blocks ?? []
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].children.map(\.kind), [.number])
    }

    func testRotationOnlyWithSeveralTabsAndAIBlockFields() {
        let one = build(#"{"name":"x","rotatesTabs":true,"tabs":[{"name":"a","blocks":[{"type":"divider"}]}]}"#)
        XCTAssertEqual(one?.rotatesTabs, false)
        let two = build(#"{"name":"x","rotatesTabs":true,"tabs":[{"name":"a","blocks":[{"type":"ai","title":"مدرب","systemPrompt":"كن مختصراً","includePageData":true}]},{"name":"b","blocks":[{"type":"divider"}]}]}"#)
        XCTAssertEqual(two?.rotatesTabs, true)
        let ai = two?.tabs.first?.blocks.first
        XCTAssertEqual(ai?.text, "كن مختصراً")
        XCTAssertEqual(ai?.aiIncludesPageData, true)
    }

    func testBadReplies() {
        XCTAssertEqual(AIPageBuilder.page(from: "no json here"), .failure(.noJSON))
        XCTAssertEqual(AIPageBuilder.page(from: "{ not json }"), .failure(.badJSON))
        XCTAssertEqual(AIPageBuilder.page(from: #"{"name":"x","tabs":[]}"#), .failure(.empty))
    }
}

final class AIPageBuilderCalcTests: XCTestCase {
    private func page(_ json: String) -> PageDefinition? {
        if case .success(let page) = AIPageBuilder.page(from: json) { return page }
        return nil
    }

    private let tracker = #"""
    {"name":"سعراتي","tabs":[{"name":"اليوم","blocks":[
      {"type":"number","title":"هدف السعرات","persistent":true},
      {"type":"container","title":"الفطور","children":[{"type":"sets","title":"الأطعمة","columns":["السعرات","البروتين"]}]},
      {"type":"container","title":"الغداء","children":[{"type":"sets","title":"الأطعمة","columns":["السعرات","البروتين"]}]},
      {"type":"calc","title":"سعرات اليوم","terms":[{"source":"الأطعمة","column":"السعرات"}],"targetSource":"هدف السعرات"},
      {"type":"calc","title":"متوسط البروتين","period":"weekAverage","terms":[{"source":"الأطعمة","column":2}]}
    ]}]}
    """#

    func testCalcTermsExpandToEverySetsTableWithThatTitle() {
        let tab = page(tracker)?.tabs.first
        let blocks = tab?.blocks ?? []
        let calc = blocks.first { $0.title == "سعرات اليوم" }
        XCTAssertEqual(calc?.terms.count, 2)
        XCTAssertEqual(calc?.terms.map(\.column), [0, 0])
        let goal = blocks.first { $0.title == "هدف السعرات" }
        XCTAssertEqual(goal?.carryForward, true)
        XCTAssertEqual(calc?.targetSourceID, goal?.id)
        let protein = blocks.first { $0.title == "متوسط البروتين" }
        XCTAssertEqual(protein?.calcPeriod, .weekAverage)
        XCTAssertEqual(protein?.terms.map(\.column), [1, 1])
    }

    func testCalcWithoutResolvableTermsIsDropped() {
        let result = page(#"{"name":"x","tabs":[{"name":"a","blocks":[{"type":"number","title":"n"},{"type":"calc","title":"c","terms":[{"source":"nope"}]}]}]}"#)
        XCTAssertEqual(result?.tabs.first?.blocks.map(\.kind), [.number])
    }
}
