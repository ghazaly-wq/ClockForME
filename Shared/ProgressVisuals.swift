import SwiftUI

/// One segment per main task. The shop style changes the shape; done segments are always
/// filled and open ones outlined or faded, so state never depends on color alone.
struct SegmentBar: View {
    let segments: [Bool]
    var styleID: String = "live.default"
    var height: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            if segments.isEmpty {
                Capsule().fill(Theme.primary.opacity(0.2)).frame(height: height)
            } else {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, done in
                    segment(done)
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func segment(_ done: Bool) -> some View {
        switch styleID {
        case "live.blocks":
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(done ? Theme.primary : Theme.primary.opacity(0.2))
                .frame(height: height + 4)
        case "live.dots":
            Circle()
                .fill(done ? Theme.primary : Theme.primary.opacity(0.2))
                .overlay {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: height * 0.7, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: height + 8, height: height + 8)
                .frame(maxWidth: .infinity)
        case "live.thin":
            Capsule()
                .fill(done ? Theme.primary : Theme.primary.opacity(0.25))
                .frame(height: max(3, height / 2.5))
        case "live.stars":
            Image(systemName: done ? "star.fill" : "star")
                .font(.system(size: height + 6, weight: .bold))
                .foregroundStyle(done ? Theme.primary : Theme.primary.opacity(0.45))
                .frame(maxWidth: .infinity)
        default:
            Capsule()
                .fill(done ? Theme.primary : Theme.primary.opacity(0.2))
                .frame(height: height)
        }
    }
}

/// Circular progress with optional centered content.
struct ProgressRing<Center: View>: View {
    let fraction: Double
    let lineWidth: CGFloat
    let center: Center

    init(fraction: Double, lineWidth: CGFloat = 6, @ViewBuilder center: () -> Center) {
        self.fraction = fraction
        self.lineWidth = lineWidth
        self.center = center()
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.primary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(Theme.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center
        }
    }
}
