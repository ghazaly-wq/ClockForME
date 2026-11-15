import Foundation
import HabitCore
import SwiftData
import UIKit

/// Stores photos picked for image blocks inside the app's Documents folder (private to the app, kept in backups).
enum PageImageStore {
    static var folder: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("PageImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Saves JPEG data and returns the file name to keep in the block.
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String) -> UIImage? {
        guard !name.isEmpty else { return nil }
        return UIImage(contentsOfFile: folder.appendingPathComponent(name).path)
    }

    static func remove(_ name: String) {
        guard !name.isEmpty else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
    }
}

@MainActor
enum PageActions {
    // MARK: - Creating

    static func create(_ definition: PageDefinition, in context: ModelContext, existing: [PageRecord], today: DayKey) -> PageRecord {
        var page = definition
        page.anchorDay = today
        let order = (existing.map(\.sortOrder).max() ?? -1) + 1
        let record = PageRecord(definition: page, sortOrder: order)
        context.insert(record)
        try? context.save()
        NotificationCenter.default.post(name: .achievementsNeedSync, object: nil)
        return record
    }

    /// A page made from a template (built-in or saved): fresh ids, no schedule, not pinned.
    static func instantiate(_ template: PageDefinition) -> PageDefinition {
        var page = template
        page.id = UUID()
        page.schedule = nil
        page.isMainTask = false
        page.pinnedToHome = false
        page.tabs = template.tabs.map { tab in
            PageTab(name: tab.name, blocks: tab.blocks.clonedWithNewIDs())
        }
        return page
    }

    /// Copies a page into the "قوالبي" list (structure only).
    static func saveAsTemplate(_ page: PageDefinition, in context: ModelContext) {
        var copy = instantiate(page)
        copy.name = page.name
        let record = PageRecord(definition: copy, isTemplate: true)
        context.insert(record)
        try? context.save()
    }

    // MARK: - Saving + linking to alarms and tasks

    /// Writes the page and keeps its alarm and main task in step with its schedule.
    /// Past days are never rewritten: if the schedule changes and the task has history,
    /// the old task stops today and a new one starts.
    static func save(
        _ page: PageDefinition,
        record: PageRecord,
        alarms: [AlarmRecord],
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        context: ModelContext,
        today: DayKey
    ) {
        record.definition = page
        syncLinks(page, alarms: alarms, tasks: tasks, completions: completions, context: context, today: today)
        try? context.save()
        Task { @MainActor in await AlarmActions.requestAndReplan() }
    }

    static func syncLinks(
        _ page: PageDefinition,
        alarms: [AlarmRecord],
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        context: ModelContext,
        today: DayKey
    ) {
        // The alarm: same schedule as the page; the owner may switch it off in the Alarms list.
        let linkedAlarm = alarms.first { $0.linkedPageID == page.id }
        if let rule = PageLogic.alarmRule(for: page, existingID: linkedAlarm?.id ?? UUID()) {
            if let linkedAlarm {
                var updated = rule
                updated.isEnabled = linkedAlarm.isEnabled
                updated.note = linkedAlarm.note
                linkedAlarm.apply(updated)
            } else {
                context.insert(AlarmRecord(rule: rule))
            }
        } else if let linkedAlarm {
            AlarmScheduler.cancelAll(forRule: linkedAlarm.id)
            context.delete(linkedAlarm)
        }

        // The main task.
        let active = tasks.first { $0.pageID == page.id && $0.endDay == nil }
        guard let schedule = page.schedule, page.isMainTask else {
            if let active { _ = TaskActions.delete(active, completions: completions, context: context, today: today) }
            return
        }
        var start = today
        if case .once(let day) = schedule.repetition { start = day }

        guard let active else {
            let order = (tasks.map(\.sortOrder).max() ?? -1) + 1
            insertTask(page, schedule: schedule, start: start, order: order, notes: "", context: context)
            return
        }
        let hasHistory = completions.contains { $0.taskID == active.id }
        let scheduleChanged = active.kind != .main || active.repetition != schedule.repetition
        if hasHistory && scheduleChanged {
            active.endDay = today
            active.pageID = nil
            insertTask(page, schedule: schedule, start: start, order: active.sortOrder, notes: active.notes, context: context)
        } else {
            active.title = page.name
            active.time = schedule.time
            active.extraPrayers = schedule.extraPrayers
            active.routineEnd = schedule.endDay
            active.kind = .main
            active.repetition = schedule.repetition
            if case .once(let day) = schedule.repetition {
                active.startDay = day
            } else {
                active.startDay = min(active.startDay, today)
            }
        }
    }

    private static func insertTask(_ page: PageDefinition, schedule: PageSchedule, start: DayKey, order: Int, notes: String, context: ModelContext) {
        let task = TaskRecord(title: page.name, kind: .main, repetition: schedule.repetition, startDay: start, notes: notes, sortOrder: order)
        task.pageID = page.id
        task.time = schedule.time
        task.extraPrayers = schedule.extraPrayers
        task.routineEnd = schedule.endDay
        context.insert(task)
    }

    // MARK: - Deleting

    /// `everything`: also removes the page's alarm and stops its task. Otherwise they stay as ordinary
    /// alarm/task. The page's history (sessions) and photos are removed either way.
    static func delete(
        _ record: PageRecord,
        everything: Bool,
        alarms: [AlarmRecord],
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        sessions: [PageSessionRecord],
        context: ModelContext,
        today: DayKey
    ) {
        let id = record.id
        for block in record.definition.allBlocks where block.kind == .image {
            PageImageStore.remove(block.imageFile)
        }
        for session in sessions where session.pageID == id { context.delete(session) }
        for alarm in alarms where alarm.linkedPageID == id {
            if everything {
                AlarmScheduler.cancelAll(forRule: alarm.id)
                context.delete(alarm)
            } else {
                alarm.linkedPageID = nil
            }
        }
        for task in tasks where task.pageID == id {
            if everything && task.endDay == nil {
                _ = TaskActions.delete(task, completions: completions, context: context, today: today)
            }
            task.pageID = nil
        }
        context.delete(record)
        try? context.save()
        Task { @MainActor in await AlarmActions.replan(container: AppEnvironment.shared.container) }
    }

    // MARK: - Sessions

    static func finishedSessions(pageID: UUID, records: [PageSessionRecord]) -> [PageSession] {
        records.filter { $0.pageID == pageID && $0.isFinished }.compactMap(\.session)
    }

    /// Today's latest session for a tab (so reopening the page continues where he left off).
    static func latestSession(pageID: UUID, tabID: UUID, day: DayKey, records: [PageSessionRecord]) -> PageSession? {
        records
            .filter { $0.pageID == pageID && $0.tabID == tabID && $0.dayISO == day.isoString }
            .sorted { $0.startedAt < $1.startedAt }
            .last?.session
    }

    /// Saves a session, creating its record the first time. Untouched, unfinished sessions are not kept.
    static func upsert(_ session: PageSession, records: [PageSessionRecord], context: ModelContext) {
        if let existing = records.first(where: { $0.id == session.id }) {
            if session.hasNoData && !session.isFinished {
                context.delete(existing)
            } else {
                existing.apply(session)
            }
        } else if !session.hasNoData || session.isFinished {
            context.insert(PageSessionRecord(session: session))
        }
        try? context.save()
        if session.isFinished { NotificationCenter.default.post(name: .achievementsNeedSync, object: nil) }
    }

    /// Completes the page's linked main task for today, if it is scheduled today and not done yet.
    static func completeLinkedTask(
        pageID: UUID,
        tasks: [TaskRecord],
        completions: [CompletionRecord],
        context: ModelContext,
        now: Date,
        dayStartHour: Int
    ) -> CompletionOutcome? {
        let calendar = Calendar.app
        let today = DayKey(date: now, calendar: calendar, dayStartHour: dayStartHour)
        guard let task = tasks.first(where: {
            $0.pageID == pageID && $0.kind == .main && $0.spec.isScheduled(on: today, calendar: calendar)
        }) else { return nil }
        if completions.contains(where: { $0.taskID == task.id && $0.day == today }) { return nil }
        return TaskActions.toggle(task, on: today, tasks: tasks, completions: completions, context: context, now: now, dayStartHour: dayStartHour)
    }

    /// Quick-creates a secondary task (button action "إضافة مهمة فرعية").
    static func addSecondaryTask(title: String, tasks: [TaskRecord], context: ModelContext, today: DayKey) {
        let order = (tasks.map(\.sortOrder).max() ?? -1) + 1
        context.insert(TaskRecord(title: title, kind: .secondary, repetition: nil, startDay: today, sortOrder: order))
        try? context.save()
    }
}
