import Foundation

/// Turns what the user typed on a page into plain text the AI can read ("الوزن: 80"), for AI blocks that opt in.
public enum AIPageContext {
    /// The page as indented text: headings, static text and container names (so the AI knows e.g. which exercise a
    /// sets table belongs to), plus every value typed so far. Containers/headings with nothing under them still
    /// appear, because their names are the context.
    public static func summary(blocks: [Block], session: PageSession) -> String {
        lines(blocks, session: session, depth: 0).joined(separator: "\n")
    }

    private static func lines(_ blocks: [Block], session: PageSession, depth: Int) -> [String] {
        let indent = String(repeating: "  ", count: depth)
        var result: [String] = []
        for block in blocks {
            switch block.kind {
            case .heading, .container:
                let title = block.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { result.append("\(indent)[\(title)]") }
                result += lines(block.children, session: session, depth: block.kind == .container ? depth + 1 : depth)
            case .text:
                let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { result.append("\(indent)\(text)") }
            default:
                guard block.kind.isInput, let value = session.value(for: block.id), !value.isEmpty,
                      let text = describe(value, block: block) else { continue }
                let name = block.title.isEmpty ? block.kind.arabicName : block.title
                let unit = block.unit.isEmpty ? "" : " \(block.unit)"
                result.append("\(indent)\(name): \(text)\(unit)")
            }
        }
        return result
    }

    private static func format(_ number: Double) -> String {
        number == number.rounded() ? String(Int(number)) : String(number)
    }

    private static func describe(_ value: BlockValue, block: Block) -> String? {
        switch value {
        case .text(let text): return text
        case .number(let n), .duration(let n): return format(n)
        case .bool(let flag): return flag ? "نعم" : "لا"
        case .rows(let rows):
            let lines = rows.enumerated().compactMap { index, row -> String? in
                let cells = row.values.map { $0.map(format) ?? "-" }
                guard row.values.contains(where: { $0 != nil }) else { return nil }
                return "(\(index + 1)) " + cells.joined(separator: " × ")
            }
            return lines.isEmpty ? nil : lines.joined(separator: "، ")
        case .flags(let flags):
            let done = zip(block.options, flags).filter { $0.1 }.map(\.0)
            return done.isEmpty ? nil : done.joined(separator: "، ")
        case .choices(let picked):
            let names = picked.compactMap { block.options.indices.contains($0) ? block.options[$0] : nil }
            return names.isEmpty ? nil : names.joined(separator: "، ")
        case .date(let date): return ISO8601DateFormatter().string(from: date)
        }
    }
}
