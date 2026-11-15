import Charts
import HabitCore
import SwiftUI

struct StatisticsView: View {
    let snapshot: ProgressSnapshot
    let completions: [CompletionRecord]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.digitStyle) private var digits

    private let calendar = Calendar.app
    private let heatmapWeeks = 53
    private let chartWeeks = 8
    private let xpDays = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    tiles
                    heatmapCard
                    weeklyCard
                    xpCard
                }
                .padding(20)
            }
            .background(Theme.surface.ignoresSafeArea())
            .navigationTitle("الإحصائيات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                }
            }
        }
    }

    // MARK: - Tiles

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tile("السلسلة الحالية", value: snapshot.streak.current, symbol: "flame.fill")
            tile("أفضل سلسلة", value: snapshot.streak.best, symbol: "trophy.fill")
            tile("المهام المنجزة", value: snapshot.completedTasks, symbol: "checkmark.circle.fill")
            tile("الأيام المكتملة", value: snapshot.streak.completeDays, symbol: "calendar.badge.checkmark")
        }
    }

    private func tile(_ title: LocalizedStringKey, value: Int, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.primaryStrong)
                .accessibilityHidden(true)
            Text(digits.format(value))
                .font(.title.bold().monospacedDigit())
                .fontDesign(.rounded)
                .foregroundStyle(Theme.textPrimary)
            Text(title)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        let cells = StatsCalculator.heatmap(
            progressByDay: snapshot.progressByDay, today: snapshot.today, weeks: heatmapWeeks, calendar: calendar
        )
        let completeCount = cells.filter { $0.state == .complete }.count
        let lookup = Dictionary(uniqueKeysWithValues: cells.map { ($0.column * 7 + $0.row, $0) })

        return VStack(alignment: .leading, spacing: 10) {
            Text("آخر سنة")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 3) {
                        ForEach(0..<heatmapWeeks, id: \.self) { column in
                            VStack(spacing: 3) {
                                ForEach(0..<7, id: \.self) { row in
                                    cell(lookup[column * 7 + row]?.state)
                                }
                            }
                            .id(column)
                        }
                    }
                }
                .onAppear { proxy.scrollTo(heatmapWeeks - 1, anchor: .trailing) }
            }
            // Oldest week on the left, newest on the right, regardless of the app direction.
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(digits.format(String(localized: "خريطة الأيام: \(completeCount) يوماً مكتملاً في آخر سنة"))))

            HStack(spacing: 14) {
                legend(.complete, "مكتمل")
                legend(.partial, "جزئي")
                legend(.none, "لم تُنجز")
                legend(.noTasks, "بدون مهام")
            }
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Each state differs in shape or fill, not just color.
    @ViewBuilder
    private func cell(_ state: DayProgress.State?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        Group {
            switch state {
            case .complete:
                shape.fill(Theme.primary)
                    .overlay { Image(systemName: "checkmark").font(.system(size: 8, weight: .black)).foregroundStyle(.white) }
            case .partial:
                shape.fill(Theme.primary.opacity(0.4))
                    .overlay { Rectangle().fill(Theme.primary).frame(height: 2) }
            case .some(.none):
                shape.strokeBorder(Theme.textSecondary.opacity(0.7), lineWidth: 1.5)
            case .some(.noTasks):
                shape.fill(Theme.textSecondary.opacity(0.12))
            case nil:
                Color.clear
            }
        }
        .frame(width: 14, height: 14)
    }

    private func legend(_ state: DayProgress.State, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            cell(state)
            Text(title)
        }
    }

    // MARK: - Weekly completion

    private var weeklyCard: some View {
        let weeks = StatsCalculator.weeklyCompletion(
            progressByDay: snapshot.progressByDay, today: snapshot.today, weeks: chartWeeks, calendar: calendar
        )

        return VStack(alignment: .leading, spacing: 10) {
            Text("نسبة الإنجاز الأسبوعية")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Chart {
                ForEach(weeks, id: \.start) { week in
                    BarMark(
                        x: .value("الأسبوع", dayLabel(week.start)),
                        y: .value("النسبة", week.fraction * 100)
                    )
                    .foregroundStyle(Theme.primary)
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        if week.hadTasks {
                            Text(digits.format("\(Int((week.fraction * 100).rounded()))%"))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let number = value.as(Int.self) {
                            Text(digits.format("\(number)%")).font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().font(.caption2) }
            }
            .frame(height: 180)
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityLabel(Text(weeklySummary(weeks)))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func weeklySummary(_ weeks: [WeekPoint]) -> String {
        guard let current = weeks.last else { return "" }
        return digits.format(String(localized: "نسبة إنجاز هذا الأسبوع \(Int((current.fraction * 100).rounded()))٪"))
    }

    private func dayLabel(_ day: DayKey) -> String {
        digits.format("\(day.day)/\(day.month)")
    }

    // MARK: - XP

    private var xpCard: some View {
        var perDay: [DayKey: Int] = [:]
        for completion in completions { perDay[completion.day, default: 0] += 1 }
        let to = snapshot.today
        let from = to.adding(days: -(xpDays - 1), calendar: calendar) ?? to
        let points = StatsCalculator.xpTimeline(
            completedTasksByDay: perDay, progressByDay: snapshot.progressByDay, from: from, to: to, calendar: calendar
        )

        return VStack(alignment: .leading, spacing: 10) {
            Text("الخبرة في آخر 30 يوماً")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("من المهام والأيام المكتملة، بدون مكافآت الإنجازات.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            Chart {
                ForEach(points, id: \.day) { point in
                    if let date = point.day.startDate(calendar: calendar) {
                        LineMark(x: .value("اليوم", date), y: .value("الخبرة", point.cumulativeXP))
                            .foregroundStyle(Theme.primary)
                            .interpolationMethod(.monotone)
                        AreaMark(x: .value("اليوم", date), y: .value("الخبرة", point.cumulativeXP))
                            .foregroundStyle(Theme.primary.opacity(0.15))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            let parts = calendar.dateComponents([.day, .month], from: date)
                            Text(digits.format("\(parts.day ?? 0)/\(parts.month ?? 0)")).font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let number = value.as(Int.self) { Text(digits.format(number)).font(.caption2) }
                    }
                }
            }
            .frame(height: 180)
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityLabel(Text(digits.format(String(localized: "مجموع الخبرة \(points.last?.cumulativeXP ?? 0)"))))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
