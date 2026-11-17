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

/// A challenge that has to be done now; shown full screen until it is completed.
struct ActiveChallenge: Identifiable, Equatable {
    /// The ring's key (`alarm.<id>.<yyyyMMddHHmm>`).
    let id: String
    let alarmID: UUID
    let title: String
    let challenge: AlarmChallenge
    let destination: StopDestination?
    /// After this moment the chain has stopped ringing and the screen can be closed without finishing.
    let expiresAt: Date
    let showTasks: Bool
    let pageID: UUID?
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
    /// Set when an alarm's stop button opened the app (`OpenHabitsIntent`); the app then checks whether that ring
    /// has a challenge or a destination waiting.
    var alarmStoppedAt: Date?
    /// The challenge on screen right now, if any.
    var activeChallenge: ActiveChallenge?
    private var pendingLevelUp: LevelUpInfo?

    func celebrate(_ outcome: CompletionOutcome) {
        // One sound per completion, the biggest moment wins: day complete > achievement / level up > task done.
        if outcome.completedDay {
            SoundEffects.shared.play(.dayComplete)
        } else if !outcome.newAchievements.isEmpty || outcome.newLevel != nil {
            SoundEffects.shared.play(.achievement)
        } else if outcome.didComplete {
            SoundEffects.shared.play(.taskDone)
        }
        if outcome.completedDay {
            showDayComplete = true
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.showDayComplete = false
            }
        }
        show(achievements: outcome.newAchievements, newLevel: outcome.newLevel)
    }

    /// Achievements first; a level-up that came with them waits until that sheet is closed.
    func present(achievements: [AchievementDef], newLevel: ProgressSummary?) {
        if !achievements.isEmpty || newLevel != nil { SoundEffects.shared.play(.achievement) }
        show(achievements: achievements, newLevel: newLevel)
    }

    private func show(achievements: [AchievementDef], newLevel: ProgressSummary?) {
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
