import HabitCore
import SwiftUI

/// A computed value (sum, average, percentage…) of other blocks, with an optional goal and progress bar.
struct CalcBlockView: View {
    let block: Block
    let page: PageDefinition
    let runtime: PageRuntime

    @Environment(\.digitStyle) private var digits

    private func fmt(_ value: Double) -> String {
        NumberFormatting.string((value * 10).rounded() / 10, style: digits)
    }

    var body: some View {
        let tab = page.tabs.first { $0.id == runtime.session.tabID } ?? page.tabs.first
        let blocks = (tab?.blocks ?? []).flattened
        let value = CalcEngine.displayValue(
            of: block, blocks: blocks, current: runtime.session, sessions: runtime.allSessions, calendar: Calendar.app
        )
        let lookup = CalcEngine.lookup(for: runtime.session, among: runtime.allSessions + [runtime.session], blocks: blocks)
        let goal = CalcEngine.target(of: block, blocks: blocks, lookup: lookup)
        let unit = block.unit.isEmpty ? "" : " " + block.unit

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(block.title.isEmpty ? "الحساب" : block.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if block.calcPeriod != .today {
                    Text(block.calcPeriod.arabicName)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Text(value.map { fmt($0) + unit } ?? "—")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            if let goal, goal > 0 {
                ProgressView(value: min(max((value ?? 0) / goal, 0), 1))
                    .tint(Theme.primary)
                let remaining = goal - (value ?? 0)
                Text(remaining >= 0
                     ? "الهدف \(fmt(goal))\(unit) · المتبقي \(fmt(remaining))"
                     : "الهدف \(fmt(goal))\(unit) · تعدّيته بـ \(fmt(-remaining))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
