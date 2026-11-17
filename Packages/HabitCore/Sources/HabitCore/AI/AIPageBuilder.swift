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
    - number: title, unit, allowDecimal (bool), target (number, optional)
    - sets: title, columns [two names, e.g. ["الوزن (كجم)","العدّات"]], allowDecimal (bool)
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
    - ai: title, systemPrompt (instructions for an AI helper inside the page), includePageData (bool)

    Rules: input blocks are what the user fills in each session; use containers to group related inputs under a name. Titles inside "sources" must match exact titles of blocks in the same tab. End most pages with a finishSession button. Keep it practical and not too long (under 30 blocks per tab). Never output anything except the JSON object.
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
            var wanted: [UUID: [String]] = [:]
            let blocks = build(tabSpec.blocks ?? [], depth: 0, wanted: &wanted)
            let name = clean(tabSpec.name, limit: 40)
            if blocks.isEmpty { continue }
            let resolved = resolveSources(blocks, wanted: wanted)
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

    private static func build(_ specs: [BlockSpec], depth: Int, wanted: inout [UUID: [String]]) -> [Block] {
        var result: [Block] = []
        var budget = maxBlocksPerTab
        for spec in specs {
            guard budget > 0, let kind = kind(spec.type), allowed.contains(kind) else { continue }
            if kind == .container, depth >= maxDepth - 1 { continue }
            var block = Block.make(kind)
            let title = clean(spec.title, limit: 80)
            if !title.isEmpty || kind == .divider { block.title = title }
            apply(spec, to: &block)
            if kind == .container {
                block.children = build(spec.children ?? [], depth: depth + 1, wanted: &wanted)
                if block.children.isEmpty { continue }
            }
            if kind == .checklist || kind == .choice, block.options.isEmpty { continue }
            if let sources = spec.sources { wanted[block.id] = sources }
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
            if list.count >= 2 { block.columns = Array(list.prefix(2)) }
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
        if block.kind == .ai {
            block.text = String((spec.systemPrompt ?? "").prefix(1500))
            block.aiIncludesPageData = spec.includePageData ?? false
        }
    }

    // MARK: - Chart / progress / history sources

    /// Fills `sourceIDs` by matching the titles the model gave to blocks in the same tab, and drops
    /// charts/progress bars that end up with no valid source.
    private static func resolveSources(_ blocks: [Block], wanted: [UUID: [String]]) -> [Block] {
        let all = blocks.flattened

        func resolved(_ list: [Block]) -> [Block] {
            list.compactMap { original in
                var block = original
                block.children = resolved(block.children)
                if block.kind == .container, block.children.isEmpty { return nil }
                guard [.chart, .progress, .history].contains(block.kind) else { return block }
                let candidates = all.filter { candidate in
                    switch block.kind {
                    case .chart: return candidate.kind.isChartable
                    case .progress: return candidate.kind.isNumeric
                    default: return candidate.kind.isInput
                    }
                }
                var picked: [Block] = []
                for title in wanted[block.id] ?? [] {
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
}
