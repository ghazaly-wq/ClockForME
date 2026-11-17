import HabitCore
import SwiftUI

/// Shown over the whole app while a task with "block my apps" is past its time and not done.
/// The owner's Shortcuts automation brings them here when they open one of the chosen apps; the only way out is
/// to finish the task (the button marks it done, exactly like on the Tasks page).
struct AppBlockView: View {
    let blocking: [BlockingTask]
    let onDone: (TaskRecord) -> Void

    @Environment(\.digitStyle) private var digits

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.primaryStrong)
                    .accessibilityHidden(true)
                Text("خلّص مهمتك أول")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("التطبيقات اللي اخترتها مقفلة لين تخلص:")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(blocking) { item in
                        row(item)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityAddTraits(.isModal)
    }

    private func row(_ item: BlockingTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.task.title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(digits.format(String(localized: "من الساعة \(AlarmText.time(item.since, digits: digits))")))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Button {
                onDone(item.task)
            } label: {
                Label("خلصتها", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityHint("يعلّم المهمة منجزة ويفتح التطبيقات")
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }
}
