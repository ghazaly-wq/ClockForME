import Foundation

/// Lets an AI design a page. The model answers with a small JSON "spec" (not the app's storage format); this turns it
/// into a real `PageDefinition`, dropping anything invalid and keeping sizes sane. Pure and unit-tested.
public enum AIPageBuilder {
    public enum BuildError: Error, Equatable, Sendable {
        case noJSON, badJSON, empty
    }

    public static let maxTabs = 8
    public static let maxBlocksPerTab = 40
    public static let maxDepth = 2

    /// Instructions for the model.
    public static let systemPrompt = """
    You design pages for a personal habits app. A page has tabs; each tab has blocks. Reply with ONE JSON object only (no explanation, no markdown fences), written in the user's language (Arabic unless asked otherwise).

    JSON shape:
    {"name": string, "emoji": one emoji, "accent": "green"|"blue"|"purple"|"orange"|"pink"|"gray",
     "rotatesTabs": bool (true only if the tabs are meant to alternate between sessions, like workout A/B/C),
     "tabs": [{"name": string, "blocks": [BLOCK]}]}

    BLOCK = {"type": TYPE, "title": string, ...fields}
    TYPE and its fields:
    - heading: title
    - text: text (a static note)
    - container: title, children [BLOCK] (a titled box, e.g. one exercise; children may not contain containers)
    - textField: title, multiline (bool)
    - number: title, unit, allowDecimal (bool), target (number, optional), persistent (bool: true for goals/settings the user enters once, like a daily calorie goal; its value is remembered on later days)
    - sets: title, columns [2 to 4 column names, e.g. ["الوزن (كجم)","العدّات"] or ["السعرات","البروتين","الكارب","الدهون"]], allowDecimal (bool). The user can add as many rows as they like (one row per set, or per food item).
    - counter: title, unit, target (number, optional)
    - checkbox: title
    - checklist: title, options [items]
    - choice: title, options [choices], multiSelect (bool)
    - rating: title, maxRating (3 to 10)
    - dateTime: title
    - timer: title, seconds (5 to 7200)
    - stopwatch: title
    - progress: title, sources [titles of number/counter/rating/stopwatch blocks in the same tab], target (optional)
    - chart: title, sources [titles of number/sets/counter/rating/stopwatch blocks in the same tab], metric ("value" | "setsMax" | "setsVolume" | "setsTotal"; use setsMax/setsVolume/setsTotal only for sets blocks)
    - history: title, sources [titles of input blocks in the same tab]
    - divider
    - button: title, action ("finishSession" | "clearFields")
    - calc: title, unit, terms [{"source": title of a block (or of a container, meaning every number/sets block inside it) in the same tab, "column": name of the sets column to read (only for sets), "weight": multiplier, default 1}], op ("sum" | "average" | "difference" | "product" | "ratio"; default sum; difference = first minus the rest; ratio = first divided by second), period ("today" | "weekAverage" | "weekTotal"; default today; week = last 7 days), scale (number multiplied into the result, default 1), target (number, optional goal) or targetSource (title of a number/calc block holding the goal). The calc shows its value with a progress bar toward the goal.
    - ai: title, systemPrompt (instructions for an AI helper inside the page), includePageData (bool)

    Rules: input blocks are what the user fills in each session; use containers to group related inputs under a name. Titles inside "sources" must match exact titles of blocks in the same tab. End most pages with a finishSession button. Keep it practical and not too long (under 30 blocks per tab). For totals, averages, percentages and goals use calc blocks. Typical pattern for a calorie/macro tracker: a tab with persistent number blocks for the goals; one container per meal, each with a sets block whose columns are the nutrients and whose rows are the foods; then calc blocks: daily total of each nutrient (terms with source = the sets title shared by all meals, one calc per column), calories computed from macros if useful (weights 4, 4, 9), a calc with period weekAverage for the 7-day average, and targetSource pointing at the goal blocks. Percent of calories from protein = ratio of (protein term with weight 4) over (calories term), scale 100. Do not invent block types. Keep the JSON compact: no comments, no trailing commas, short titles. Never output anything except the JSON object.
    """

    // MARK: - Spec (what the model returns)

    private struct Spec: Decodable {
        var name: String?
        var emoji: String?
        var accent: String?
        var rotatesTabs: Bool?
        var tabs: [TabSpec]?
    }

    private struct TabSpec: Decodable {
        var name: String?
        var blocks: [BlockSpec]?
    }

    private struct BlockSpec: Decodable {
        var type: String?
        var title: String?
        var text: String?
        var unit: String?
        var allowDecimal: Bool?
        var multiline: Bool?
        var options: [String]?
        var multiSelect: Bool?
        var columns: [String]?
        var maxRating: Int?
        var seconds: Int?
        var target: Double?
        var sources: [String]?
        var metric: String?
        var action: String?
        var systemPrompt: String?
        var includePageData: Bool?
        var children: [BlockSpec]?
        var op: String?
        var period: String?
        var scale: Double?
        var terms: [TermSpec]?
        var targetSource: String?
        var persistent: Bool?
    }

    /// A calc input as the model writes it. `column` may be a column name or a 1-based number.
    private struct TermSpec: Decodable {
        var source: String?
        var column: String?
        var weight: Double?

        enum CodingKeys: String, CodingKey { case source, column, weight }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            source = try? c.decode(String.self, forKey: .source)
            weight = try? c.decode(Double.self, forKey: .weight)
            if let text = try? c.decode(String.self, forKey: .column) {
                column = text
            } else if let number = try? c.decode(Int.self, forKey: .column) {
                column = String(number)
            }
        }
    }

    private static let accents: Set<String> = ["green", "blue", "purple", "orange", "pink", "gray"]

    // MARK: - Parsing

    /// The JSON object inside a model reply (tolerates ```json fences and chatter around it).
    public static func extractJSON(_ reply: String) -> Data? {
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}"), start < end else { return nil }
        return String(reply[start...end]).data(using: .utf8)
    }

    public static func page(from reply: String) -> Result<PageDefinition, BuildError> {
        guard let data = extractJSON(reply) else { return .failure(.noJSON) }
        guard let spec = try? JSONDecoder().decode(Spec.self, from: data) else { return .failure(.badJSON) }

        var tabs: [PageTab] = []
        for tabSpec in (spec.tabs ?? []).prefix(maxTabs) {
            var specs: [UUID: BlockSpec] = [:]
            let blocks = build(tabSpec.blocks ?? [], depth: 0, specs: &specs)
            let name = clean(tabSpec.name, limit: 40)
            if blocks.isEmpty { continue }
            let resolved = resolveSources(blocks, specs: specs)
            if resolved.isEmpty { continue }
            tabs.append(PageTab(name: name.isEmpty ? "الرئيسية" : name, blocks: resolved))
        }
        guard !tabs.isEmpty else { return .failure(.empty) }

        let name = clean(spec.name, limit: 50)
        let emoji = clean(spec.emoji, limit: 4)
        return .success(PageDefinition(
            name: name.isEmpty ? "صفحة جديدة" : name,
            emoji: emoji.isEmpty ? "📄" : String(emoji.prefix(2)),
            accent: accents.contains(spec.accent ?? "") ? spec.accent! : "green",
            tabs: tabs,
            rotatesTabs: tabs.count > 1 && (spec.rotatesTabs ?? false)
        ))
    }

    private static func clean(_ text: String?, limit: Int) -> String {
        String((text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    private static func kind(_ type: String?) -> BlockKind? {
        guard let type else { return nil }
        let wanted = type.trimmingCharacters(in: .whitespaces).lowercased()
        return BlockKind.allCases.first { $0.rawValue.lowercased() == wanted }
    }

    /// Blocks the model may use. Images need a file and links need a validated URL, so they're not offered.
    private static let allowed: Set<BlockKind> = Set(BlockKind.allCases).subtracting([.image, .link])

    private static func build(_ items: [BlockSpec], depth: Int, specs: inout [UUID: BlockSpec]) -> [Block] {
        var result: [Block] = []
        var budget = maxBlocksPerTab
        for spec in items {
            guard budget > 0, let kind = kind(spec.type), allowed.contains(kind) else { continue }
            if kind == .container, depth >= maxDepth - 1 { continue }
            var block = Block.make(kind)
            let title = clean(spec.title, limit: 80)
            if !title.isEmpty || kind == .divider { block.title = title }
            apply(spec, to: &block)
            if kind == .container {
                block.children = build(spec.children ?? [], depth: depth + 1, specs: &specs)
                if block.children.isEmpty { continue }
            }
            if kind == .checklist || kind == .choice, block.options.isEmpty { continue }
            specs[block.id] = spec
            result.append(block)
            budget -= 1 + block.children.count
        }
        return result
    }

    private static func apply(_ spec: BlockSpec, to block: inout Block) {
        if let text = spec.text { block.text = String(text.prefix(500)) }
        if let unit = spec.unit { block.unit = String(unit.prefix(12)) }
        if let flag = spec.allowDecimal { block.allowDecimal = flag }
        if let flag = spec.multiline { block.multiline = flag }
        if let flag = spec.multiSelect { block.multiSelect = flag }
        if let options = spec.options {
            let list = options.map { clean($0, limit: 60) }.filter { !$0.isEmpty }
            block.options = Array(list.prefix(20))
        }
        if let columns = spec.columns, block.kind == .sets {
            let list = columns.map { clean($0, limit: 30) }.filter { !$0.isEmpty }
            if !list.isEmpty { block.columns = Array(list.prefix(4)) }
        }
        if let rating = spec.maxRating { block.maxRating = min(max(rating, 3), 10) }
        if let seconds = spec.seconds { block.seconds = min(max(seconds, 5), 7200) }
        if let target = spec.target, target > 0, target.isFinite { block.target = target }
        if let metric = spec.metric, let value = ChartMetric(rawValue: metric) { block.metric = value }
        if block.kind == .button {
            switch spec.action {
            case "clearFields": block.action = .clearFields
            default: block.action = .finishSession
            }
        }
        if block.kind == .calc {
            if let name = spec.op, let op = CalcOp(rawValue: name) { block.calcOp = op }
            if let name = spec.period, let period = CalcPeriod(rawValue: name) { block.calcPeriod = period }
            if let scale = spec.scale, scale.isFinite, scale != 0 { block.calcScale = scale }
        }
        if (block.kind == .number || block.kind == .counter), spec.persistent == true { block.carryForward = true }
        if block.kind == .ai {
            block.text = String((spec.systemPrompt ?? "").prefix(1500))
            block.aiIncludesPageData = spec.includePageData ?? false
        }
    }

    // MARK: - Chart / progress / history sources

    /// Fills `sourceIDs` by matching the titles the model gave to blocks in the same tab, and drops
    /// charts/progress bars that end up with no valid source.
    private static let calcInputs: Set<BlockKind> = [.number, .counter, .sets, .stopwatch, .rating, .checkbox, .checklist, .calc]

    private static func resolveSources(_ blocks: [Block], specs: [UUID: BlockSpec]) -> [Block] {
        let all = blocks.flattened

        /// Blocks a title refers to: every block with that title, or, for a container, everything inside it.
        func matches(_ title: String, among kinds: Set<BlockKind>) -> [Block] {
            let direct = all.filter { $0.title == title && kinds.contains($0.kind) }
            if !direct.isEmpty { return direct }
            return all.filter { $0.kind == .container && $0.title == title }
                .flatMap { $0.children.flattened }
                .filter { kinds.contains($0.kind) }
        }

        func resolved(_ list: [Block]) -> [Block] {
            list.compactMap { original in
                var block = original
                block.children = resolved(block.children)
                if block.kind == .container, block.children.isEmpty { return nil }
                let spec = specs[block.id]
                if block.kind == .calc { return resolveCalc(block, spec: spec, matches: matches) }
                guard [.chart, .progress, .history].contains(block.kind) else { return block }
                let candidates = all.filter { candidate in
                    switch block.kind {
                    case .chart: return candidate.kind.isChartable
                    case .progress: return candidate.kind.isNumeric
                    default: return candidate.kind.isInput
                    }
                }
                var picked: [Block] = []
                for title in spec?.sources ?? [] {
                    if let match = candidates.first(where: { $0.title == title }), !picked.contains(where: { $0.id == match.id }) {
                        picked.append(match)
                    }
                }
                guard !picked.isEmpty else { return nil }
                block.sourceIDs = picked.map(\.id)
                if block.kind == .chart {
                    let allSets = picked.allSatisfy { $0.kind == .sets }
                    if allSets { if block.metric == .value { block.metric = .setsMax } } else { block.metric = .value }
                }
                return block
            }
        }
        return resolved(blocks)
    }

    private static func resolveCalc(_ original: Block, spec: BlockSpec?, matches: (String, Set<BlockKind>) -> [Block]) -> Block? {
        var block = original
        var terms: [CalcTerm] = []
        for term in spec?.terms ?? [] {
            guard let source = term.source else { continue }
            for target in matches(source, calcInputs) where target.id != block.id {
                var column: Int?
                if target.kind == .sets {
                    guard let named = term.column else { column = 0; terms.append(CalcTerm(blockID: target.id, column: 0, weight: term.weight ?? 1)); continue }
                    let names = target.columns
                    if let index = names.firstIndex(of: named) {
                        column = index
                    } else if let number = Int(named), number >= 1, number <= max(names.count, 1) {
                        column = number - 1
                    } else {
                        continue   // this sets table doesn't have that column
                    }
                }
                terms.append(CalcTerm(blockID: target.id, column: column, weight: term.weight ?? 1))
            }
        }
        // Drop duplicates, cap the size.
        var seen = Set<String>()
        terms = terms.filter { seen.insert("\($0.blockID)|\($0.column ?? -1)|\($0.weight)").inserted }
        guard !terms.isEmpty else { return nil }
        block.terms = Array(terms.prefix(40))
        if let title = spec?.targetSource, block.target == nil {
            block.targetSourceID = matches(title, [.number, .counter, .calc]).first { $0.id != block.id }?.id
        }
        return block
    }
}
