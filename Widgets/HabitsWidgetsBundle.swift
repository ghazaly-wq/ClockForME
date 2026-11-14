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

@main
struct HabitsWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderWidget()
    }
}
