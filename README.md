# Habits — عاداتي (ClockForME)

An Arabic-first, right-to-left iPhone app for building habits. It combines tasks, real ringing alarms
tied to clock times or Islamic prayer times, challenge alarms, gamification (streaks, XP, levels,
achievements, a cosmetic shop, custom rewards), a custom page builder, a Lock Screen Live Activity and
widgets. Everything runs on-device with no server.

> **This README is the guide for anyone who wants to understand, change or extend the project.**
> **Part 1 is in English. Part 2 (below it) is the same guide in Arabic.**

---

# PART 1 — ENGLISH

## Contents
1. [Features](#1-features)
2. [Tech stack](#2-tech-stack)
3. [Getting started](#3-getting-started)
4. [Repository layout](#4-repository-layout)
5. [Architecture](#5-architecture)
6. [Domain rules](#6-domain-rules)
7. [Design system](#7-design-system)
8. [CI and distribution](#8-ci-and-distribution)
9. [How to extend the project (recipes)](#9-how-to-extend-the-project-recipes)
10. [Conventions and rules](#10-conventions-and-rules)
11. [Where to change what](#11-where-to-change-what)

## 1. Features

| Area | What it does |
|---|---|
| **Tasks** | Main and secondary tasks. Repetition: once, weekly (any weekdays), monthly (any days). Secondary tasks can be "anytime, until done". Drag to reorder, filters (all / main / secondary), undo delete. |
| **Alarms** | Real alarms through **AlarmKit** that ring even in Silent mode, or notification-only alarms. Time can be a clock time or **relative to prayers** ("30 min before Fajr"), on one or several prayers. Routines can have an end date. An alarm can be a **main-task alarm** that creates and keeps a linked main task. If that task is already done for the day, the alarm does not ring that day (undo the task and it rings again). |
| **Challenge alarms** | The alarm keeps ringing until a challenge is solved: math, walking steps, typing a phrase, shaking the phone, or memorizing digits. A **stop destination** can open a link, an app URL, or a Shortcut afterwards. |
| **Home** | Greeting, Gregorian and Hijri date, next prayer with countdown, scrollable calendar strip (past and future days), today's progress and streak, next main task, upcoming alarms, level card, closest goals, recent achievements, Live Activity controls. |
| **Progress** | Streak, XP, levels with Arabic titles, points, ~50 achievements (some hidden), owner-defined **rewards**, a **shop** of cosmetics (themes, level-card frames, celebration effects, progress-bar styles, alternate app icons), and statistics (yearly heatmap, weekly completion, XP over 30 days). |
| **Custom pages** | A block-based page builder with 21 block types (inputs, sets table, counters, timers, stopwatch, charts, history, images, links, action buttons…). Pages have tabs (optionally rotating), sessions with history and "last time" hints, an optional schedule that creates an alarm and a main task, and templates (workout, reading, water, study, plus user-saved). |
| **Lock Screen** | Live Activity with one segment per main task, the next task, and percent done. Widgets: small, medium, and Lock Screen circular, rectangular, and inline. |
| **Calc block** | A page block that computes a value from other blocks: sum, average, difference, product or ratio, with per-input weights (calories = protein×4 + carbs×4 + fat×9), optional multiplier, a period (today, 7-day average, 7-day total) and a goal (fixed or read from another block; number blocks can be set to remember their value across days so a goal is typed once). Sets tables can have up to 4 columns and any number of rows, so a meal can list foods with their macros. The AI page builder knows this block (`CalcEngine` and `AIPageBuilder` in HabitCore). |
| **AI keys** | Settings > AI keys: pick a provider (Google AI, ChatGPT, Kimi, Qwen, DeepSeek), paste your own key, and follow an illustrated how-to for that provider. Keys live in the device Keychain only (not in backups) and form an ordered fallback list (`AIKeyBook` in HabitCore, `AIKeyStore` in the app). No AI feature calls them yet. |
| **Settings** | Appearance (auto, light, dark), Western or Arabic-Indic digits, day-start hour, prayer location (GPS once, Saudi city list, or coordinates), custom alarm sound, Live Activity options, morning reminder, multi-prayer task options, backup and restore, signature-expiry reminder, alarm diagnostics, reset all data. |

The UI is **Arabic only** (casual Saudi dialect), **RTL**, locale `ar_SA`, with weeks starting on
Sunday. Text fields accept any language.

## 2. Tech stack

| Area | Technology |
|---|---|
| Language | Swift (Swift 5 language mode; package uses swift-tools 5.9) |
| UI | SwiftUI with Observation (`@Observable`), `@Query`, `@AppStorage` |
| Persistence | **SwiftData** for records, `UserDefaults` for settings |
| Alarms | **AlarmKit** (iOS 26) |
| Notifications | `UserNotifications` |
| Lock Screen | **ActivityKit** (Live Activity) and **WidgetKit** (extension target) |
| Intents | `AppIntents` (`LiveActivityIntent` for the alarm stop button) |
| Background | `BGTaskScheduler` app refresh |
| Sensors | CoreMotion (`CMPedometer`, accelerometer) and CoreLocation (one-shot) |
| Prayer times | [`adhan-swift`](https://github.com/batoulapps/adhan-swift) 1.5: Umm al-Qura method, Shafi'i Asr |
| Project generation | **XcodeGen** (`project.yml`). The `.xcodeproj` is not committed. |
| CI | GitHub Actions on `macos-26` |
| Tests | XCTest, about 167 unit tests on the `HabitCore` package |

**Minimum iOS:** 26.1 (AlarmKit and the APIs used require iOS 26). iPhone only, portrait.

## 3. Getting started

### Run the logic tests (any Mac or Linux with a Swift toolchain that can build the package)
```bash
swift test --package-path Packages/HabitCore
```
Most of the app's rules live in `HabitCore`, so this is the fastest feedback loop.

### Build the app (Mac with Xcode 26)
```bash
brew install xcodegen
xcodegen generate          # creates Habits.xcodeproj from project.yml
open Habits.xcodeproj      # pick the "Habits" scheme, set your own team / bundle id to run on a device
```
- Bundle ids: `com.ghazaly.habits` (app) and `com.ghazaly.habits.widgets` (widget extension).
- App Group: `group.com.ghazaly.habits`. It is shared by the app and the widgets and is required for the
  widgets and Live Activity. If you change bundle ids, change the App Group too.
- `Config/*.entitlements` and `Config/*-Info.plist` are **generated** by XcodeGen. Edit `project.yml`, not
  those files.

### Build without a Mac
Push to `main` or run the workflow manually. GitHub Actions builds an **unsigned IPA**, fake-signs it with
`ldid` (entitlements included), and publishes it as a Release and an **AltStore source**. See
[§8](#8-ci-and-distribution).

## 4. Repository layout

```
.
├── project.yml                     # XcodeGen spec: Habits (app) + HabitsWidgets (extension)
├── .github/workflows/build.yml     # test → build → IPA → Release → AltStore source
├── docs/design/layout-reference.png# layout reference: curved header, curved bottom bar, round Home button
├── Packages/HabitCore/             # PURE logic package (no UI, no SwiftData) + all unit tests
│   ├── Sources/HabitCore/
│   │   ├── Common/        DayKey, AppearanceMode, DigitStyle/NumberFormatting, SignatureMath
│   │   ├── Tasks/         TaskKind, TaskSpec, DayProgress
│   │   ├── Recurrence/    Weekday, Repetition
│   │   ├── Streak/        StreakEngine
│   │   ├── Progress/      XP, points, levels, titles, streak milestones
│   │   ├── Achievements/  catalog, evaluator, timing (before Dhuhr / after Isha)
│   │   ├── Rewards/       user-defined reward conditions
│   │   ├── Shop/          ShopCatalog (cosmetics)
│   │   ├── Stats/         history stats, weekly completion, heatmap, XP timeline
│   │   ├── Home/          greeting, next prayer, countdown, next main task
│   │   ├── Prayer/        Prayer, Direction, PrayerTimeProviding, AdhanPrayerTimes
│   │   ├── Alarms/        AlarmRule, TimeSpec, NotificationPlanner, challenges, chain & ledger
│   │   ├── Pages/         block schema, sessions & logic, tree editing, templates
│   │   └── Backup/        versioned backup document + coding/validation
│   └── Tests/HabitCoreTests/       one file per area + TestSupport (fixed prayer times…)
├── App/                            # iOS app target
│   ├── AppMain.swift               # @main
│   ├── Navigation/                 # RootView (hub), AppRouter, AppTab, CurvedTabBar
│   ├── Persistence/                # SwiftData models + *Actions (all writes)
│   ├── Services/                   # AlarmScheduler, AlarmNotifier, LiveActivityController, AppDelegate, …
│   ├── Design/                     # CurvedPage/Header, shapes, Metrics, Motion, ChoiceChip, SettingsKey, appRoot
│   ├── Features/                   # Home, Tasks, Alarms, Challenges, Pages, Progress, Settings
│   └── Resources/                  # Localizable.xcstrings (source: ar), InfoPlist.xcstrings, Assets (11 icons)
├── Shared/                         # compiled into BOTH the app and the widget extension
│   ├── AppGroup.swift, Theme.swift, WidgetSnapshot.swift, TodayActivityAttributes.swift,
│   └── AlarmMetadata.swift, ProgressVisuals.swift, SharedFormat.swift (+ DeepLink)
└── Widgets/                        # TodayWidget, TodayLiveActivity, HabitAlarmActivity, bundle
```

## 5. Architecture

### 5.1 Three layers

```
┌───────────────────────────────────────────────────────────┐
│ App/Features  (SwiftUI views)                             │  read: @Query, @AppStorage
│   └─ compute derived state with ProgressSnapshot.make()   │  write: call *Actions
├───────────────────────────────────────────────────────────┤
│ App/Persistence + App/Services                            │  SwiftData @Model records,
│   TaskActions, AlarmActions, PageActions,                 │  JSON-encoded HabitCore values,
│   AchievementActions, BackupService, AlarmScheduler…      │  system frameworks
├───────────────────────────────────────────────────────────┤
│ Packages/HabitCore  (pure, tested)                        │  value types + pure functions,
│   rules for streak, XP, planning, challenges, pages…      │  Foundation + Adhan only
└───────────────────────────────────────────────────────────┘
```

1. **HabitCore:** no SwiftUI, no SwiftData, no `UserDefaults`, no hidden clock. Time (`now`) and
   `Calendar` are always parameters. Every rule here has tests.
2. **Persistence:** `@Model` classes (`TaskRecord`, `CompletionRecord`, `AlarmRecord`, `PageRecord`,
   `PageSessionRecord`, `AchievementUnlockRecord`, `PurchaseRecord`, `RewardRecord`). Complex values are
   stored as JSON `Data` (`repetitionData`, `timeData`, `definitionData`, …) and exposed through computed
   properties that convert to HabitCore types (`TaskRecord.spec`, `AlarmRecord.rule`,
   `PageRecord.definition`). **All mutations go through the `*Actions` enums.**
3. **Features:** thin views that read, derive and call Actions.

### 5.2 Derived, never stored
XP, points, level, streak, complete days and statistics are **never persisted**.
`ProgressSnapshot.make(tasks:completions:now:dayStartHour:extras:)` recomputes them from history every
time. The consequences:
- Un-completing a task revokes its XP and points automatically, so rewards can't be farmed.
- Editing the past stays consistent.
- The only stored "extras" are unlocked achievements (kept once earned), shop purchases, and the cost of
  claimed point-rewards.

### 5.3 History is never rewritten
- Deleting a task **that has completions** sets `endDay = today` (exclusive). Past days and the streak are
  unchanged. A task with no history is removed completely. Both can be undone (`DeleteUndo`).
- Changing the schedule of a linked task (from an alarm or page) **that has history** ends the old task
  today and starts a new one.

### 5.4 The day
`DayKey` (year, month, day) is the unit of history. The **day-start hour** setting (0–23) lets late-night
activity count for the previous day. Always use `Calendar.app` (Gregorian, week starts Sunday, current time
zone) and `DayKey(date:calendar:dayStartHour:)`.

### 5.5 RootView (the hub)
`App/Navigation/RootView.swift` hosts:
- the five tabs, laid out side by side as pages. All stay alive, you can swipe from the screen edges, and
  they cross-fade when Reduce Motion is on.
- one **shared morphing curved header**. Pages describe it through `HeaderConfig` and a `PreferenceKey`.
- the `CurvedTabBar`, sheets (settings, level-up, achievement unlock), the day-complete overlay, and the
  full-screen challenge.
- reactive background jobs:
  - `.task(id: replanKey)` runs `AlarmActions.replan` whenever an alarm fingerprint, the location, the sound
    or the day changes.
  - `.task(id: widgetKey)` rebuilds the `WidgetSnapshot` and syncs the Live Activity.
  - auto backup, signature reminder, morning reminder, achievement sync, deep links (`habits://today`,
    `habits://start`), day change, scene phase, and `.achievementsNeedSync`.

`AppRouter` (`@Observable`) holds navigation and celebration state. `AppEnvironment.shared` owns the
`ModelContainer` and the router, so intents and background tasks can reach them.

### 5.6 Data flow for alarms
```
AlarmRecord(s) ─► AlarmRule ─► NotificationPlanner.plan (14 days, concrete dates)
                                   ├─► AlarmScheduler  (delivery = .alarm)        → AlarmKit
                                   └─► AlarmNotifier   (delivery = .notification) → UNUserNotificationCenter
Stop button ─► OpenHabitsIntent ─► AppRouter.alarmStoppedAt ─► RootView: challenge? destination?
```

### 5.7 Data flow for widgets and the Live Activity
```
SwiftData ─► WidgetSnapshotBuilder ─► WidgetSnapshot.json (App Group container) ─► Widgets
                                   └► LiveActivityController ─► ActivityKit (TodayActivityAttributes)
```
The widget extension does **not** link HabitCore. Logic it needs is mirrored in `Shared/`.

## 6. Domain rules

### 6.1 Tasks
- **Main** tasks drive the streak, the Live Activity, the widgets and "day complete".
- **Secondary** tasks give the same XP but don't affect the streak. `repetition == nil` means "anytime,
  until done".
- `Repetition`: `.once(DayKey)`, `.weekly(Set<Weekday>)` (`.daily` = all seven days), or
  `.monthly(Set<Int>)`. A monthly day the month doesn't have (for example, the 31st in April) fires on the
  month's **last day**.
- `routineEnd` (inclusive, copied from an alarm's end day) is different from `endDay` (exclusive, meaning
  the task was stopped).
- **App block** (`TaskRecord.blocksApps`, off by default): a main task with an enabled alarm can block the
  owner's chosen apps from its first time of the day until it is done. iOS can't close other apps, so the
  owner makes a Shortcuts automation that runs the app's `BlockStatusIntent` ("فيه قفل؟", answers yes/no
  without opening the app) whenever one of those apps opens, and opens this app only if the answer is yes.
  `RootView` covers the app with `AppBlockView` while `AppBlockRule.blockingIDs` (HabitCore, pure) returns tasks. The
  screen's only way out is marking the task done. A master switch (`SettingsKey.appBlockEnabled`, default on)
  turns it all off. `AppBlockGuideView` (Settings) explains the automation steps.

### 6.2 Streak (`StreakEngine`)
| Day state | Effect |
|---|---|
| 100 % of main tasks | streak **+1**, missed run resets |
| 1–99 % | streak **holds**, missed run resets |
| 0 % (tasks existed) | missed run +1. After **3** grace days in a row, streak **−1 per further day** (minimum 0) |
| no main tasks | neutral |
| today | counts only when complete, and is never "missed" before it ends |

There are intentionally **no streak freezes or skips**.

### 6.3 XP, points, levels (`ProgressRules`)
- Completed task: **10 XP, 1 point**. Complete day: **20 XP, 3 points**.
- Best-streak milestones: 7 → 50 XP / 5 pts, 14 → 100/10, 30 → 200/20, 60 → 300/30, 100 → 500/50,
  200 → 800/80, 365 → 1500/150.
- XP needed to go from level L to L+1 = **100 + 25 × (L − 1)**.
- Titles: مبتدئ 1–4 · مثابر 5–9 · منضبط 10–19 · متقن 20–34 · قدوة 35–49 · أسطورة 50+.
- Displayed totals = history + achievement bonuses − spent points. Achievements are judged on the **base
  level** (without achievement XP) to avoid a feedback loop.

### 6.4 Achievements
About 50 entries in `AchievementCatalog`, with **stable string ids** (`tasks.100`, `streak.30`, `run.7`,
`level.10`, `hidden.comeback`, `bigday.5`, `early.1`, `night.10`, `page.1`, `sessions.50`, …).
Conditions: total tasks, complete days, best streak, consecutive complete run, base level, comebacks
(completing a day after 3 or more missed days), secondary tasks, a big day, early bird (finished before
Dhuhr), night finisher (finished after Isha), pages created, and page sessions. Hidden achievements show
"؟؟؟" until unlocked.

### 6.5 Rewards and shop
- **Rewards** are user-defined. A reward unlocks at a level, streak, task count, perfect-day count, or
  achievement, or it costs points (deducted on claim). States: locked, unlocked, claimed.
- The **shop** is **cosmetic only**. Categories: theme (10), frame (7), effect (6), liveStyle (5),
  appIcon (11). Each item has a price and a required level. Equipped items are stored in
  `SettingsKey.equipped*`.

### 6.6 Prayer times
`AdhanPrayerTimes` uses Umm al-Qura with Shafi'i Asr and covers Fajr, Dhuhr, Asr, Maghrib and Isha. The
location comes from GPS (one shot), a list of 20 Saudi cities, or manual coordinates. Without a location,
prayer-based items show their wording instead of a time and aren't scheduled.

### 6.7 Alarms
- `AlarmRule` fields: `title`, `note`, `isEnabled`, `repetition`, `time` (`.clock(h, m)` or
  `.prayer(p, .before/.after, h, m)`), `extraPrayers`, `endDay` (inclusive), `isMainTask`, `linkedPageID`,
  `delivery` (`.alarm` or `.notification`), `challenge`, `stopDestination`.
- **Planning** (`NotificationPlanner.plan`) covers the next **14 days**. It starts one day early because
  "after Isha" can cross midnight. Results are sorted and capped (60 for AlarmKit, 40 for notifications;
  iOS allows 64 pending). Identifiers are stable: `alarm.<uuid>.<yyyyMMddHHmm>`.
- **AlarmScheduler** schedules one-time `.fixed(date)` AlarmKit alarms:
  - ids are **SHA-256-derived stable UUIDs** (identifier + fingerprint), so replanning is a cheap diff.
  - it cancels stale scheduled alarms and never touches ringing, snoozed or paused ones (except orphans).
  - it prioritizes the next 48 hours and challenge chains, and evicts far-away alarms when
    `maximumLimitReached`.
  - it falls back to a classic alarm if the system refuses the challenge configuration.
  - snooze is 10 minutes (none on challenge alarms).
  - it writes an `AlarmScheduleReport`, shown in **Settings → System check**.
- **AlarmNotifier** handles notification-only alarms. Request ids use the prefix
  `com.ghazaly.habits.alarmnote.`.
- One-time alarms switch themselves off after ringing.
- Replanning happens on launch, on foreground, on day change, on any relevant change, and during
  background refresh (about every 6 hours; iOS decides the exact time).

### 6.8 Challenge alarms
| Kind | Range | Notes |
|---|---|---|
| `math` | 1–10 questions; easy/medium/hard | addition and subtraction, answer never negative |
| `steps` | 10–2000 | `CMPedometer` |
| `typing` | — | Arabic phrases; diacritics, tatweel and extra spaces are ignored |
| `shake` | 10–200 | accelerometer |
| `memory` | 3–10 digits | never starts with 0 |

The system stop button can't be blocked. Instead, each of the next **2** rings gets a **chain of 10 extra
alarms, one per minute**. `ChallengeLedger` (JSON in UserDefaults) tracks pending and completed rings, and
completing the challenge cancels the rest of the chain. `ChallengeView` is a full-screen cover that can't be
dismissed until the challenge is done or the window ends (10 + 2 minutes). Devices without step counting or
a shake sensor fall back to math.

`StopDestination` can be:
- `.link`: https, app schemes, mailto or tel. `javascript`, `file`, `data` and `vbscript` are blocked. Bare
  domains get `https://`.
- `.shortcut`: opens `shortcuts://run-shortcut?name=…`.

### 6.9 Custom pages
- A **`PageDefinition`** (stored as JSON) has: `name`, `emoji`, `accent`, `tabs` (each with a list of
  `Block`s), `rotatesTabs` (scheduled sessions cycle A → B → C), `schedule` (same editor as alarms; it
  creates a linked alarm and, if `isMainTask` is set, a linked main task), `pinnedToHome`, and `anchorDay`.
- **`Block` is one flexible struct.** Every field has a default when decoding, so old pages always load.
  Add new fields with defaults, and bump `pageSchemaVersion` only for breaking changes.
- **21 block kinds:**
  - **Layout:** heading, text, divider, container (nests other blocks), image, link.
  - **Input:** text field, number, sets table, counter, checkbox, checklist, choice, rating, date and time.
  - **Time:** timer (sends a local notification when done), stopwatch.
  - **Display:** progress (can sum several sources), chart (`value`, `setsMax`, `setsVolume`,
    `setsTotal`), history.
  - **Action:** button (`finishSession`, `completeTask`, `startTimer`, `openPage`, `openAlarm`,
    `addSecondaryTask`, `clearFields`).
- **`PageSession`** stores values keyed by block id. It provides "last time" hints, untouched sessions
  aren't saved, and **finishing a session** completes the page's linked main task for today.
- The page has two modes: **use** (`PageUseView`) and **edit** (`PageEditView`). Pure tree operations are
  in `PageTree.swift`.
- **Templates:** workout (Full Body A/B/C rotation), reading, water, study, and user-saved templates.

### 6.10 Widgets and Live Activity
- The app writes `WidgetSnapshot` to the App Group container. `AppGroup.identifier` prefers the
  `ALTAppGroups` Info.plist key, because sideloading tools may rename the group.
- The Live Activity shows one segment per main task, the next task and its time, the percentage, and an
  "open app" link. It has **no complete buttons**. It auto-starts, is renewed (activities live about 8 hours,
  and a reminder notification is scheduled), and has a "stop for today" option.
- Widget families: small, medium, accessoryCircular, accessoryRectangular, accessoryInline.
  `HabitAlarmActivity` is required by AlarmKit to display snoozed alarms.
- The equipped theme id is mirrored to the App Group defaults so widgets match the app.

### 6.11 Backup
- A `BackupDocument` uses **schema v1**, ISO-8601 dates and sorted keys. It contains every record type,
  the settings listed in `BackupService.settingKeys`, and page images.
- Decoding refuses newer schema versions and validates that ids are unique. Restoring **replaces
  everything**.
- **Weekly automatic copies** are saved to `Documents/Backups` (`habits-backup-YYYY-MM-DD.json`). The 4
  newest are kept, and they're visible in the Files app.
- The custom alarm sound file isn't backed up.

### 6.12a Sound effects
Four moments have sounds: task done, achievement / level up, day complete and shop purchase (`SoundEvent`). Each has
4 sounds (`App/Resources/Sounds/sfx_<event>_0…3.m4a`). `SoundEffects` plays them in random order through
`ShuffleBag` (HabitCore, pure): a sound only comes back after the other three have played, and the bag is kept in
`UserDefaults` between launches. `AppRouter.celebrate` picks one sound per completion (day complete beats
achievement beats task done). Audio uses the playback category with `mixWithOthers`: it plays even on silent,
follows the media volume, and doesn't stop the user's music. A Settings switch
(`SettingsKey.soundEffectsEnabled`, default on) turns them off.

### 6.12 Settings keys
All keys are in `SettingsKey` (`App/Design/AppRoot.swift`, plus an extension in `BackupService.swift`):
appearance, digitStyle, dayStartHour, prayer location, equipped shop items, Live Activity options, morning
reminder, alarmSound (imported audio converted to `.caf` in `Library/Sounds`, up to 29 seconds),
taskShowAllTimes, taskFollowsNextRing, autoBackupEnabled, lastBackupAt, signatureReminderEnabled.

## 7. Design system
- **Look:** white and greens (black and green in dark mode), a **curved header** with an arc, and a
  **curved bottom bar** with a raised round **Home** button (see `docs/design/layout-reference.png`). Tab
  order from right to left: المهمات · التنبيهات · (الرئيسية) · الإنجازات · صفحاتي.
- **Colors:** use only `Theme` tokens (`primary`, `primaryStrong`, `barMuted`, `surface`, `card`,
  `textPrimary`, `textSecondary`, `danger`, `gold`). Never use raw colors. `gold` is reserved for
  achievements, levels and rewards. Tokens adapt to light and dark mode and to the equipped shop theme.
- **Root modifier:** `.appRoot()` sets RTL, `ar_SA`, digit style, color scheme, tint, and `.id(theme)` so
  the view tree rebuilds when the theme changes. **Apply it to every sheet and fullScreenCover.**
- **RTL geometry:** layout that must not mirror (pager offsets, the tab-bar arc) goes inside an explicit
  LTR container.
- **Numbers:** show them through the digit-style environment (`digits.format(…)`, `NumberFormatting`).
  Prefix math expressions with an LTR mark (`\u{200E}`).
- **Accessibility:** state is never shown by color alone (checkmark + strikethrough, distinct shapes), the
  header grows with Dynamic Type, Reduce Motion gives cross-fades, accessibility labels are in Arabic, and
  haptics play on success. The guidelines follow Apple's HIG.
- **Reusable pieces:** `CurvedPage`, `CurvedHeader`, `HeaderButton`, `ChoiceChip`, `SegmentBar`,
  `ProgressRing`, `Metrics`, the `Motion` helpers.

## 8. CI and distribution
`.github/workflows/build.yml` runs on pushes to `main`, on `v*` tags, and on manual dispatch:
1. Selects the newest Xcode 26 and installs `xcodegen` and `ldid`.
2. **Runs the HabitCore tests.** A failing test stops the build.
3. Runs `xcodegen generate` and `xcodebuild` (Release, `generic/platform=iOS`, code signing disabled). The
   build number is the run number.
4. Runs `ldid -S` with the entitlements (extension first, then the app). **It fails if the App Group isn't
   embedded.**
5. Packages `Payload/Habits.app` as `Habits.ipa` and uploads it as an artifact.
6. On `v*` tags: attaches the IPA to that release.
7. On `main`: publishes the `build-<n>` release (marked latest) and refreshes `source.json` in the
   `altstore-source` release, so **AltStore** always offers the newest build.

A free-account signature expires after 7 days. The app reads `embedded.mobileprovision` and schedules a
reminder one day before it expires.

## 9. How to extend the project (recipes)

**Add a SwiftData property**
1. Add it with a **default value** (`var x: Int = 0`) so lightweight migration works.
2. If it should survive backups, add it to the matching `Backup*` struct in `BackupDocument.swift` (as an
   optional) and to `BackupService.makeDocument` and `BackupService.restore`.
3. If it affects ringing, include it in `AlarmRecord.fingerprint`.

**Add an achievement**
1. Append an `AchievementDef` to `AchievementCatalog.all` with a **new, unique id**. Never rename or reuse
   ids.
2. If it needs a new statistic, add a case to `AchievementCondition`, a field to `AchievementStats`, compute
   it in `ProgressSnapshot`, and handle it in `AchievementEvaluator.progress`.
3. Add tests.

**Add a shop item**
1. Add a `ShopItem` to `ShopCatalog.all`.
2. Theme: add a palette in `ThemePalette.palette(for:)`.
3. Frame, effect or bar style: handle the id in `FrameBorder`, `ConfettiView` or `SegmentBar`.
4. App icon: add the `IconXxx.appiconset`, add the name to `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`
   in `project.yml`, and add a preview in `ShopSection`.

**Add a page block type**
1. Add a case to `BlockKind`, plus its `arabicName`, `symbol`, flags (`isInput`, `isChartable`,
   `isNumeric`) and category.
2. Add defaults in `Block.make`. Add any new fields to `Block` **with decoder defaults**.
3. Render it in `BlockUseView`, configure it in `BlockConfigView`, and describe its value in
   `PageValueText`.
4. If it stores a value, extend `BlockValue` (and `PageLogic.metricValue` if it can be charted). Add tests in
   `PagesTests`.

**Add a challenge type**
1. Add a case to `ChallengeKind` and its range or fields to `AlarmChallenge` (clamped, decoded with
   defaults). Put any generator or checker logic in HabitCore and test it.
2. Add its name and settings in `ChallengeSection` and its screen in `ChallengeView`. If the device may not
   support it, fall back to math.

**Add a setting**
1. Add a key to `SettingsKey` and read it with `@AppStorage`.
2. Add it to `BackupService.settingKeys` if it should be backed up.
3. If it changes what widgets or alarms show, include it in `widgetKey` or `replanKey` in `RootView`.

**Change a rule (streak, XP…)**
Change it in HabitCore and update or add tests. Because everything is derived, the new rule applies to the
whole history at once. Make sure that's what you want.

## 10. Conventions and rules
1. **Logic goes in HabitCore, with tests.** Keep views thin. Pass `now` and `calendar` in.
2. **Don't store derived numbers** (XP, points, streak, level).
3. **Don't rewrite history.** Use `endDay` instead of deleting tasks that have completions.
4. **Backward-compatible data:** use defaults for new SwiftData properties, `decodeIfPresent` with
   defaults for new Codable fields, and keep enum raw values and ids stable. Bump
   `BackupDocument.currentVersion` only for breaking backup changes.
5. **Anything that affects ringing must change the alarm fingerprint**, so that a replan runs.
6. **Respect system limits:** 64 pending notifications and the AlarmKit maximum. Plan concrete dates in a
   rolling window.
7. **Write through `*Actions`**, call `try? context.save()`, and post `.achievementsNeedSync` when something
   outside tasks might unlock an achievement.
8. **Language:** UI strings are in Arabic (casual Saudi tone), written with `Text("…")` or
   `String(localized:)`. `Localizable.xcstrings` has Arabic as its source language. Code, comments and
   commit messages are in English.
9. **The widget extension can't import HabitCore.** Put shared code in `Shared/` and keep mirrored rules in
   sync (`WidgetSnapshot.nextItem` / `effectiveTime` must match `NextMainTask` /
   `TodayTaskItem.effectiveTime`).
10. **Always use `AppGroup.identifier`**, never a hard-coded group string.
11. **Product principles:** no streak freezes, main and secondary tasks give equal XP, the shop is cosmetic
    only, the Live Activity has no complete buttons, and data stays on the device.
12. **Branches and PRs:** `feature/…` and `fix/…`. Keep commits focused.

## 11. Where to change what
| To change… | Look in |
|---|---|
| Streak rules | `HabitCore/Streak/StreakEngine.swift` |
| XP, points, level curve | `HabitCore/Progress/ProgressCalculator.swift` |
| Achievements | `HabitCore/Achievements/Achievements.swift` |
| Shop items | `HabitCore/Shop/ShopCatalog.swift`, `Shared/Theme.swift`, `Features/Progress/ShopSection.swift` |
| Alarm timing math | `HabitCore/Alarms/NotificationPlanner.swift` |
| AlarmKit integration | `App/Services/AlarmScheduler.swift` |
| Notification-only alarms | `App/Services/AlarmNotifier.swift` |
| App block (apps locked until a task is done) | `HabitCore/Tasks/AppBlock.swift`, `App/Persistence/AppBlockService.swift`, `App/Services/BlockStatusIntent.swift`, `Features/AppBlock/AppBlockView.swift`, `RootView` |
| Challenges | `HabitCore/Alarms/AlarmChallenge.swift`, `Features/Alarms/ChallengeSection.swift`, `Features/Challenges/ChallengeView.swift` |
| Page blocks | `HabitCore/Pages/PageSchema.swift`, `Features/Pages/BlockUseView.swift`, `BlockConfigView.swift`, `PageSupport.swift` |
| Page templates | `HabitCore/Pages/PageTemplates.swift` |
| Home screen | `Features/Home/HomeView.swift`, `CalendarStrip.swift` |
| Widgets and Live Activity | `Widgets/*.swift`, `Shared/ProgressVisuals.swift`, `App/Services/LiveActivityController.swift` |
| Backup | `HabitCore/Backup/BackupDocument.swift`, `App/Persistence/BackupService.swift` |
| Settings | `Features/Settings/SettingsView.swift`, `App/Design/AppRoot.swift` |
| Header, tab bar, shapes | `App/Design/CurvedPage.swift`, `CurvedShapes.swift`, `Metrics.swift`, `Navigation/CurvedTabBar.swift` |
| Build and release | `project.yml`, `.github/workflows/build.yml` |

---
---

<div dir="rtl">

# الجزء الثاني — العربية

## المحتويات
١. المزايا · ٢. التقنيات · ٣. البدء · ٤. هيكل المستودع · ٥. البنية المعمارية · ٦. قواعد التطبيق ·
٧. نظام التصميم · ٨. البناء والتوزيع · ٩. وصفات التوسعة · ١٠. القواعد والاتفاقيات · ١١. وين أعدّل وش

## ١. المزايا

| القسم | وش يسوي |
|---|---|
| **المهمات** | مهمات رئيسية وفرعية. التكرار: مرة وحدة، أسبوعي (أي أيام)، شهري (أي تواريخ). الفرعية ممكن تكون "بدون موعد لين تنجزها". ترتيب بالسحب، وفلترة (الكل / الرئيسية / الفرعية)، وتراجع عن الحذف. |
| **التنبيهات** | منبهات حقيقية عن طريق **AlarmKit** ترن حتى لو الجوال صامت، أو تنبيه إشعار فقط. الوقت إما ساعة عادية أو **بالنسبة للصلاة** ("قبل الفجر بـ 30 دقيقة")، على صلاة وحدة أو أكثر. الروتين ممكن يكون له تاريخ نهاية. والتنبيه ممكن يكون **تنبيه مهمة رئيسية** يسوي مهمة مرتبطة فيه ويحدّثها. |
| **منبهات التحدي** | المنبه يظل يرن لين تحل تحدي: معادلات، أو مشي خطوات، أو كتابة جملة، أو هز الجوال، أو حفظ أرقام. و**وجهة الإيقاف** تفتح رابط أو تطبيق أو اختصار بعدها. |
| **الرئيسية** | التحية، والتاريخ الميلادي والهجري، والصلاة الجاية مع عد تنازلي، وشريط تقويم يتمرر (أيام ماضية وقادمة)، وتقدم اليوم والستريك، والمهمة الرئيسية التالية، والتنبيهات القادمة، وبطاقة المستوى، وأقرب الأهداف، وآخر الإنجازات، وأزرار العرض الحي. |
| **التقدم** | ستريك، وخبرة، ومستويات بألقاب عربية، ونقاط، وتقريباً ٥٠ إنجاز (بعضها مخفي)، و**جوائز** يحددها المستخدم، و**متجر** تجميلي (ثيمات، إطارات لبطاقة المستوى، مؤثرات احتفال، أشكال شريط التقدم، أيقونات بديلة)، وإحصائيات (خريطة حرارية لسنة، ونسبة الإنجاز الأسبوعية، والخبرة لآخر ٣٠ يوم). |
| **الصفحات الخاصة** | باني صفحات من القطع فيه ٢١ نوع (إدخال، جدول مجموعات، عدادات، مؤقتات، ساعة إيقاف، رسوم بيانية، سجل، صور، روابط، أزرار إجراءات…). الصفحة لها تبويبات (ممكن تدور)، وجلسات بسجل وتلميح "آخر مرة"، وموعد اختياري يسوي تنبيه ومهمة رئيسية، وقوالب (تمارين، قراءة، ماء، مذاكرة، وقوالب المستخدم). |
| **شاشة القفل** | عرض حي فيه جزء لكل مهمة رئيسية، والمهمة التالية، ونسبة الإنجاز. والويدجت: صغير، ومتوسط، ولشاشة القفل دائري ومستطيل وسطر. |
| **الإعدادات** | المظهر (تلقائي / فاتح / داكن)، والأرقام غربية أو عربية هندية، وساعة بداية اليوم، وموقع الصلاة (GPS مرة وحدة، أو قائمة مدن سعودية، أو إحداثيات)، وصوت منبه مخصص، وخيارات العرض الحي، وتذكير الصباح، وخيارات المهمات متعددة الصلوات، والنسخ الاحتياطي والاسترجاع، وتذكير انتهاء التوقيع، وفحص المنبهات، وحذف كل البيانات. |

الواجهة **عربية فقط** (بلهجة سعودية عامية)، ومن **اليمين لليسار**، واللغة المحلية `ar_SA`، والأسبوع يبدأ
الأحد. وخانات الكتابة تقبل أي لغة.

## ٢. التقنيات

| المجال | التقنية |
|---|---|
| اللغة | Swift (وضع لغة Swift 5، والحزمة swift-tools 5.9) |
| الواجهة | SwiftUI مع Observation (`@Observable`) و`@Query` و`@AppStorage` |
| التخزين | **SwiftData** للسجلات، و`UserDefaults` للإعدادات |
| المنبهات | **AlarmKit** (iOS 26) |
| الإشعارات | `UserNotifications` |
| شاشة القفل | **ActivityKit** (العرض الحي) و**WidgetKit** (هدف إضافة منفصل) |
| الأوامر | `AppIntents` (`LiveActivityIntent` لزر إيقاف المنبه) |
| الخلفية | تحديث خلفي بـ `BGTaskScheduler` |
| الحساسات | CoreMotion (`CMPedometer` ومقياس التسارع) وCoreLocation (مرة وحدة) |
| أوقات الصلاة | مكتبة `adhan-swift` 1.5: طريقة أم القرى، والعصر على المذهب الشافعي |
| توليد المشروع | **XcodeGen** (`project.yml`). ملف `.xcodeproj` غير مرفوع. |
| البناء المستمر | GitHub Actions على `macos-26` |
| الاختبارات | XCTest، تقريباً ١٦٧ اختبار على حزمة `HabitCore` |

**أقل إصدار iOS:** 26.1 (لأن AlarmKit والواجهات المستخدمة تحتاج iOS 26). آيفون فقط، وبالوضع العمودي.

## ٣. البدء

### تشغيل اختبارات المنطق (على أي ماك، أو لينكس فيه أدوات Swift تقدر تبني الحزمة)
```bash
swift test --package-path Packages/HabitCore
```
أغلب قواعد التطبيق موجودة في `HabitCore`، فهذي أسرع طريقة تتأكد فيها من شغلك.

### بناء التطبيق (ماك فيه Xcode 26)
```bash
brew install xcodegen
xcodegen generate          # يسوي Habits.xcodeproj من project.yml
open Habits.xcodeproj      # اختر مخطط "Habits"، وحط فريقك ومعرّف الحزمة حقك عشان تشغله على جهاز
```
- معرّفات الحزمة: `com.ghazaly.habits` (التطبيق) و`com.ghazaly.habits.widgets` (الويدجت).
- مجموعة التطبيق (App Group): `group.com.ghazaly.habits`. يتشاركها التطبيق والويدجت، والويدجت والعرض الحي
  ما يشتغلون بدونها. إذا غيّرت معرّفات الحزمة غيّرها هي بعد.
- ملفات `Config/*.entitlements` و`Config/*-Info.plist` **يولّدها** XcodeGen. عدّل `project.yml` مو هذي الملفات.

### البناء بدون ماك
ادفع على `main` أو شغّل خط البناء يدوياً. GitHub Actions يبني ملف **IPA غير موقّع**، ويوقّعه توقيع وهمي بـ
`ldid` (مع الصلاحيات)، وينشره كـ Release وكـ **مصدر لـ AltStore**. التفاصيل في القسم ٨.

## ٤. هيكل المستودع

```
.
├── project.yml                     # مواصفات XcodeGen: Habits (التطبيق) + HabitsWidgets (الإضافة)
├── .github/workflows/build.yml     # اختبار ← بناء ← IPA ← Release ← مصدر AltStore
├── docs/design/layout-reference.png# مرجع التصميم: هيدر مقوس، شريط سفلي مقوس، زر رئيسية دائري
├── Packages/HabitCore/             # حزمة المنطق الصافي (بدون واجهة وبدون SwiftData) + كل الاختبارات
│   ├── Sources/HabitCore/
│   │   ├── Common/        DayKey، المظهر، الأرقام وتنسيقها، حساب انتهاء التوقيع
│   │   ├── Tasks/         نوع المهمة، TaskSpec، تقدم اليوم
│   │   ├── Recurrence/    أيام الأسبوع، التكرار
│   │   ├── Streak/        محرك الستريك
│   │   ├── Progress/      الخبرة، النقاط، المستويات، الألقاب، محطات الستريك
│   │   ├── Achievements/  الكتالوج، المقيّم، التوقيت (قبل الظهر / بعد العشاء)
│   │   ├── Rewards/       شروط الجوائز
│   │   ├── Shop/          كتالوج المتجر
│   │   ├── Stats/         إحصائيات التاريخ، الإنجاز الأسبوعي، الخريطة الحرارية، خط الخبرة
│   │   ├── Home/          التحية، الصلاة الجاية، العد التنازلي، المهمة التالية
│   │   ├── Prayer/        الصلوات، قبل/بعد، مزود الأوقات، AdhanPrayerTimes
│   │   ├── Alarms/        AlarmRule، TimeSpec، مخطط المواعيد، التحديات، السلسلة والسجل
│   │   ├── Pages/         مخطط القطع، الجلسات ومنطقها، تعديل الشجرة، القوالب
│   │   └── Backup/        مستند النسخة الاحتياطية بإصدار + ترميزه والتحقق منه
│   └── Tests/HabitCoreTests/       ملف لكل مجال + TestSupport (أوقات صلاة ثابتة…)
├── App/                            # هدف تطبيق iOS
│   ├── AppMain.swift               # نقطة البداية
│   ├── Navigation/                 # RootView (المركز)، AppRouter، AppTab، CurvedTabBar
│   ├── Persistence/                # نماذج SwiftData + ملفات *Actions (كل الكتابة)
│   ├── Services/                   # جدولة المنبهات، الإشعارات، العرض الحي، AppDelegate، …
│   ├── Design/                     # الصفحة والهيدر المقوس، الأشكال، المقاسات، الحركة، الشرائح، مفاتيح الإعدادات، appRoot
│   ├── Features/                   # الرئيسية، المهمات، التنبيهات، التحديات، الصفحات، التقدم، الإعدادات
│   └── Resources/                  # الترجمة (اللغة الأساسية عربي)، الأصول (١١ أيقونة)
├── Shared/                         # ينبني داخل التطبيق والإضافة الاثنين
│   ├── AppGroup.swift، Theme.swift، WidgetSnapshot.swift، TodayActivityAttributes.swift،
│   └── AlarmMetadata.swift، ProgressVisuals.swift، SharedFormat.swift (+ الروابط)
└── Widgets/                        # TodayWidget، TodayLiveActivity، HabitAlarmActivity، والحزمة
```

## ٥. البنية المعمارية

### ٥.١ ثلاث طبقات

```
┌───────────────────────────────────────────────────────────┐
│ App/Features  (واجهات SwiftUI)                            │  القراءة: @Query و @AppStorage
│   └─ تحسب الحالة المشتقة بـ ProgressSnapshot.make()        │  الكتابة: عن طريق *Actions
├───────────────────────────────────────────────────────────┤
│ App/Persistence + App/Services                            │  سجلات SwiftData،
│   TaskActions، AlarmActions، PageActions،                 │  قيم HabitCore مرمّزة JSON،
│   AchievementActions، BackupService، AlarmScheduler…      │  وأطر النظام
├───────────────────────────────────────────────────────────┤
│ Packages/HabitCore  (صافي ومختبر)                         │  أنواع قيم ودوال صافية،
│   قواعد الستريك والخبرة والجدولة والتحديات والصفحات…       │  Foundation و Adhan فقط
└───────────────────────────────────────────────────────────┘
```

١. **HabitCore:** بدون SwiftUI، وبدون SwiftData، وبدون `UserDefaults`، وبدون ساعة مخفية. الوقت (`now`)
   والتقويم دايماً يجون كمعاملات. وكل قاعدة هنا لها اختبارات.
٢. **التخزين:** كلاسات `@Model` (`TaskRecord`، `CompletionRecord`، `AlarmRecord`، `PageRecord`،
   `PageSessionRecord`، `AchievementUnlockRecord`، `PurchaseRecord`، `RewardRecord`). القيم المعقدة تنحفظ
   JSON في `Data` وتنعرض بخصائص محسوبة تحوّلها لأنواع HabitCore (`TaskRecord.spec`، `AlarmRecord.rule`،
   `PageRecord.definition`). **كل تعديل يمر عن طريق ملفات `*Actions`.**
٣. **الواجهات:** خفيفة، تقرأ وتشتق وتنادي الـ Actions.

### ٥.٢ يُشتق، ما يُخزّن
الخبرة والنقاط والمستوى والستريك والأيام المكتملة والإحصائيات **ما تنحفظ أبداً**.
`ProgressSnapshot.make(...)` يحسبها من جديد من التاريخ كل مرة. والنتيجة:
- إذا ألغيت إنجاز مهمة تنسحب خبرتها ونقاطها تلقائياً، فما ينقدر التلاعب بالمكافآت.
- تعديل الماضي يظل متسق.
- الأشياء الإضافية الوحيدة المخزنة: الإنجازات المفتوحة (تظل بعد ما تنفتح)، ومشتريات المتجر، وتكلفة الجوائز
  المستلمة بالنقاط.

### ٥.٣ التاريخ ما يتغيّر
- حذف مهمة **لها إنجازات** يحط `endDay = اليوم` (غير شامل)، والأيام الماضية والستريك ما تتغير. المهمة اللي
  ما لها تاريخ تنحذف كلياً. والاثنين ينقدر التراجع عنهم (`DeleteUndo`).
- تغيير موعد مهمة مرتبطة (بتنبيه أو صفحة) **لها تاريخ** ينهي القديمة اليوم ويبدأ وحدة جديدة.

### ٥.٤ اليوم
`DayKey` (سنة، شهر، يوم) هو وحدة التاريخ. إعداد **ساعة بداية اليوم** (٠–٢٣) يخلي الشغل بعد منتصف الليل
ينحسب لليوم اللي قبله. استخدم دايماً `Calendar.app` (ميلادي، الأسبوع يبدأ الأحد، منطقة الجهاز الزمنية) و
`DayKey(date:calendar:dayStartHour:)`.

### ٥.٥ RootView (المركز)
`App/Navigation/RootView.swift` فيه:
- التبويبات الخمسة كصفحات جنب بعض. كلها تظل شغالة، وتنقدر تسحب من حواف الشاشة، وتتلاشى بدل الحركة لما يكون
  "تقليل الحركة" مفعّل.
- **هيدر مقوس واحد مشترك يتحول**. كل صفحة تحدده عن طريق `HeaderConfig` و`PreferenceKey`.
- `CurvedTabBar`، والنوافذ (الإعدادات، المستوى الجديد، فتح إنجاز)، وطبقة اكتمال اليوم، وشاشة التحدي الكاملة.
- مهام خلفية تتفاعل مع التغييرات:
  - `.task(id: replanKey)` يشغّل `AlarmActions.replan` كل ما تغيرت بصمة تنبيه أو الموقع أو الصوت أو اليوم.
  - `.task(id: widgetKey)` يعيد بناء `WidgetSnapshot` ويزامن العرض الحي.
  - النسخ الاحتياطي التلقائي، وتذكير التوقيع، وتذكير الصباح، ومزامنة الإنجازات، والروابط (`habits://today`
    و`habits://start`)، وتغير اليوم، وحالة التطبيق، و`.achievementsNeedSync`.

`AppRouter` (`@Observable`) يحفظ حالة التنقل والاحتفالات. و`AppEnvironment.shared` يملك `ModelContainer`
والراوتر، عشان الـ Intents والمهام الخلفية تقدر توصل لهم.

### ٥.٦ مسار بيانات التنبيهات
```
AlarmRecord ─► AlarmRule ─► NotificationPlanner.plan (١٤ يوم، مواعيد فعلية)
                                ├─► AlarmScheduler  (delivery = .alarm)        → AlarmKit
                                └─► AlarmNotifier   (delivery = .notification) → مركز الإشعارات
زر الإيقاف ─► OpenHabitsIntent ─► AppRouter.alarmStoppedAt ─► RootView: فيه تحدي؟ فيه وجهة؟
```

### ٥.٧ مسار بيانات الويدجت والعرض الحي
```
SwiftData ─► WidgetSnapshotBuilder ─► WidgetSnapshot.json (حاوية App Group) ─► الويدجت
                                   └► LiveActivityController ─► ActivityKit
```
إضافة الويدجت **ما تستورد** HabitCore، والمنطق اللي تحتاجه منسوخ في `Shared/`.

## ٦. قواعد التطبيق

### ٦.١ المهمات
- **الرئيسية** تحرّك الستريك والعرض الحي والويدجت و"اكتمال اليوم".
- **الفرعية** تعطي نفس الخبرة بس ما تأثر على الستريك. وإذا كان `repetition == nil` معناها "بدون موعد لين
  تنجزها".
- التكرار: `.once` (مرة وحدة)، أو `.weekly` (`.daily` = كل الأيام السبعة)، أو `.monthly`. واليوم الشهري اللي
  الشهر ما فيه (مثل ٣١ في أبريل) يصير في **آخر يوم** من الشهر.
- `routineEnd` (شامل، منسوخ من نهاية روتين التنبيه) غير `endDay` (غير شامل، معناه إن المهمة انوقفت).
- **قفل التطبيقات** (`TaskRecord.blocksApps`، مطفي افتراضياً): المهمة الرئيسية اللي لها تنبيه مفعّل تقدر تقفل
  التطبيقات اللي اخترتها من أول وقت لها في اليوم لين تخلصها. iOS ما يخلي تطبيق يقفل تطبيقات ثانية، فالمالك
  يسوي أتمتة في الاختصارات تشغّل أمر `BlockStatusIntent` («فيه قفل؟»، يجاوب نعم/لا من غير ما يفتح التطبيق) كل ما
  انفتح تطبيق من اللي اختارها، وتفتح هذا التطبيق بس إذا الجواب نعم. و`RootView` يغطي التطبيق بـ
  `AppBlockView` طول ما `AppBlockRule.blockingIDs` (في HabitCore، صافية) ترجع مهمات. المخرج الوحيد من الشاشة
  هو إنك تعلّم المهمة منجزة. ومفتاح عام (`SettingsKey.appBlockEnabled`، مفعّل افتراضياً) يطفي كل شي.
  و`AppBlockGuideView` (في الإعدادات) يشرح خطوات الأتمتة.

### ٦.٢ الستريك (`StreakEngine`)
| حالة اليوم | التأثير |
|---|---|
| ١٠٠٪ من المهمات الرئيسية | الستريك **+١** وعداد الغياب يرجع صفر |
| ١–٩٩٪ | الستريك **يثبت** وعداد الغياب يرجع صفر |
| ٠٪ (وكان فيه مهمات) | عداد الغياب +١، وبعد **٣** أيام سماح متتالية الستريك **ينقص ١ عن كل يوم زيادة** (أقل شي صفر) |
| ما فيه مهمات رئيسية | محايد |
| اليوم الحالي | ينحسب بس إذا اكتمل، وما يعتبر غياب قبل ما يخلص |

**ما فيه تجميد ستريك ولا تخطي، وهذا مقصود.**

### ٦.٣ الخبرة والنقاط والمستويات (`ProgressRules`)
- المهمة المنجزة: **١٠ خبرة، ١ نقطة**. اليوم المكتمل: **٢٠ خبرة، ٣ نقاط**.
- محطات أفضل ستريك: ٧ ← ٥٠ خبرة / ٥ نقاط، ١٤ ← ١٠٠/١٠، ٣٠ ← ٢٠٠/٢٠، ٦٠ ← ٣٠٠/٣٠، ١٠٠ ← ٥٠٠/٥٠،
  ٢٠٠ ← ٨٠٠/٨٠، ٣٦٥ ← ١٥٠٠/١٥٠.
- الخبرة المطلوبة من مستوى L إلى L+1 = **١٠٠ + ٢٥ × (L − ١)**.
- الألقاب: مبتدئ ١–٤ · مثابر ٥–٩ · منضبط ١٠–١٩ · متقن ٢٠–٣٤ · قدوة ٣٥–٤٩ · أسطورة ٥٠+.
- المعروض = التاريخ + مكافآت الإنجازات − النقاط المصروفة. والإنجازات تنحكم على **المستوى الأساسي** (بدون خبرة
  الإنجازات) عشان ما تصير حلقة.

### ٦.٤ الإنجازات
تقريباً ٥٠ في `AchievementCatalog`، و**معرّفاتها النصية ثابتة** (`tasks.100`، `streak.30`، `run.7`،
`level.10`، `hidden.comeback`، `bigday.5`، `early.1`، `night.10`، `page.1`، `sessions.50`…). الشروط:
مجموع المهمات، والأيام المكتملة، وأفضل ستريك، والأيام المكتملة المتتالية، والمستوى الأساسي، والعودة (تكمل يوم
بعد ٣ أيام غياب أو أكثر)، والمهمات الفرعية، واليوم الحافل، والطير المبكر (تخلص قبل الظهر)، وختامها مسك (تخلص
بعد العشاء)، وعدد الصفحات، وعدد الجلسات. المخفية تظهر "؟؟؟" لين تنفتح.

### ٦.٥ الجوائز والمتجر
- **الجوائز** يحددها المستخدم. الجائزة تنفتح بمستوى أو ستريك أو عدد مهمات أو أيام مكتملة أو إنجاز، أو تكون
  بنقاط (تنخصم عند الاستلام). الحالات: مقفلة، مفتوحة، مستلمة.
- **المتجر** تجميلي فقط. الفئات: ثيم (١٠)، إطار (٧)، مؤثر (٦)، شكل الشريط (٥)، أيقونة (١١). كل عنصر له سعر
  ومستوى مطلوب. والعناصر المجهزة تنحفظ في `SettingsKey.equipped*`.

### ٦.٦ أوقات الصلاة
`AdhanPrayerTimes` يستخدم أم القرى والعصر على المذهب الشافعي، ويحسب الفجر والظهر والعصر والمغرب والعشاء.
الموقع يجي من GPS (مرة وحدة)، أو قائمة ٢٠ مدينة سعودية، أو إحداثيات يدوية. بدون موقع، العناصر المرتبطة بالصلاة
تعرض وصفها بدل الوقت وما تنجدول.

### ٦.٧ التنبيهات
- حقول `AlarmRule`: `title`، `note`، `isEnabled`، `repetition`، `time` (`.clock` أو `.prayer` مع
  قبل/بعد وساعات ودقائق)، `extraPrayers`، `endDay` (شامل)، `isMainTask`، `linkedPageID`، `delivery` (منبه
  أو إشعار فقط)، `challenge`، `stopDestination`.
- **التخطيط** (`NotificationPlanner.plan`) يغطي **١٤ يوم** قدام. يبدأ من يوم قبل لأن "بعد العشاء" ممكن
  يعدّي منتصف الليل. النتائج مرتبة ومحدودة العدد (٦٠ لـ AlarmKit و٤٠ للإشعارات؛ iOS يسمح بـ ٦٤ معلّق).
  والمعرفات ثابتة: `alarm.<uuid>.<yyyyMMddHHmm>`.
- **AlarmScheduler** يجدول منبهات AlarmKit لمرة وحدة بموعد ثابت `.fixed(date)`:
  - معرفاتها **UUID ثابتة مشتقة من SHA-256** (المعرف + البصمة)، فإعادة التخطيط مجرد مقارنة رخيصة.
  - يلغي المجدول القديم، وما يلمس اللي ترن أو المؤجلة أو الموقوفة (إلا اليتيمة).
  - يعطي أولوية لأول ٤٨ ساعة ولسلاسل التحدي، ويشيل البعيدة إذا وصل `maximumLimitReached`.
  - يرجع لمنبه عادي لو النظام رفض إعداد التحدي.
  - التأجيل ١٠ دقائق (وما فيه تأجيل في منبهات التحدي).
  - يكتب `AlarmScheduleReport` اللي يظهر في **الإعدادات ← فحص النظام**.
- **AlarmNotifier** يتعامل مع تنبيهات الإشعار فقط، ومعرفات طلباتها تبدأ بـ `com.ghazaly.habits.alarmnote.`.
- التنبيه اللي لمرة وحدة يطفي نفسه بعد ما يرن.
- إعادة التخطيط تصير عند التشغيل، والرجوع للتطبيق، وتغير اليوم، وأي تغيير مهم، والتحديث الخلفي (تقريباً كل ٦
  ساعات، والوقت الفعلي يحدده iOS).

### ٦.٨ منبهات التحدي
| النوع | المدى | ملاحظات |
|---|---|---|
| `math` معادلات | ١–١٠ أسئلة؛ سهل/متوسط/صعب | جمع وطرح، والناتج ما يكون سالب |
| `steps` خطوات | ١٠–٢٠٠٠ | `CMPedometer` |
| `typing` كتابة | — | جمل عربية؛ يتجاهل التشكيل والتطويل والمسافات الزايدة |
| `shake` هز | ١٠–٢٠٠ | مقياس التسارع |
| `memory` حفظ | ٣–١٠ أرقام | ما يبدأ بصفر |

زر الإيقاف حق النظام ما ينقدر يُمنع. بدال كذا، كل وحدة من **الرنتين** الجاية لها **سلسلة من ١٠ منبهات إضافية،
وحدة كل دقيقة**. `ChallengeLedger` (JSON في UserDefaults) يتابع الرنات المعلقة والمكتملة، وإكمال التحدي يلغي
باقي السلسلة. `ChallengeView` شاشة كاملة ما تنقفل لين يخلص التحدي أو تنتهي النافذة (١٠ + ٢ دقائق). والجهاز
اللي ما يدعم الخطوات أو الهز يتحول لمعادلات.

`StopDestination` يكون:
- `.link` رابط: https، أو روابط التطبيقات، أو mailto، أو tel. ممنوع `javascript` و`file` و`data`
  و`vbscript`. والدومين اللي بدون بروتوكول ينضاف له `https://`.
- `.shortcut` اختصار: يفتح `shortcuts://run-shortcut?name=…`.

### ٦.٩ الصفحات الخاصة
- **`PageDefinition`** (محفوظ JSON) فيه: `name`، `emoji`، `accent`، `tabs` (كل تبويب فيه قائمة `Block`)،
  `rotatesTabs` (الجلسات المجدولة تدور أ ← ب ← ج)، `schedule` (نفس محرر التنبيهات؛ يسوي تنبيه مرتبط، ولو
  `isMainTask` مفعّل يسوي مهمة رئيسية مرتبطة)، `pinnedToHome`، `anchorDay`.
- **`Block` struct واحد مرن.** كل حقل له قيمة افتراضية في فك الترميز، فالصفحات القديمة دايماً تنفتح. أضف الحقول
  الجديدة بقيم افتراضية، وارفع `pageSchemaVersion` بس للتغييرات اللي تكسر التوافق.
- **٢١ نوع قطعة:**
  - **تنسيق:** عنوان، نص، فاصل، مربع (يحتوي قطع ثانية)، صورة، رابط.
  - **إدخال:** مربع كتابة، رقم، جدول مجموعات، عداد، مربع اختيار، قائمة تحقق، اختيار، تقييم، تاريخ ووقت.
  - **وقت:** مؤقت (يرسل إشعار محلي لما يخلص)، ساعة إيقاف.
  - **عرض:** شريط تقدم (يقدر يجمع أكثر من مصدر)، رسم بياني (`value`، `setsMax`، `setsVolume`،
    `setsTotal`)، سجل.
  - **إجراء:** زر (`finishSession`، `completeTask`، `startTimer`، `openPage`، `openAlarm`،
    `addSecondaryTask`، `clearFields`).
- **`PageSession`** يحفظ القيم بمفتاح معرف القطعة. فيه تلميحات "آخر مرة"، والجلسة اللي ما انلمست ما تنحفظ،
  و**إنهاء الجلسة** يكمل المهمة الرئيسية المرتبطة بالصفحة لليوم.
- للصفحة وضعين: **استخدام** (`PageUseView`) و**تعديل** (`PageEditView`). وعمليات الشجرة الصافية في
  `PageTree.swift`.
- **القوالب:** تمارين (تدوير Full Body A/B/C)، وقراءة، وماء، ومذاكرة، وقوالب المستخدم.

### ٦.١٠ الويدجت والعرض الحي
- التطبيق يكتب `WidgetSnapshot` في حاوية App Group. و`AppGroup.identifier` يفضّل مفتاح `ALTAppGroups` في
  Info.plist، لأن أدوات التثبيت الجانبي ممكن تغيّر اسم المجموعة.
- العرض الحي فيه جزء لكل مهمة رئيسية، والمهمة التالية ووقتها، والنسبة، ورابط لفتح التطبيق. **ما فيه أزرار
  إكمال**. يبدأ تلقائياً، ويتجدد (العرض يعيش تقريباً ٨ ساعات، وينجدول إشعار تذكير)، وفيه خيار "إيقاف لليوم".
- أحجام الويدجت: صغير، ومتوسط، ودائري ومستطيل وسطر لشاشة القفل. و`HabitAlarmActivity` مطلوب من AlarmKit عشان
  يعرض المنبهات المؤجلة.
- معرف الثيم المجهز ينسخ لإعدادات App Group عشان الويدجت تطابق التطبيق.

### ٦.١١ النسخ الاحتياطي
- `BackupDocument` يستخدم **الإصدار ١**، وتواريخ ISO-8601، ومفاتيح مرتبة. فيه كل أنواع السجلات، والإعدادات
  المذكورة في `BackupService.settingKeys`، وصور الصفحات.
- فك الترميز يرفض الإصدارات الأحدث ويتأكد إن المعرفات ما تتكرر. والاسترجاع **يستبدل كل شي**.
- **نسخ تلقائية أسبوعية** تنحفظ في `Documents/Backups` (`habits-backup-YYYY-MM-DD.json`). ينحفظ آخر ٤،
  وتظهر في تطبيق الملفات.
- ملف صوت المنبه المخصص ما يدخل في النسخة.

### ٦.١٢ أ المؤثرات الصوتية
أربع لحظات لها أصوات: إنجاز مهمة، إنجاز/مستوى جديد، اكتمال اليوم، وشراء من المتجر (`SoundEvent`). كل لحظة لها ٤
أصوات (`App/Resources/Sounds/sfx_<event>_0…3.m4a`). `SoundEffects` يشغلها بترتيب عشوائي عن طريق `ShuffleBag`
(في HabitCore، صافية): الصوت ما يرجع إلا بعد ما تخلص الثلاثة الثانية، والحالة تنحفظ في `UserDefaults` بين مرات
التشغيل. و`AppRouter.celebrate` يختار صوت واحد لكل إنجاز (اكتمال اليوم أقوى من الإنجاز، والإنجاز أقوى من إنجاز
المهمة). الصوت بفئة playback مع `mixWithOthers`: يشتغل حتى على الصامت، ويتبع مستوى صوت الجوال، وما يوقف
موسيقاك. ومفتاح في الإعدادات (`SettingsKey.soundEffectsEnabled`، مفعّل
افتراضياً) يطفيها.

### ٦.١٢ مفاتيح الإعدادات
كلها في `SettingsKey` (`App/Design/AppRoot.swift`، وفيه امتداد في `BackupService.swift`): المظهر، ونمط
الأرقام، وساعة بداية اليوم، وموقع الصلاة، وعناصر المتجر المجهزة، وخيارات العرض الحي، وتذكير الصباح، وصوت المنبه
(ملف صوتي مستورد يتحول لـ `.caf` في `Library/Sounds`، أقصاه ٢٩ ثانية)، و`taskShowAllTimes`،
و`taskFollowsNextRing`، والنسخ التلقائي، ووقت آخر نسخة، وتذكير التوقيع.

## ٧. نظام التصميم
- **الشكل:** أبيض ودرجات أخضر (أسود وأخضر في الوضع الداكن)، و**هيدر مقوس**، و**شريط سفلي مقوس** فيه زر
  **رئيسية** دائري بارز (شوف `docs/design/layout-reference.png`). ترتيب التبويبات من اليمين لليسار: المهمات ·
  التنبيهات · (الرئيسية) · الإنجازات · صفحاتي.
- **الألوان:** استخدم رموز `Theme` بس (`primary`، `primaryStrong`، `barMuted`، `surface`، `card`،
  `textPrimary`، `textSecondary`، `danger`، `gold`)، ولا تستخدم ألوان مباشرة أبداً. `gold` محجوز للإنجازات
  والمستويات والجوائز. والرموز تتكيّف مع الفاتح والداكن ومع ثيم المتجر المجهز.
- **المعدّل الجذري:** `.appRoot()` يضبط RTL، و`ar_SA`، ونمط الأرقام، والمظهر، واللون، و`.id(theme)` عشان
  الواجهة تنبني من جديد لما يتغير الثيم. **طبّقه على كل sheet و fullScreenCover.**
- **الاتجاه:** الأشياء اللي ما لازم تنعكس (إزاحة الصفحات وقوس الشريط) تنحط داخل حاوية LTR صريحة.
- **الأرقام:** اعرضها عن طريق بيئة نمط الأرقام (`digits.format(…)` و`NumberFormatting`)، وحط علامة LTR
  (`\u{200E}`) قبل المعادلات.
- **الوصولية:** الحالة ما تنعرف باللون بس (علامة صح + شطب، وأشكال مختلفة)، والهيدر يكبر مع حجم الخط، و"تقليل
  الحركة" يعطي تلاشي، والتسميات بالعربي، وفيه اهتزاز عند النجاح. والإرشادات تتبع Apple HIG.
- **قطع جاهزة تقدر تعيد استخدامها:** `CurvedPage`، `CurvedHeader`، `HeaderButton`، `ChoiceChip`،
  `SegmentBar`، `ProgressRing`، `Metrics`، ودوال `Motion`.

## ٨. البناء والتوزيع
`.github/workflows/build.yml` يشتغل عند الدفع على `main`، وعند وسوم `v*`، وعند التشغيل اليدوي:
١. يختار أحدث Xcode 26 ويثبت `xcodegen` و`ldid`.
٢. **يشغّل اختبارات HabitCore**. لو فشل اختبار يوقف البناء.
٣. يشغّل `xcodegen generate` و`xcodebuild` (Release، `generic/platform=iOS`، والتوقيع مطفي). ورقم البناء =
   رقم التشغيل.
٤. يشغّل `ldid -S` مع الصلاحيات (الإضافة أول ثم التطبيق). **يفشل لو App Group ما انضاف.**
٥. يحزم `Payload/Habits.app` في `Habits.ipa` ويرفعه كـ artifact.
٦. مع وسوم `v*`: يرفق الـ IPA في الإصدار.
٧. على `main`: ينشر إصدار `build-<n>` (كأحدث إصدار) ويحدّث `source.json` في إصدار `altstore-source`، عشان
   **AltStore** دايماً يعرض آخر نسخة.

توقيع الحساب المجاني ينتهي بعد ٧ أيام. التطبيق يقرأ `embedded.mobileprovision` ويجدول تذكير قبل الانتهاء بيوم.

## ٩. وصفات التوسعة

**إضافة خاصية في SwiftData**
١. أضفها **بقيمة افتراضية** (`var x: Int = 0`) عشان الترحيل الخفيف يشتغل.
٢. إذا لازم تنحفظ في النسخ الاحتياطي، أضفها للـ struct المناسب من `Backup*` في `BackupDocument.swift` (كاختيارية)،
   ولـ `BackupService.makeDocument` و`BackupService.restore`.
٣. إذا تأثر على الرنين، أضفها لـ `AlarmRecord.fingerprint`.

**إضافة إنجاز**
١. أضف `AchievementDef` لـ `AchievementCatalog.all` **بمعرف جديد وفريد**. لا تغيّر اسم معرف ولا تعيد استخدامه.
٢. إذا يحتاج إحصائية جديدة: أضف حالة لـ `AchievementCondition`، وحقل لـ `AchievementStats`، واحسبها في
   `ProgressSnapshot`، وتعامل معها في `AchievementEvaluator.progress`.
٣. أضف اختبارات.

**إضافة عنصر للمتجر**
١. أضف `ShopItem` لـ `ShopCatalog.all`.
٢. ثيم: أضف ألوانه في `ThemePalette.palette(for:)`.
٣. إطار أو مؤثر أو شكل شريط: تعامل مع المعرف في `FrameBorder` أو `ConfettiView` أو `SegmentBar`.
٤. أيقونة: أضف `IconXxx.appiconset`، وأضف الاسم لـ `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` في
   `project.yml`، وأضف معاينة في `ShopSection`.

**إضافة نوع قطعة للصفحات**
١. أضف حالة لـ `BlockKind` مع `arabicName` و`symbol` والأعلام (`isInput`، `isChartable`، `isNumeric`)
   والفئة.
٢. أضف قيمها الافتراضية في `Block.make`. وأي حقل جديد في `Block` لازم يكون له **قيمة افتراضية في فك الترميز**.
٣. اعرضها في `BlockUseView`، وأعدّها في `BlockConfigView`، ووصّف قيمتها في `PageValueText`.
٤. إذا تخزن قيمة، وسّع `BlockValue` (و`PageLogic.metricValue` إذا تنرسم). وأضف اختبارات في `PagesTests`.

**إضافة نوع تحدي**
١. أضف حالة لـ `ChallengeKind` ومداها أو حقولها لـ `AlarmChallenge` (محصورة، وتنفك بقيم افتراضية). وحط منطق
   التوليد والتحقق في HabitCore مع اختبارات.
٢. أضف اسمها وإعداداتها في `ChallengeSection`، وشاشتها في `ChallengeView`. وإذا الجهاز ممكن ما يدعمها خلها
   تتحول لمعادلات.

**إضافة إعداد**
١. أضف مفتاح لـ `SettingsKey` واقرأه بـ `@AppStorage`.
٢. أضفه لـ `BackupService.settingKeys` إذا لازم يدخل في النسخة.
٣. إذا يغيّر اللي تعرضه الويدجت أو المنبهات، أضفه لـ `widgetKey` أو `replanKey` في `RootView`.

**تغيير قاعدة (ستريك، خبرة…)**
عدّلها في HabitCore وحدّث الاختبارات أو أضف جديدة. ولأن كل شي يُشتق، القاعدة الجديدة تنطبق على كل التاريخ مرة
وحدة. تأكد إن هذا اللي تبيه.

## ١٠. القواعد والاتفاقيات
١. **المنطق مكانه HabitCore ومعه اختبارات.** خل الواجهات خفيفة، ومرّر `now` والتقويم.
٢. **لا تخزن أرقام مشتقة** (الخبرة، النقاط، الستريك، المستوى).
٣. **لا تغيّر التاريخ.** استخدم `endDay` بدل حذف المهمات اللي لها إنجازات.
٤. **حافظ على توافق البيانات:** قيم افتراضية لخصائص SwiftData الجديدة، و`decodeIfPresent` مع قيم افتراضية
   لحقول Codable الجديدة، وخل قيم الـ enum والمعرفات ثابتة. ارفع `BackupDocument.currentVersion` بس إذا
   التغيير يكسر النسخ الاحتياطية.
٥. **أي شي يأثر على الرنين لازم يغيّر بصمة التنبيه**، عشان يصير إعادة تخطيط.
٦. **احترم حدود النظام:** ٦٤ إشعار معلّق، والحد الأقصى لـ AlarmKit. خطط مواعيد فعلية في نافذة متجددة.
٧. **الكتابة عن طريق `*Actions`**، ونادِ `try? context.save()`، وأرسل `.achievementsNeedSync` لما شي خارج
   المهمات ممكن يفتح إنجاز.
٨. **اللغة:** نصوص الواجهة بالعربي (لهجة سعودية عامية)، وتنكتب بـ `Text("…")` أو `String(localized:)`. ملف
   `Localizable.xcstrings` لغته الأساسية عربي. والكود والتعليقات ورسائل الـ commit بالإنجليزي.
٩. **إضافة الويدجت ما تستورد HabitCore.** حط الكود المشترك في `Shared/` وخل القواعد المنسوخة متطابقة
   (`WidgetSnapshot.nextItem` و`effectiveTime` لازم يطابقون `NextMainTask` و`TodayTaskItem.effectiveTime`).
١٠. **استخدم دايماً `AppGroup.identifier`**، ولا تكتب اسم المجموعة ثابت في الكود.
١١. **مبادئ المنتج:** ما فيه تجميد ستريك، والرئيسية والفرعية نفس الخبرة، والمتجر تجميلي فقط، والعرض الحي بدون
    أزرار إكمال، والبيانات تظل على الجهاز.
١٢. **الفروع والـ PR:** `feature/…` و`fix/…`، وخل الـ commits مركزة.

## ١١. وين أعدّل وش
| أبي أعدّل… | المكان |
|---|---|
| قواعد الستريك | `HabitCore/Streak/StreakEngine.swift` |
| الخبرة والنقاط ومنحنى المستويات | `HabitCore/Progress/ProgressCalculator.swift` |
| الإنجازات | `HabitCore/Achievements/Achievements.swift` |
| عناصر المتجر | `HabitCore/Shop/ShopCatalog.swift`، `Shared/Theme.swift`، `Features/Progress/ShopSection.swift` |
| حساب مواعيد التنبيهات | `HabitCore/Alarms/NotificationPlanner.swift` |
| التعامل مع AlarmKit | `App/Services/AlarmScheduler.swift` |
| تنبيهات الإشعار فقط | `App/Services/AlarmNotifier.swift` |
| قفل التطبيقات (لين تخلص مهمة) | `HabitCore/Tasks/AppBlock.swift`، `App/Persistence/AppBlockService.swift`، `App/Services/BlockStatusIntent.swift`، `Features/AppBlock/AppBlockView.swift`، `RootView` |
| التحديات | `HabitCore/Alarms/AlarmChallenge.swift`، `Features/Alarms/ChallengeSection.swift`، `Features/Challenges/ChallengeView.swift` |
| قطع الصفحات | `HabitCore/Pages/PageSchema.swift`، `Features/Pages/BlockUseView.swift`، `BlockConfigView.swift`، `PageSupport.swift` |
| قوالب الصفحات | `HabitCore/Pages/PageTemplates.swift` |
| الرئيسية | `Features/Home/HomeView.swift`، `CalendarStrip.swift` |
| الويدجت والعرض الحي | `Widgets/*.swift`، `Shared/ProgressVisuals.swift`، `App/Services/LiveActivityController.swift` |
| النسخ الاحتياطي | `HabitCore/Backup/BackupDocument.swift`، `App/Persistence/BackupService.swift` |
| الإعدادات | `Features/Settings/SettingsView.swift`، `App/Design/AppRoot.swift` |
| الهيدر والشريط والأشكال | `App/Design/CurvedPage.swift`، `CurvedShapes.swift`، `Metrics.swift`، `Navigation/CurvedTabBar.swift` |
| البناء والإصدار | `project.yml`، `.github/workflows/build.yml` |

</div>
