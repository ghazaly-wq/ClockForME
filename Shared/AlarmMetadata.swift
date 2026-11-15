import AlarmKit
import Foundation

/// Extra data carried by every alarm (shared by the app and the widget extension).
struct HabitAlarmMetadata: AlarmMetadata {
    var alarmID: String
}
