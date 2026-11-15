import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island for "today's main tasks".
struct TodayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodayActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Theme.card)
                .activitySystemActionForegroundColor(Theme.textPrimary)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ProgressRing(fraction: state.fraction, lineWidth: 5) {
                        Text(SharedFormat.percent(state.fraction, arabic: state.arabicDigits))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                    }
                    .frame(width: 44, height: 44)
                }
                DynamicIslandExpandedRegion(.center) {
                    NextTaskText(state: state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(SharedFormat.count(state.completed, of: state.total, arabic: state.arabicDigits))
                        .font(.headline.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        SegmentBar(segments: state.segments, styleID: state.styleID, height: 8)
                        OpenAppButton()
                    }
                }
            } compactLeading: {
                ProgressRing(fraction: state.fraction, lineWidth: 3) { EmptyView() }
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                Text(SharedFormat.count(state.completed, of: state.total, arabic: state.arabicDigits))
                    .font(.caption.bold().monospacedDigit())
            } minimal: {
                ProgressRing(fraction: state.fraction, lineWidth: 3) { EmptyView() }
                    .frame(width: 20, height: 20)
            }
            .keylineTint(Theme.primary)
        }
    }
}

private struct NextTaskText: View {
    let state: TodayActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.allDone {
                Text("أنجزت كل مهماتك 🎉")
            } else if let title = state.nextTitle {
                VStack(spacing: 2) {
                    Text("التالية: \(title)")
                    if let time = state.nextTime {
                        Text(SharedFormat.time(time, arabic: state.arabicDigits))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("مهمات اليوم")
            }
        }
        .font(.subheadline.bold())
        .lineLimit(2)
        .multilineTextAlignment(.center)
    }
}

private struct OpenAppButton: View {
    var body: some View {
        Link(destination: DeepLink.today) {
            Text("الانتقال إلى التطبيق")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Theme.primary, in: Capsule())
        }
    }
}

private struct LockScreenView: View {
    let state: TodayActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("مهمات اليوم")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(SharedFormat.percent(state.fraction, arabic: state.arabicDigits)
                     + " · " + SharedFormat.count(state.completed, of: state.total, arabic: state.arabicDigits))
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(Theme.primaryStrong)
            }
            SegmentBar(segments: state.segments, styleID: state.styleID, height: 10)
            NextTaskText(state: state)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            OpenAppButton()
        }
        .padding(16)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar_SA"))
    }
}
