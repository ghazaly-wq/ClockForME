import HabitCore
import Observation
import SwiftUI

struct LevelUpInfo: Identifiable, Equatable {
    let id = UUID()
    let level: Int
    let title: LevelTitle
}

/// Where the user is in the app, plus celebrations waiting to be shown.
/// Deep links (`habits://...`) will drive this later.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var showSettings = false
    var showDayComplete = false
    var levelUp: LevelUpInfo?

    func celebrate(_ outcome: CompletionOutcome) {
        if outcome.completedDay {
            showDayComplete = true
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.showDayComplete = false
            }
        }
        if let summary = outcome.newLevel {
            levelUp = LevelUpInfo(level: summary.level, title: summary.title)
        }
    }
}
