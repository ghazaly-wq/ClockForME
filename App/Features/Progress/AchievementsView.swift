import HabitCore
import SwiftData
import SwiftUI

struct AchievementsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.digitStyle) private var digits
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @Query private var tasks: [TaskRecord]
    @Query private var completions: [CompletionRecord]
    @Query private var unlocks: [AchievementUnlockRecord]
    @Query private var purchases: [PurchaseRecord]
    @Query(sort: \RewardRecord.createdAt) private var rewards: [RewardRecord]
    @State private var showStats = false
    @State private var rewardEditor: RewardEditorTarget?

    var body: some View {
        @Bindable var router = router
        let snapshot = ProgressSnapshot.make(
            tasks: tasks, completions: completions, now: Date(), dayStartHour: dayStartHour,
            extras: ProgressExtras(unlocks: unlocks, purchases: purchases, rewards: rewards)
        )

        CurvedPage(title: "الإنجازات", onAdd: router.achievementsSegment == .rewards ? { rewardEditor = .new } : nil) {
            VStack(spacing: 16) {
                LevelCard(summary: snapshot.summary)

                Button {
                    showStats = true
                } label: {
                    HStack {
                        Label("الإحصائيات", systemImage: "chart.bar.xaxis")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityHidden(true)
                    }
                    .padding(16)
                    .frame(minHeight: 44)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)

                Picker("القسم", selection: $router.achievementsSegment) {
                    Text("الإنجازات").tag(AchievementsSegment.achievements)
                    Text("جوائزي").tag(AchievementsSegment.rewards)
                    Text("المتجر").tag(AchievementsSegment.shop)
                }
                .pickerStyle(.segmented)

                switch router.achievementsSegment {
                case .achievements:
                    AchievementGrid(snapshot: snapshot, unlocks: unlocks)
                case .rewards:
                    RewardsSection(snapshot: snapshot, rewards: rewards, editor: $rewardEditor)
                case .shop:
                    ShopSection(snapshot: snapshot, purchases: purchases)
                }
            }
        }
        .sheet(isPresented: $showStats) {
            StatisticsView(snapshot: snapshot, completions: completions)
                .appRoot()
        }
        .sheet(item: $rewardEditor) { target in
            RewardEditorView(target: target)
                .appRoot()
        }
    }
}

// MARK: - Achievements

private struct AchievementGrid: View {
    let snapshot: ProgressSnapshot
    let unlocks: [AchievementUnlockRecord]
    @Environment(\.digitStyle) private var digits

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let stats = snapshot.achievementStats
        let unlockedCount = AchievementCatalog.all.filter { snapshot.unlockedIDs.contains($0.id) }.count

        VStack(alignment: .leading, spacing: 12) {
            Text(digits.format(String(localized: "\(unlockedCount) من \(AchievementCatalog.all.count) إنجاز")))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AchievementCatalog.all) { def in
                    AchievementBadge(
                        def: def,
                        progress: AchievementEvaluator.progress(of: def, stats: stats),
                        unlocked: snapshot.unlockedIDs.contains(def.id)
                    )
                }
            }
        }
    }
}

private struct AchievementBadge: View {
    let def: AchievementDef
    let progress: AchievementProgress
    let unlocked: Bool
    @Environment(\.digitStyle) private var digits

    private var isSecret: Bool { def.hidden && !unlocked }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(unlocked ? Theme.gold : Theme.textSecondary.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: isSecret ? "questionmark" : def.symbol)
                            .font(.title2)
                            .foregroundStyle(unlocked ? Color.black.opacity(0.85) : Theme.textSecondary)
                    }
                Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.fill")
                    .font(.caption.bold())
                    .foregroundStyle(unlocked ? Theme.primaryStrong : Theme.textSecondary)
                    .padding(3)
                    .background(Theme.card, in: Circle())
            }
            .accessibilityHidden(true)

            Text(isSecret ? "؟؟؟" : def.name)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(isSecret ? String(localized: "إنجاز سري") : def.detail)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            if unlocked {
                Text(digits.format(String(localized: "+\(def.xp) خبرة · +\(def.points) نقطة")))
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(Theme.primaryStrong)
            } else if !isSecret {
                VStack(spacing: 4) {
                    LevelProgressBar(fraction: progress.fraction)
                    Text(digits.format("\(progress.current) / \(progress.target)"))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .top)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var accessibilityText: String {
        if isSecret { return String(localized: "إنجاز سري، لم يُفتح بعد") }
        if unlocked { return "\(def.name)، \(def.detail)، " + String(localized: "مفتوح") }
        return digits.format("\(def.name)، \(def.detail)، " + String(localized: "التقدم \(progress.current) من \(progress.target)"))
    }
}
