import HabitCore
import SwiftData
import SwiftUI

struct RewardEditorTarget: Identifiable {
    let id = UUID()
    let reward: RewardRecord?

    static var new: RewardEditorTarget { RewardEditorTarget(reward: nil) }
}

/// "جوائزي": rewards the owner defines for themselves, unlocked by progress.
struct RewardsSection: View {
    let snapshot: ProgressSnapshot
    let rewards: [RewardRecord]
    @Binding var editor: RewardEditorTarget?
    @Environment(\.modelContext) private var context
    @Environment(\.digitStyle) private var digits
    @State private var toDelete: RewardRecord?
    @State private var toClaim: RewardRecord?

    var body: some View {
        VStack(spacing: 12) {
            if rewards.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "gift")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.primaryStrong)
                        .accessibilityHidden(true)
                    Text("ما أضفت أي جائزة بعد")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("حدد جائزة تكافئ بها نفسك، مثل وجبة تحبها، وشرط الوصول لها.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("إضافة جائزة") { editor = .new }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(rewards) { reward in
                    row(reward)
                }
            }
        }
        .confirmationDialog(
            "حذف الجائزة؟",
            isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("حذف", role: .destructive) {
                if let reward = toDelete {
                    context.delete(reward)
                    try? context.save()
                }
                toDelete = nil
            }
            Button("إلغاء", role: .cancel) { toDelete = nil }
        }
        .confirmationDialog(
            claimTitle,
            isPresented: Binding(get: { toClaim != nil }, set: { if !$0 { toClaim = nil } }),
            titleVisibility: .visible
        ) {
            Button("استلمتها") {
                if let reward = toClaim {
                    AchievementActions.claim(reward, snapshot: snapshot, context: context, now: Date())
                }
                toClaim = nil
            }
            Button("إلغاء", role: .cancel) { toClaim = nil }
        }
    }

    private var claimTitle: String {
        guard let reward = toClaim else { return "" }
        let cost = reward.condition.cost
        return cost > 0
            ? digits.format(String(localized: "سيتم خصم \(cost) نقطة"))
            : String(localized: "تأكيد استلام الجائزة")
    }

    private func row(_ reward: RewardRecord) -> some View {
        let state = RewardEvaluator.state(of: reward.condition, claimed: reward.isClaimed, context: snapshot.rewardContext)
        let progress = RewardEvaluator.progress(of: reward.condition, context: snapshot.rewardContext)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reward.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    if !reward.note.isEmpty {
                        Text(reward.note)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Menu {
                    if !reward.isClaimed {
                        Button("تعديل", systemImage: "pencil") { editor = RewardEditorTarget(reward: reward) }
                    }
                    Button("حذف", systemImage: "trash", role: .destructive) { toDelete = reward }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("خيارات الجائزة"))
            }

            Text(RewardText.condition(reward, digits: digits))
                .font(.subheadline.bold())
                .foregroundStyle(Theme.primaryStrong)

            switch state {
            case .locked:
                LevelProgressBar(fraction: progress.fraction)
                Label(
                    digits.format(String(localized: "مقفلة · \(progress.current) / \(progress.target)")),
                    systemImage: "lock.fill"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
            case .unlocked:
                Button {
                    toClaim = reward
                } label: {
                    Label("جاهزة، اضغط للاستلام", systemImage: "gift.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.gold)
                .foregroundStyle(Color.black.opacity(0.85))
            case .claimed:
                Label("تم الاستلام", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primaryStrong)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

enum RewardText {
    static func condition(_ reward: RewardRecord, digits: DigitStyle) -> String {
        let text: String
        switch reward.kind {
        case .level: text = String(localized: "عند الوصول للمستوى \(reward.target)")
        case .streak: text = String(localized: "عند سلسلة \(reward.target) أيام")
        case .tasks: text = String(localized: "عند إنجاز \(reward.target) مهمة")
        case .days: text = String(localized: "عند إكمال \(reward.target) يوماً")
        case .achievement:
            let name = AchievementCatalog.definition(id: reward.achievementID)?.name ?? "—"
            text = String(localized: "عند فتح إنجاز: \(name)")
        case .points: text = String(localized: "مقابل \(reward.target) نقطة")
        }
        return digits.format(text)
    }
}

struct RewardEditorView: View {
    let target: RewardEditorTarget
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.digitStyle) private var digits
    @State private var title = ""
    @State private var note = ""
    @State private var kind: RewardKind = .level
    @State private var value = RewardKind.level.defaultTarget
    @State private var achievementID = AchievementCatalog.all.first?.id ?? ""
    @State private var loaded = false

    private var isClaimed: Bool { target.reward?.isClaimed ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section("الجائزة") {
                    TextField("اسم الجائزة", text: $title)
                    TextField("ملاحظة (اختياري)", text: $note)
                }
                Section("شرط الحصول عليها") {
                    Picker("النوع", selection: $kind) {
                        ForEach(RewardKind.allCases) { Text($0.label).tag($0) }
                    }
                    .disabled(isClaimed)
                    if kind == .achievement {
                        Picker("الإنجاز", selection: $achievementID) {
                            ForEach(AchievementCatalog.all.filter { !$0.hidden }) { Text($0.name).tag($0.id) }
                        }
                    } else {
                        Stepper(value: $value, in: 1...100_000, step: kind.step) {
                            Text(digits.format("\(value)"))
                                .monospacedDigit()
                        }
                    }
                    if kind == .points {
                        Text("تُخصم هذه النقاط من رصيدك عند استلام الجائزة.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .navigationTitle(target.reward == nil ? "جائزة جديدة" : "تعديل الجائزة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: kind) { _, newKind in
                if loaded { value = newKind.defaultTarget }
            }
            .onAppear {
                guard !loaded else { return }
                if let reward = target.reward {
                    title = reward.title
                    note = reward.note
                    kind = reward.kind
                    value = reward.target
                    if !reward.achievementID.isEmpty { achievementID = reward.achievementID }
                }
                loaded = true
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let reward = target.reward {
            reward.title = trimmed
            reward.note = note
            if !reward.isClaimed {
                reward.kind = kind
                reward.target = kind == .achievement ? 1 : value
                reward.achievementID = kind == .achievement ? achievementID : ""
            }
        } else {
            context.insert(RewardRecord(
                title: trimmed, note: note, kind: kind,
                target: kind == .achievement ? 1 : value,
                achievementID: kind == .achievement ? achievementID : ""
            ))
        }
        try? context.save()
        dismiss()
    }
}
