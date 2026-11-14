import SwiftUI

/// The five destinations of the bottom bar.
/// RTL order, right to left: tasks · alarms · (home) · achievements · pages.
enum AppTab: String, CaseIterable, Identifiable {
    case tasks, alarms, home, achievements, pages

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .tasks: return "المهمات"
        case .alarms: return "التنبيهات"
        case .home: return "الرئيسية"
        case .achievements: return "الإنجازات"
        case .pages: return "صفحاتي"
        }
    }

    /// Outline symbol, used when the tab is not selected.
    var symbol: String {
        switch self {
        case .tasks: return "checkmark.circle"
        case .alarms: return "alarm"
        case .home: return "house"
        case .achievements: return "trophy"
        case .pages: return "square.grid.2x2"
        }
    }

    /// Filled symbol, used when the tab is selected.
    var selectedSymbol: String {
        switch self {
        case .tasks: return "checkmark.circle.fill"
        case .alarms: return "alarm.fill"
        case .home: return "house.fill"
        case .achievements: return "trophy.fill"
        case .pages: return "square.grid.2x2.fill"
        }
    }
}
