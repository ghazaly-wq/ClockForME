import SwiftUI

/// One rounded segment per main task; filled segments are done.
/// Completing a task fills its segment with a short spring.
struct SegmentedProgressBar: View {
    let segments: [Bool]

    var body: some View {
        HStack(spacing: 4) {
            if segments.isEmpty {
                Capsule().fill(Theme.primary.opacity(0.2)).frame(height: 10)
            } else {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, done in
                    Capsule()
                        .fill(done ? Theme.primary : Theme.primary.opacity(0.2))
                        .frame(height: 10)
                }
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.3), value: segments)
        .accessibilityHidden(true)
    }
}

/// Continuous bar with rounded ends, used for XP.
struct LevelProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.primary.opacity(0.2))
                Capsule()
                    .fill(Theme.primary)
                    .frame(width: max(10, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 10)
        .animation(.spring(duration: 0.4, bounce: 0.25), value: fraction)
        .accessibilityHidden(true)
    }
}
