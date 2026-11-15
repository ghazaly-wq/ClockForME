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
    private(set) var currentTab: AppTab = .home
    /// Side the next tab slides in from (leading = right in this RTL app).
    private(set) var tabEdge: Edge = .trailing

    /// The tab on screen. Setting it from anywhere (deep links, buttons) slides to it.
    var selectedTab: AppTab {
        get { currentTab }
        set { select(newValue) }
    }
    var showSettings = false
    var showDayComplete = false
    var levelUp: LevelUpInfo?
    var unlock: UnlockInfo?
    /// Kept in the router so it survives a theme change rebuilding the views.
    var achievementsSegment: AchievementsSegment = .achievements
    /// A custom page to open on the "صفحاتي" tab (set by alarms, tasks and links).
    var openPageID: UUID?
    private var pendingLevelUp: LevelUpInfo?

    /// Tabs further left in the bar slide in from the left, tabs further right from the right.
    /// The direction is set first and the change follows on the next turn, so the screen
    /// that leaves already knows which way to go.
    func select(_ tab: AppTab) {
        guard tab != currentTab else { return }
        tabEdge = tab.order > currentTab.order ? .trailing : .leading
        Task { @MainActor [weak self] in
            self?.currentTab = tab
        }
    }

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
