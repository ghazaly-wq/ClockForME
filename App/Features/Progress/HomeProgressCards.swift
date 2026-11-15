import HabitCore
import SwiftUI

/// Home: the closest achievement and the closest reward, each with its progress.
struct HomeGoalsCard: View {
    let snapshot: ProgressSnapshot
    let rewards: [RewardRecord]
    @Environment(\.digitStyle) private var digits

    var body: some View {
        let stats = snapshot.achievementStats
        let nextAchievement = AchievementCatalog.all
            .filter { !$0.hidden && !snapshot.unlockedIDs.contains($0.id) }
            .map { ($0, AchievementEvaluator.progress(of: $0, stats: stats)) }
            .max(by: { $0.1.fraction < $1.1.fraction })
        let nextReward = rewards
            .filter { !$0.isClaimed }
            .map { ($0, RewardEvaluator.progress(of: $0.condition, context: snapshot.rewardContext)) }
            .max(by: { $0.1.fraction < $1.1.fraction })

        if nextAchievement != nil || nextReward != nil {
            VStack(alignment: .leading, spacing: 14) {
                if let (def, progress) = nextAchievement {
                    goal(
                        symbol: def.symbol, title: String(localized: "أقرب إنجاز"), name: def.name,
                        progress: progress, ready: false
                    )
                }
                if let (reward, progress) = nextReward {
                    goal(
                        symbol: "gift.fill", title: String(localized: "أقرب جائزة"), name: reward.title,
                        progress: progress, ready: progress.isMet
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func goal(symbol: String, title: String, name: String, progress: AchievementProgress, ready: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.gold)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textPrimary)
                LevelProgressBar(fraction: progress.fraction)
                Text(ready
                     ? String(localized: "جاهزة للاستلام")
                     : digits.format("\(progress.current) / \(progress.target)"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Home: the last few unlocked achievements.
struct RecentAchievementsCard: View {
    let unlocks: [AchievementUnlockRecord]

    var body: some View {
        let recent = unlocks
            .sorted { $0.unlockedAt > $1.unlockedAt }
            .prefix(5)
            .compactMap { AchievementCatalog.definition(id: $0.achievementID) }

        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("آخر إنجازاتك")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(recent), id: \.id) { def in
                            VStack(spacing: 6) {
                                Image(systemName: def.symbol)
                                    .font(.title3)
                                    .foregroundStyle(Color.black.opacity(0.85))
                                    .frame(width: 48, height: 48)
                                    .background(Theme.gold, in: Circle())
                                Text(def.name)
                                    .font(.caption2.bold())
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 72)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
