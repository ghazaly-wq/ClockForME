import HabitCore
import SwiftUI

extension LevelTitle {
    var arabicName: String {
        switch self {
        case .beginner: return String(localized: "مبتدئ")
        case .persistent: return String(localized: "مثابر")
        case .disciplined: return String(localized: "منضبط")
        case .master: return String(localized: "متقن")
        case .roleModel: return String(localized: "قدوة")
        case .legend: return String(localized: "أسطورة")
        }
    }
}

/// Level number, Arabic title, XP bar and points balance.
struct LevelCard: View {
    let summary: ProgressSummary
    @Environment(\.digitStyle) private var digits

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.primary)
                Text(digits.format(summary.level))
                    .font(.title2.bold().monospacedDigit())
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(summary.title.arabicName)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(digits.format(String(localized: "\(summary.points) نقطة")))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                LevelProgressBar(fraction: summary.levelFraction)
                Text(digits.format(String(localized: "\(summary.xpIntoLevel) من \(summary.xpForNextLevel) خبرة")))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(digits.format(String(localized: "المستوى \(summary.level)، \(summary.title.arabicName)"))))
    }
}

/// Today's main-task progress and the streak.
struct TodayCard: View {
    let progress: DayProgress
    let segments: [Bool]
    let streak: Int
    /// "التالية: …" — the next main task by time, or the all-done message.
    var nextLine: String? = nil
    @Environment(\.digitStyle) private var digits

    private var progressText: String {
        if progress.total == 0 { return String(localized: "ما عندك مهمات رئيسية اليوم") }
        let percent = Int((progress.fraction * 100).rounded())
        return digits.format(String(localized: "\(progress.completed) من \(progress.total) مهمات رئيسية · \(percent)%"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("مهمات اليوم")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(progressText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text(digits.format(streak))
                        .font(.title3.bold().monospacedDigit())
                        .fontDesign(.rounded)
                }
                .foregroundStyle(Theme.primaryStrong)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(digits.format(String(localized: "الستريك \(streak) أيام متتالية"))))
            }
            SegmentedProgressBar(segments: segments)
            if let nextLine {
                Text(nextLine)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primaryStrong)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
