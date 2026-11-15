import HabitCore
import SwiftUI

/// One task in the list: a check button, the title and its schedule summary.
/// State is never shown by color alone: done = filled check + strikethrough.
struct TaskRow: View {
    let title: String
    let subtitle: String
    let isDone: Bool
    var showsCheck = true
    /// Set for tasks that came from an alarm: its time, shown with an alarm icon.
    var alarmTime: String? = nil
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if showsCheck {
                Button(action: onToggle) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isDone ? Theme.primaryStrong : Theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(isDone ? "إلغاء الإكمال" : "إكمال المهمة"))
            }

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? Theme.textSecondary : Theme.textPrimary)
                    HStack(spacing: 4) {
                        if let alarmTime {
                            Image(systemName: "alarm.fill")
                                .font(.caption2)
                                .accessibilityHidden(true)
                            Text(alarmTime + " · ")
                        }
                        Text(subtitle)
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("اضغط للتعديل"))
        }
        .padding(.vertical, 2)
    }
}
