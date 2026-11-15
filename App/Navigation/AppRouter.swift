import HabitCore
import Observation
import SwiftUI

struct LevelUpInfo: Identifiable, Equatable {
    let id = UUID()
    let level: Int
    let title: LevelTitle
}

struct UnlockInfo: Identifiable {
    let id = UUID()
    let achievements: [AchievementDef]
}

enum AchievementsSegment: String, CaseIterable {
    case achievements, rewards, shop
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
    var unlock: UnlockInfo?
    /// Kept in the router so it survives a theme change rebuilding the views.
    var achievementsSegment: AchievementsSegment = .achievements
    /// A custom page to open on the "صفحاتي" tab (set by alarms, tasks and links).
    var openPageID: UUID?
    private var pendingLevelUp: LevelUpInfo?

    func celebrate(_ outcome: CompletionOutcome) {
        if outcome.completedDay {
            showDayComplete = true
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.showDayComplete = false
            }
        }
        present(achievements: outcome.newAchievements, newLevel: outcome.newLevel)
    }

    /// Achievements first; a level-up that came with them waits until that sheet is closed.
    func present(achievements: [AchievementDef], newLevel: ProgressSummary?) {
        let info = newLevel.map { LevelUpInfo(level: $0.level, title: $0.title) }
        if !achievements.isEmpty {
            pendingLevelUp = info
            unlock = UnlockInfo(achievements: achievements)
        } else if let info {
            levelUp = info
        }
    }

    func unlockSheetClosed() {
        if let info = pendingLevelUp {
            pendingLevelUp = nil
            levelUp = info
        }
    }
}
