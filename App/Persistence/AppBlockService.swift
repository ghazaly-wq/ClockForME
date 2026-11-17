import Foundation
import HabitCore
import SwiftData

/// A task that is blocking the owner's apps right now, and since when.
struct BlockingTask: Identifiable {
    let task: TaskRecord
    /// The first time the task was due today (when the block started).
    let since: Date
    var id: UUID { task.id }
}

/// Glue between the stored tasks and the pure `AppBlockRule`.
///
/// iOS doesn't let an app close other apps (that needs the paid Screen Time entitlement). Instead the owner makes a
/// Shortcuts automation that runs `BlockStatusIntent` ("is anything blocking?") whenever one of the chosen apps
/// opens and opens this app only if the answer is yes; the app then shows a full-screen "finish your task first".
enum AppBlockService {
    /// Tasks that block right now, earliest first. A task blocks only when its switch is on, it has an enabled
    /// alarm, it is scheduled today, its time for today has come and it isn't done yet.
    static func blockingTasks(
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        alarms: [AlarmRecord],
        now: Date,
        dayStartHour: Int,
        provider: PrayerTimeProviding?,
        calendar: Calendar = Calendar.app
    ) -> [BlockingTask] {
        let today = DayKey(date: now, calendar: calendar, dayStartHour: dayStartHour)
        let doneToday = Set(completions.filter { $0.day == today }.map(\.taskID))
        let enabledAlarms = Set(alarms.filter(\.isEnabled).map(\.id))

        var due: [UUID: [Date]] = [:]
        var candidates: [BlockCandidate] = []
        var byID: [UUID: TaskRecord] = [:]
        for task in tasks where task.blocksApps {
            guard let alarmID = task.alarmID, enabledAlarms.contains(alarmID),
                  task.spec.isScheduled(on: today, calendar: calendar) else { continue }
            let times = task.dueDates(on: today, provider: provider, calendar: calendar)
            due[task.id] = times
            byID[task.id] = task
            candidates.append(BlockCandidate(id: task.id, blocksApps: true, isDone: doneToday.contains(task.id), dueTimes: times))
        }

        return AppBlockRule.blockingIDs(candidates, now: now)
            .compactMap { id -> BlockingTask? in
                guard let task = byID[id], let since = due[id]?.min() else { return nil }
                return BlockingTask(task: task, since: since)
            }
            .sorted { $0.since < $1.since }
    }
}

/// "Is anything blocking right now?" for places that have no views (the Shortcuts action).
@MainActor
enum BlockStatus {
    /// Same answer the full-screen block gives: the master switch is on and at least one task is blocking.
    static func isBlocking(now: Date = Date()) -> Bool {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: SettingsKey.appBlockEnabled) as? Bool ?? true
        guard enabled else { return false }

        let context = AppEnvironment.shared.container.mainContext
        let tasks = (try? context.fetch(FetchDescriptor<TaskRecord>())) ?? []
        let completions = (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? []
        let alarms = (try? context.fetch(FetchDescriptor<AlarmRecord>())) ?? []
        let provider: AdhanPrayerTimes? = defaults.bool(forKey: SettingsKey.hasPrayerLocation)
            ? AdhanPrayerTimes(
                latitude: defaults.double(forKey: SettingsKey.prayerLatitude),
                longitude: defaults.double(forKey: SettingsKey.prayerLongitude)
            )
            : nil
        return !AppBlockService.blockingTasks(
            tasks: tasks, completions: completions, alarms: alarms, now: now,
            dayStartHour: defaults.integer(forKey: SettingsKey.dayStartHour), provider: provider
        ).isEmpty
    }
}
