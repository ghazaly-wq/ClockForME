import SwiftData
import SwiftUI

struct AchievementsView: View {
    @AppStorage(SettingsKey.dayStartHour) private var dayStartHour = 0
    @Query private var tasks: [TaskRecord]
    @Query private var completions: [CompletionRecord]

    var body: some View {
        let snapshot = ProgressSnapshot.make(
            tasks: tasks, completions: completions, now: Date(), dayStartHour: dayStartHour
        )
        CurvedPage(title: "الإنجازات") {
            VStack(spacing: 16) {
                LevelCard(summary: snapshot.summary)
                PlaceholderContent(symbol: "trophy", message: "هنا تظهر إنجازاتك وجوائزك")
            }
        }
    }
}
