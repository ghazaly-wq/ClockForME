import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// The look of a snoozed alarm (counting down) on the Lock Screen and Dynamic Island.
/// AlarmKit needs this in the extension, otherwise snoozed alarms can be dismissed.
struct HabitAlarmActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<HabitAlarmMetadata>.self) { context in
            HStack(spacing: 10) {
                Image(systemName: "alarm.fill")
                Text(context.attributes.presentation.alert.title)
                    .font(.headline)
                Spacer(minLength: 0)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.presentation.alert.title)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: "alarm.fill")
            }
        }
    }
}

@main
struct HabitsWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TodayLiveActivity()
        HabitAlarmActivity()
    }
}
