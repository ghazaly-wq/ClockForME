import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

// Placeholder widget so the extension is valid and installable.
// Real widgets and the Live Activity arrive in phase 5.

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: Date())], policy: .never))
    }
}

struct PlaceholderWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.largeTitle)
            Text("عاداتي")
                .font(.headline)
        }
        .foregroundStyle(.white)
        .containerBackground(Theme.primary, for: .widget)
    }
}

struct PlaceholderWidget: Widget {
    let kind = "PlaceholderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            PlaceholderWidgetView()
        }
        .configurationDisplayName("عاداتي")
        .description("ويدجت تجريبي")
        .supportedFamilies([.systemSmall])
    }
}

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
        PlaceholderWidget()
        HabitAlarmActivity()
    }
}
