import SwiftUI

/// Selectable pill. Selected = filled; unselected = outlined (never color alone).
struct ChoiceChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.bold())
                .foregroundStyle(isSelected ? Color.white : Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if isSelected {
                        Capsule().fill(Theme.primary)
                    } else {
                        Capsule().stroke(Theme.textSecondary.opacity(0.5), lineWidth: 1.5)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
