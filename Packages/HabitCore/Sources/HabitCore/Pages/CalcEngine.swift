import Foundation

/// How a calc block combines its terms.
public enum CalcOp: String, Codable, CaseIterable, Sendable {
    case sum, average, difference, product, ratio

    public var arabicName: String {
        switch self {
        case .sum: return "جمع"
        case .average: return "متوسط"
        case .difference: return "طرح (الأول ناقص الباقي)"
        case .product: return "ضرب"
        case .ratio: return "قسمة (الأول ÷ الثاني)"
        }
    }
}

/// Over which days a calc block is computed.
public enum CalcPeriod: String, Codable, CaseIterable, Sendable {
    case today, weekAverage, weekTotal

    public var arabicName: String {
        switch self {
        case .today: return "اليوم"
        case .weekAverage: return "متوسط آخر 7 أيام"
        case .weekTotal: return "مجموع آخر 7 أيام"
        }
    }
}

/// One input of a calc block: a block, which column to read when it is a sets table (0-based), and a multiplier.
public struct CalcTerm: Codable, Equatable, Sendable {
    public var blockID: UUID
    public var column: Int?
    public var weight: Double

    public init(blockID: UUID, column: Int? = nil, weight: Double = 1) {
        self.blockID = blockID; self.column = column; self.weight = weight
    }

    enum CodingKeys: String, CodingKey { case blockID, column, weight }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        blockID = try c.decode(UUID.self, forKey: .blockID)
        column = try c.decodeIfPresent(Int.self, forKey: .column)
        weight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 1
    }
}

/// Evaluates calc blocks from the values typed in sessions. Pure.
public enum CalcEngine {
    public typealias Lookup = (UUID) -> BlockValue?

    static let maxDepth = 4

    // MARK: Values

    /// The number a term contributes (already multiplied by its weight), or nil when nothing was entered.
    public static func termValue(_ term: CalcTerm, blocks: [Block], lookup: Lookup, depth: Int = 0) -> Double? {
        guard let block = blocks.first(where: { $0.id == term.blockID }) else { return nil }
        if block.kind == .calc {
            guard depth < maxDepth, let v = value(of: block, blocks: blocks, lookup: lookup, depth: depth + 1) else { return nil }
            return v * term.weight
        }
        guard let value = lookup(block.id) else { return nil }
        let number: Double?
        switch value {
        case .number(let n), .duration(let n): number = n
        case .bool(let flag): number = flag ? 1 : 0
        case .flags(let flags): number = Double(flags.filter { $0 }.count)
        case .choices(let picked): number = Double(picked.count)
        case .rows(let rows):
            let column = term.column ?? 0
            let cells = rows.compactMap { row in row.values.indices.contains(column) ? row.values[column] : nil }
            number = cells.isEmpty ? nil : cells.reduce(0, +)
        case .text, .date: number = nil
        }
        return number.map { $0 * term.weight }
    }

    /// The calc block's value for one session's values (ignoring `calcPeriod`).
    public static func value(of calc: Block, blocks: [Block], lookup: Lookup, depth: Int = 0) -> Double? {
        let values = calc.terms.map { termValue($0, blocks: blocks, lookup: lookup, depth: depth) }
        let present = values.compactMap { $0 }
        let result: Double?
        switch calc.calcOp {
        case .sum:
            result = present.isEmpty ? nil : present.reduce(0, +)
        case .average:
            result = present.isEmpty ? nil : present.reduce(0, +) / Double(present.count)
        case .difference:
            if let first = values.first, let head = first {
                result = head - values.dropFirst().compactMap { $0 }.reduce(0, +)
            } else { result = nil }
        case .product:
            result = (values.isEmpty || values.contains { $0 == nil }) ? nil : present.reduce(1, *)
        case .ratio:
            if values.count >= 2, let a = values[0], let b = values[1], b != 0 { result = a / b } else { result = nil }
        }
        guard let result, result.isFinite else { return nil }
        return result * calc.calcScale
    }

    /// The goal of a calc block: its own `target`, else the value of the block it points at.
    public static func target(of calc: Block, blocks: [Block], lookup: Lookup) -> Double? {
        if let target = calc.target, target > 0 { return target }
        guard let id = calc.targetSourceID else { return nil }
        let term = CalcTerm(blockID: id)
        let v = termValue(term, blocks: blocks, lookup: lookup)
        return (v ?? 0) > 0 ? v : nil
    }

    // MARK: Sessions

    /// Values of one session; blocks marked `carryForward` fall back to the last value typed on an earlier day.
    public static func lookup(for session: PageSession, among sessions: [PageSession], blocks: [Block]) -> Lookup {
        let earlier = sessions
            .filter { $0.id != session.id && ($0.day, $0.startedAt) < (session.day, session.startedAt) }
            .sorted { ($0.day, $0.startedAt) > ($1.day, $1.startedAt) }
        return { id in
            if let value = session.value(for: id), !value.isEmpty { return value }
            guard blocks.first(where: { $0.id == id })?.carryForward == true else { return nil }
            for past in earlier {
                if let value = past.value(for: id), !value.isEmpty { return value }
            }
            return nil
        }
    }

    /// The value shown for a calc block, honouring its period. `sessions` are all sessions of the page (any state);
    /// `current` replaces the stored copy of itself so edits show instantly.
    public static func displayValue(
        of calc: Block, blocks: [Block], current: PageSession, sessions: [PageSession], calendar: Calendar
    ) -> Double? {
        var all = sessions.filter { $0.id != current.id }
        all.append(current)
        switch calc.calcPeriod {
        case .today:
            return value(of: calc, blocks: blocks, lookup: lookup(for: current, among: all, blocks: blocks))
        case .weekAverage, .weekTotal:
            var perDay: [Double] = []
            for offset in 0..<7 {
                guard let day = current.day.adding(days: -offset, calendar: calendar) else { continue }
                let sameDay = all.filter { $0.day == day && $0.tabID == current.tabID }
                guard let session = sameDay.max(by: { $0.startedAt < $1.startedAt }) else { continue }
                if let v = value(of: calc, blocks: blocks, lookup: lookup(for: session, among: all, blocks: blocks)) {
                    perDay.append(v)
                }
            }
            guard !perDay.isEmpty else { return nil }
            let total = perDay.reduce(0, +)
            return calc.calcPeriod == .weekTotal ? total : total / Double(perDay.count)
        }
    }
}
