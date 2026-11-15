import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    /// `nil` when the app has not written anything yet (or the container is unreachable).
    let snapshot: WidgetSnapshot?
}

struct TodayProvider: TimelineProvider {
    private static let sample = WidgetSnapshot(
        generatedAt: Date(),
        dayEnd: Date().addingTimeInterval(8 * 3600),
        items: [
            .init(id: "1", title: "مهمة", time: nil, done: true),
            .init(id: "2", title: "مهمة", time: nil, done: false),
            .init(id: "3", title: "مهمة", time: nil, done: false)
        ],
        streak: 7, level: 3, levelTitle: "مبتدئ",
        nextAlarmTitle: nil, nextAlarmDate: nil, arabicDigits: false, styleID: "live.default"
    )

    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), snapshot: context.isPreview ? Self.sample : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        guard let snapshot = WidgetSnapshot.load(), snapshot.dayEnd > now else {
            // Nothing for today yet: ask again soon (opening the app also reloads us).
            completion(Timeline(entries: [TodayEntry(date: now, snapshot: nil)], policy: .after(now.addingTimeInterval(30 * 60))))
            return
        }
        // One entry per task time, so "next task" stays right without the app running.
        var dates: [Date] = [now]
        dates += snapshot.allTimes.filter { $0 > now && $0 < snapshot.dayEnd }.sorted()
        dates.append(snapshot.dayEnd)
        let entries = dates.map { TodayEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var isAccessory: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
        default: return false
        }
    }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, entry.date < snapshot.dayEnd {
                content(snapshot)
            } else {
                stale
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar_SA"))
        .widgetURL(DeepLink.today)
        .containerBackground(for: .widget) {
            isAccessory ? Color.clear : Theme.surface
        }
    }

    // MARK: - States

    private var stale: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.clockwise")
                .font(.title3)
            Text("افتح التطبيق لتحديث الويدجت")
                .font(.footnote.bold())
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Theme.textSecondary)
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        switch family {
        case .systemMedium: medium(snapshot)
        case .accessoryCircular: circular(snapshot)
        case .accessoryRectangular: rectangular(snapshot)
        case .accessoryInline: inline(snapshot)
        default: small(snapshot)
        }
    }

    // MARK: - Pieces

    private func count(_ snapshot: WidgetSnapshot) -> String {
        SharedFormat.count(snapshot.completed, of: snapshot.total, arabic: snapshot.arabicDigits)
    }

    private func streakText(_ snapshot: WidgetSnapshot) -> String {
        SharedFormat.digits("\(snapshot.streak)", arabic: snapshot.arabicDigits)
    }

    private func ring(_ snapshot: WidgetSnapshot, size: CGFloat, lineWidth: CGFloat) -> some View {
        ProgressRing(fraction: snapshot.fraction, lineWidth: lineWidth) {
            Text(snapshot.total == 0 ? "—" : count(snapshot))
                .font(.system(size: size * 0.27, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.6)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Home screen

    private func small(_ snapshot: WidgetSnapshot) -> some View {
        VStack(spacing: 10) {
            ring(snapshot, size: 80, lineWidth: 8)
            Label(streakText(snapshot), systemImage: "flame.fill")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(Theme.primaryStrong)
        }
        .accessibilityElement(children: .combine)
    }

    private func medium(_ snapshot: WidgetSnapshot) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 8) {
                ring(snapshot, size: 64, lineWidth: 7)
                Label(streakText(snapshot), systemImage: "flame.fill")
                    .font(.footnote.bold().monospacedDigit())
                    .foregroundStyle(Theme.primaryStrong)
                Link(destination: DeepLink.start) {
                    Text("ابدأ يومك")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.primary, in: Capsule())
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                if snapshot.items.isEmpty {
                    Text("ما عندك مهمات رئيسية اليوم")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(snapshot.items.prefix(4)) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.done ? Theme.primary : Theme.textSecondary)
                            Text(item.title)
                                .font(.footnote.weight(.semibold))
                                .strikethrough(item.done)
                                .foregroundStyle(item.done ? Theme.textSecondary : Theme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let time = snapshot.effectiveTime(of: item, at: entry.date), !item.done {
                                Text(SharedFormat.time(time, arabic: snapshot.arabicDigits))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    if snapshot.items.count > 4 {
                        Text(SharedFormat.digits("+\(snapshot.items.count - 4)", arabic: snapshot.arabicDigits))
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if let title = snapshot.nextAlarmTitle, let date = snapshot.nextAlarmDate {
                    Label(
                        "\(title.isEmpty ? String(localized: "تنبيه") : title) · \(SharedFormat.time(date, arabic: snapshot.arabicDigits))",
                        systemImage: "alarm"
                    )
                    .font(.caption2)
                    .foregroundStyle(Theme.primaryStrong)
                    .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Lock screen

    private func circular(_ snapshot: WidgetSnapshot) -> some View {
        Gauge(value: snapshot.fraction) {
            Image(systemName: "checkmark")
        } currentValueLabel: {
            Text(snapshot.total == 0 ? "—" : count(snapshot))
                .font(.caption.bold())
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private func rectangular(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if snapshot.total == 0 {
                Text("ما عندك مهمات رئيسية اليوم").font(.headline)
            } else if let next = snapshot.nextItem(at: entry.date) {
                Text(next.title).font(.headline).lineLimit(1)
                if let time = snapshot.effectiveTime(of: next, at: entry.date) {
                    Text(SharedFormat.time(time, arabic: snapshot.arabicDigits)).font(.caption)
                }
            } else {
                Text("أنجزت كل مهماتك").font(.headline)
            }
            ProgressView(value: snapshot.fraction)
            Text(SharedFormat.percent(snapshot.fraction, arabic: snapshot.arabicDigits) + " · " + count(snapshot))
                .font(.caption2)
        }
    }

    private func inline(_ snapshot: WidgetSnapshot) -> some View {
        Label(
            "\(count(snapshot)) · " + String(localized: "ستريك") + " \(streakText(snapshot))",
            systemImage: "flame.fill"
        )
    }
}

struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("مهمات اليوم")
        .description("تقدمك في المهمات الرئيسية والستريك")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
