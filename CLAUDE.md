# CLAUDE.md — ClockForME ("Habits" / عاداتي)

> This file is for AI assistants (Claude, Copilot, Cursor, etc.) that open this repository.
> It explains the whole app: what it does, how it is built, where every piece lives, the rules
> that must never be broken, and how to build and ship it.
> **Part 1 is in English. Part 2 (below it) is the same content in Arabic.**

---

# PART 1 — ENGLISH

## 1. What the app is

**Habits** (display name in Arabic: **عاداتي**, repository name **ClockForME**) is a **personal iPhone app
for one owner only**. It is not on the App Store. Its job is to help the owner build habits by combining:

- **Tasks** (main and secondary) with daily/weekly/monthly/one-time repetition.
- **Alarms** that really ring (Apple **AlarmKit**, iOS 26) or are notification-only, timed by clock
  **or relative to Islamic prayer times** ("30 minutes after Asr", several prayers at once).
- **Challenge alarms** that only stop after a challenge (math, walking steps, typing a phrase, shaking,
  memorizing digits), and a **stop destination** (open a link / app / Shortcut after stopping).
- **Gamification**: streak, XP, levels with Arabic titles, points, ~50 achievements, a cosmetic **shop**
  (themes, level-card frames, celebration effects, progress-bar styles, alternate app icons), and
  **owner-defined rewards** ("جوائزي").
- **Custom pages** ("صفحاتي"): a block-based page builder (like a mini Notion) for workout logs, reading,
  water, study… with sessions, history, charts, timers, and an optional schedule that creates an alarm and a
  main task.
- **Lock Screen Live Activity**, **Home/Lock Screen widgets**, statistics (heatmap, weekly completion, XP line),
  **backup/restore** to a JSON file, and a reminder before the free sideloading signature expires.

**Language & culture:** the UI is **Arabic only, right-to-left**, written in a casual **Saudi dialect**
(e.g. "ما عندك مهمات", "وش تبي نسوي"). Locale is `ar_SA`, Gregorian calendar with week starting **Sunday**,
Hijri (Umm al-Qura) date shown on Home. Text fields must still accept English input. Digits can be shown as
Western (123) or Arabic-Indic (١٢٣) — a user setting.

**Owner constraints (very important for every decision):**
- The owner has **no Mac** and **does not pay** for the Apple Developer Program.
- So the app is **built in the cloud by GitHub Actions** (macOS runner), produced as an **unsigned IPA**,
  fake-signed with `ldid`, and **sideloaded with AltStore** using a free Apple ID (the signature lasts 7 days).
- The owner's phone runs **iOS 26.x**. Deployment target is **iOS 26.1**.
- No server, no account, no cloud sync. **All data lives on the phone** (SwiftData + UserDefaults).

## 2. Tech stack

| Area | Technology |
|---|---|
| Language | Swift 5 mode (`SWIFT_VERSION: 5.0`), Swift tools 5.9 for the package |
| UI | SwiftUI (Observation `@Observable`, `@Query`, `@AppStorage`) |
| Storage | **SwiftData** (`@Model` records) + `UserDefaults` for settings |
| Alarms | **AlarmKit** (`AlarmManager`, `AlarmAttributes`, `AlarmPresentation`) |
| Notifications | `UserNotifications` (notification-only alarms, morning reminder, timers, renewal reminders) |
| Lock screen | **ActivityKit** Live Activity + **WidgetKit** widgets (extension target) |
| Intents | `AppIntents` (`LiveActivityIntent` for the alarm stop button) |
| Background | `BGTaskScheduler` app refresh (`com.ghazaly.habits.refresh`) |
| Sensors | CoreMotion (`CMPedometer` for steps, `CMMotionManager` accelerometer for shake), CoreLocation (one-shot) |
| Prayer times | [`adhan-swift`](https://github.com/batoulapps/adhan-swift) 1.5.0 — **Umm al-Qura** method, **Shafi'i** Asr |
| Project gen | **XcodeGen** (`project.yml`) — the `.xcodeproj` is NOT committed |
| CI / delivery | GitHub Actions on `macos-26`, `ldid`, GitHub Releases, AltStore source JSON |
| Tests | XCTest, ~167 unit tests on the pure `HabitCore` package |

## 3. Repository layout

```
ClockForME/
├── project.yml                 # XcodeGen spec: targets Habits (app) + HabitsWidgets (extension)
├── .github/workflows/build.yml # Cloud build → IPA → Release → AltStore source
├── .gitignore                  # ignores *.xcodeproj, build/, *.ipa, Config/*.entitlements, Config/*-Info.plist
├── docs/design/layout-reference.png   # The owner's layout reference: curved green header, curved bottom bar, round Home button
├── Packages/HabitCore/         # PURE logic Swift package (no UI, no SwiftData) + all unit tests
│   ├── Package.swift           # depends on adhan-swift; platforms iOS 17 / macOS 13 (tests run on macOS)
│   ├── Sources/HabitCore/
│   │   ├── Common/             # DayKey, AppearanceMode, DigitStyle + NumberFormatting, SignatureMath
│   │   ├── Tasks/              # TaskKind, TaskSpec, DayProgress
│   │   ├── Recurrence/         # Weekday, Repetition (once / weekly / monthly)
│   │   ├── Streak/             # StreakEngine (replays history)
│   │   ├── Progress/           # XP, points, levels, LevelTitle, milestones
│   │   ├── Achievements/       # AchievementCatalog (~50), evaluator, AchievementTiming (before Dhuhr / after Isha)
│   │   ├── Rewards/            # owner-defined reward conditions
│   │   ├── Shop/               # ShopCatalog (cosmetics only)
│   │   ├── Stats/              # HistoryStats, weekly completion, heatmap, XP timeline
│   │   ├── Home/               # Greeting, NextPrayer, Countdown, NextMainTask, TodayTaskItem
│   │   ├── Prayer/             # Prayer, Direction, PrayerTimeProviding, AdhanPrayerTimes
│   │   ├── Alarms/             # AlarmRule, TimeSpec, AlarmDelivery, NotificationPlanner, AlarmChallenge & chain/ledger
│   │   ├── Pages/              # PageSchema (Block, PageDefinition…), PageSession + PageLogic, PageTree, PageTemplates
│   │   └── Backup/             # BackupDocument (versioned JSON), BackupCoding
│   └── Tests/HabitCoreTests/   # one test file per area + TestSupport (fixed prayer times etc.)
├── App/                        # The iOS app target
│   ├── AppMain.swift           # @main HabitsApp: RootView + AppRouter + .appRoot() + modelContainer
│   ├── Navigation/             # RootView (the hub), AppRouter, AppTab, CurvedTabBar
│   ├── Persistence/            # SwiftData models + "Actions" (all writes go through these)
│   ├── Services/               # AlarmScheduler, AlarmNotifier, LiveActivityController, AppDelegate, sounds, icons, location, signature
│   ├── Design/                 # Theme usage, CurvedPage/Header, shapes, Metrics, Motion, ChoiceChip, digit-style env, SettingsKey
│   ├── Features/
│   │   ├── Home/               # HomeView, CalendarStrip
│   │   ├── Tasks/              # TasksView, TaskEditorView, TaskRow, RepetitionText
│   │   ├── Alarms/             # AlarmsView, AlarmEditorView, ChallengeSection, DeliveryPicker, AlarmText
│   │   ├── Challenges/         # ChallengeView (full-screen challenge)
│   │   ├── Pages/              # PagesView, PageDetailView, PageUseView, PageEditView, BlockUseView, BlockConfigView, PageSettingsView, ScheduleFields, PageSupport
│   │   ├── Progress/           # AchievementsView (achievements / rewards / shop), LevelCard, Statistics, Celebrations, Shop, Rewards
│   │   └── Settings/           # SettingsView, PrayerSettingsView, AlarmSoundView, BackupView, AlarmDiagnosticsView
│   └── Resources/              # Localizable.xcstrings (source language ar), InfoPlist.xcstrings, Assets (AppIcon + 10 alternate icons)
├── Shared/                     # Compiled into BOTH app and widget extension
│   ├── AppGroup.swift          # resolves App Group id (reads AltStore's ALTAppGroups first)
│   ├── Theme.swift             # design tokens + shop theme palettes
│   ├── WidgetSnapshot.swift    # JSON the app writes for widgets
│   ├── TodayActivityAttributes.swift  # Live Activity attributes/state
│   ├── AlarmMetadata.swift     # HabitAlarmMetadata for AlarmKit
│   ├── ProgressVisuals.swift   # SegmentBar (shop styles), ProgressRing
│   └── SharedFormat.swift      # digits/time/percent helpers + DeepLink (habits://today, habits://start)
└── Widgets/                    # Widget extension: TodayWidget, TodayLiveActivity, HabitAlarmActivity, bundle
```

> There is **no README**. There is no `Config/` folder in git: XcodeGen generates the Info.plists and
> entitlements from `project.yml`.

## 4. Architecture (the most important section)

### 4.1 Three layers
1. **`HabitCore` (pure rules).** Value types and pure functions only: no SwiftUI, no SwiftData, no
   `UserDefaults`, no system frameworks except Foundation (+ Adhan). Every rule that can be tested lives
   here and **has unit tests**. Time is always passed in (`now`, `calendar`), never read inside.
2. **`App/Persistence` (records + actions).** SwiftData `@Model` classes store data; complex values are
   stored as **JSON `Data`** (e.g. `repetitionData`, `timeData`, `definitionData`) and exposed through
   computed properties that convert to/from HabitCore types (`TaskRecord.spec`, `AlarmRecord.rule`,
   `PageRecord.definition`). **All mutations go through the `*Actions` enums** (`TaskActions`,
   `AlarmActions`, `PageActions`, `AchievementActions`, `BackupService`).
3. **`App/Features` (SwiftUI views).** Read with `@Query` / `@AppStorage`, compute derived state with
   `ProgressSnapshot.make(...)`, and call Actions to write.

### 4.2 "Derived, never stored" — the golden rule
XP, points, level, streak, complete days, statistics… are **never saved**. They are recomputed from history
(`CompletionRecord`s + task specs) every time by `ProgressSnapshot.make`. Consequences:
- Un-completing a task automatically revokes its XP/points (no farming).
- Editing the past stays consistent.
- The only stored "extras": `AchievementUnlockRecord` (an achievement, once earned, is **kept** even if
  history changes), `PurchaseRecord` (spent points), `RewardRecord.claimedCost` (spent points).

**Never add a stored XP/points/streak counter.** Add a rule in HabitCore and derive it.

### 4.3 "Never rewrite the past"
- Deleting a task **that has completions** does not delete it: it sets `endDay = today` (exclusive), so past
  days and the streak stay identical. A task without history is hard-deleted. Both can be undone
  (`DeleteUndo`).
- Changing the schedule (kind/repetition) of a task linked to an alarm or page **that has history** ends
  the old task today and creates a **new** task from today.

### 4.4 The day
`DayKey` (year/month/day) is the unit of history. A **day-start hour** setting (`dayStartHour`, 0–23)
lets late-night work count for the previous day. Always use `Calendar.app` (Gregorian, firstWeekday =
Sunday, current time zone) and `DayKey(date:calendar:dayStartHour:)`.

### 4.5 RootView = the hub
`RootView` hosts the 5 tabs as side-by-side pages (all alive, swipe from screen edges, cross-fade with Reduce
Motion), one **shared morphing curved header** (pages publish `HeaderConfig` via a preference key), the
`CurvedTabBar`, sheets (settings, level-up, achievement unlock), the day-complete overlay, the full-screen
challenge, and these background jobs:
- `.task(id: replanKey)` → `AlarmActions.replan` whenever alarm fingerprints, location, sound or day change.
- `.task(id: widgetKey)` → rebuild `WidgetSnapshot` + sync the Live Activity.
- Auto backup (weekly), signature reminder, morning reminder, achievement sync, deep links (`habits://`),
  `NSCalendarDayChanged`, scene phase changes, `.achievementsNeedSync` notification.

`AppRouter` (`@Observable`) holds navigation state: `selectedTab`, `showSettings`, `openPageID`,
celebrations (`levelUp`, `unlock`, `showDayComplete`), `alarmStoppedAt`, `activeChallenge`.
`AppEnvironment.shared` owns the `ModelContainer` and the router (also reachable from intents/background).

## 5. Domain rules (exact numbers)

### 5.1 Tasks
- `TaskKind.main`: drives the **streak**, the Live Activity, widgets and "day complete".
- `TaskKind.secondary`: same XP, **no effect on streak**. May have `repetition == nil` = "anytime, until done".
- `Repetition`: `.once(DayKey)`, `.weekly(Set<Weekday>)` (`.daily` = all 7), `.monthly(Set<Int>)`.
  Monthly day that doesn't exist (31 in April) fires on the **last day** of that month.
- Tasks created from an alarm carry its `time` (and extra prayers) so lists can sort by time.
- `TaskRecord.routineEnd` (inclusive, copied from an alarm's end day) ≠ `endDay` (exclusive, "stopped by owner").

### 5.2 Day progress & streak (`StreakEngine`, owner-specified)
- Day 100% complete → streak **+1**, missed run resets.
- Day partial (1–99%) → streak **holds**, missed run resets.
- Day 0% (main tasks existed) → missed run +1; after **3** grace days in a row, streak **−1 per further missed day** (never < 0).
- Day with no main tasks → neutral.
- Today only counts when complete; it is never "missed" before it ends.
- **No streak freeze / skip exists, by design.** Do not add one.

### 5.3 XP, points, levels (`ProgressRules`)
- Task: **10 XP, 1 point**. Complete day: **20 XP, 3 points**.
- Best-streak milestones: 7d (50 XP/5 pts), 14 (100/10), 30 (200/20), 60 (300/30), 100 (500/50), 200 (800/80), 365 (1500/150).
- XP to go from level L to L+1 = **100 + 25 × (L − 1)**.
- Titles: مبتدئ 1–4, مثابر 5–9, منضبط 10–19, متقن 20–34, قدوة 35–49, أسطورة 50+.
- Final summary = base (history) + achievement bonuses − spent points. Achievements are judged on the
  **base level** (without achievement XP) to avoid a loop.

### 5.4 Achievements (`AchievementCatalog`)
~50 definitions with stable string ids (e.g. `tasks.100`, `streak.30`, `run.7`, `level.10`, `hidden.comeback`,
`bigday.5`, `early.1`, `night.10`, `page.1`, `sessions.50`). Conditions: total tasks, complete days, best
streak, consecutive complete run, base level, comebacks (complete a day after ≥3 missed), secondary tasks,
big day (N main tasks in one complete day), early bird (last main task before **Dhuhr**), night finisher
(after **Isha**), pages created, page sessions. Hidden ones show "؟؟؟" until unlocked. **Never change an
existing id** (stored in unlock records and backups).

### 5.5 Rewards ("جوائزي") and shop
- Owner creates rewards with a condition: level, streak, tasks, perfect days, achievement, or **pay points**
  (deducted on claim). States: locked / unlocked / claimed.
- Shop (`ShopCatalog`): **cosmetic only** — nothing may affect streak or XP. Categories: theme (10),
  frame (7), effect (6), liveStyle (5), appIcon (11). Each item has price + required level. Ids like
  `theme.ocean`, `icon.gold`. Equipped items are stored in `SettingsKey.equipped*`.
- Theme palettes live in `Shared/Theme.swift` (`ThemePalette.palette(for:)`) and must match the catalog ids.
  Alternate icon asset names are `Icon` + capitalized suffix (`icon.night` → `IconNight`) and must also be
  listed in `project.yml` `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.

### 5.6 Prayer times
- `AdhanPrayerTimes(latitude:longitude:)` — Umm al-Qura + Shafi'i. Five prayers: fajr, dhuhr, asr, maghrib, isha.
- Location: GPS **once** (`LocationService`), or a list of 20 Saudi cities (`SaudiCity.all`), or manual
  coordinates. Stored in UserDefaults (`prayerLatitude`, …). Without a location, prayer-based items show
  their wording ("بعد العصر بـ 10 دقائق") instead of a time and are not scheduled.

### 5.7 Alarms
- `AlarmRule` (pure) ⇄ `AlarmRecord` (SwiftData). Fields: title, note, enabled, repetition, `TimeSpec`
  (`.clock(h,m)` or `.prayer(prayer, before/after, hours, minutes)`), `extraPrayers` (same offset for several
  prayers), `endDay` (inclusive), `isMainTask`, `linkedPageID`, `delivery` (`.alarm` | `.notification`),
  `challenge`, `stopDestination`.
- **Main-task alarm**: `AlarmActions.syncLinkedTask` keeps one linked main task in step. Deleting the alarm
  deletes its task (history-safe) and vice-versa, with undo.
- **Planning**: `NotificationPlanner.plan` builds concrete fire dates for the next **14 days** (starting one
  day early, because "after Isha" can cross midnight), sorted, capped (60 for AlarmKit, 40 for notifications;
  iOS allows 64 pending notifications). Identifiers are stable: `alarm.<uuid>.<yyyyMMddHHmm>`.
- **AlarmScheduler** (AlarmKit): one-time `.fixed(date)` alarms; AlarmKit ids are **SHA-256-derived stable
  UUIDs** from identifier + fingerprint, so replanning is a cheap diff. It cancels stale scheduled alarms,
  never touches ringing/snoozed/paused ones (except orphans), prioritizes the next 48h and challenge chains,
  evicts far-away alarms when `maximumLimitReached`, and falls back to a classic alarm if a challenge
  configuration is refused. Snooze = 10 min (none for challenge alarms). Writes an `AlarmScheduleReport`
  shown in Settings → diagnostics.
- **AlarmNotifier**: notification-only alarms as `UNTimeIntervalNotificationTrigger`s with prefix
  `com.ghazaly.habits.alarmnote.`; tapping opens Tasks / the page / Alarms.
- One-time alarms switch themselves off after ringing (`expireFinished`).
- Replanning happens on launch, foreground, day change, any alarm/location/sound change, and in background
  refresh (~every 6h, iOS decides).
- Stop button → `OpenHabitsIntent` (LiveActivityIntent, opens app) → router goes to Tasks / page / Alarms and
  sets `alarmStoppedAt` → RootView checks for a pending challenge/destination.

### 5.8 Challenge alarms
- Kinds: `math` (easy/medium/hard, 1–10 questions, add/subtract, never negative), `steps` (10–2000,
  `CMPedometer`), `typing` (Arabic phrases; diacritics/tatweel/extra spaces ignored), `shake` (10–200),
  `memory` (3–10 digits, never starting with 0). All values are clamped.
- Because the system stop button can't be blocked, a **chain** of 10 extra alarms (one per minute) is
  scheduled after each of the next **2** rings; the `ChallengeLedger` (UserDefaults JSON) tracks pending and
  completed rings. Completing the challenge cancels the rest of the chain. Window = 10 min + 2 min.
- `ChallengeView` is a full-screen cover that **cannot be dismissed** until done (or the window ends). If
  steps/shake aren't available on the device, it falls back to math.
- `StopDestination`: `.link` (https, app schemes, mailto, tel; `javascript/file/data/vbscript` blocked; bare
  domains get `https://`) or `.shortcut` (`shortcuts://run-shortcut?name=…`). Opened after the challenge.

### 5.9 Custom pages ("صفحاتي")
- `PageDefinition` (JSON in `PageRecord.definitionData`): name, emoji, accent, **tabs** (each a list of
  `Block`s), `rotatesTabs` (scheduled sessions cycle A→B→C), optional `PageSchedule` (same editor as alarms
  → creates a linked alarm and, if `isMainTask`, a linked main task), `pinnedToHome`, `anchorDay`.
- `Block` is **one flexible struct** with a `kind` and many optional fields, each with a default in the
  decoder, so old saved pages always decode. **Keep it that way** (add fields with defaults; bump
  `pageSchemaVersion` only for breaking changes).
- 21 block kinds: heading, text, container (nests children), textField, number, sets (weight × reps table),
  counter, checkbox, checklist, choice, rating, dateTime, timer (local notification when done), stopwatch,
  progress (can sum several sources), chart (metrics: value, setsMax, setsVolume, setsTotal), history,
  divider, image (JPEG in Documents, included in backups), link (web or page), button (finishSession,
  completeTask, startTimer, openPage, openAlarm, addSecondaryTask, clearFields).
- `PageSession`: values typed in one use, keyed by block id string; "last time" hints; untouched sessions
  aren't saved; **finish session** completes the linked main task for today.
- Modes: **use** (`PageUseView`) and **edit** (`PageEditView`: add/configure/reorder/duplicate/move into
  containers/delete with undo). Pure tree editing is in `PageTree.swift` (`[Block]` extensions).
- Templates: built-in **workout** (Full Body A/B/C rotation), **reading**, **water**, **study**; plus the
  owner's saved templates (`PageRecord.isTemplate`).

### 5.10 Live Activity & widgets
- The app writes `WidgetSnapshot` JSON to the **App Group** container (`group.com.ghazaly.habits`, resolved
  by `AppGroup` which prefers AltStore's `ALTAppGroups` Info.plist key) and reloads timelines.
- Live Activity (`TodayActivityAttributes`): one segment per main task, next task + time, %, an "open app"
  link (**no complete buttons**, by owner's choice). Auto-starts, renewed (~7h; a reminder notification asks
  to open the app since activities last ~8h), "stop for today" option.
- `TodayWidget`: small, medium, accessoryCircular/Rectangular/Inline. `HabitAlarmActivity` is required by
  AlarmKit for snoozed alarms.
- The widget extension **does not link HabitCore**: logic it needs is duplicated in `Shared/` (keep
  `WidgetSnapshot.nextItem/effectiveTime` in sync with `NextMainTask` / `TodayTaskItem.effectiveTime`).
- Theme id is mirrored to App Group defaults so widgets use the equipped theme.

### 5.11 Backup
- `BackupDocument` (schema **v1**, ISO-8601 dates, sorted keys) contains every record type, selected
  settings (`BackupService.settingKeys`), and page images. Decoding refuses newer versions and validates
  unique ids. Restore **replaces everything**. Export/import via file exporter/importer; **weekly automatic
  copies** in `Documents/Backups` (`habits-backup-yyyy-MM-dd.json`, newest 4 kept, visible in Files because
  `UIFileSharingEnabled`). "Reset all data" exists. The alarm sound file is not backed up.

### 5.12 Settings (UserDefaults keys in `SettingsKey`)
appearance (system/light/dark), digitStyle, dayStartHour, prayer location keys, equipped shop items,
liveActivityEnabled/AutoStart, morning reminder (enabled/hour/minute), alarmSound (imported audio converted
to `.caf` in `Library/Sounds`, max 29 s), taskShowAllTimes, taskFollowsNextRing, autoBackupEnabled,
lastBackupAt, signatureReminderEnabled. Signature expiry is read from `embedded.mobileprovision`; a reminder
fires one day before ("جدّد التطبيق من AltStore").

## 6. Design system
- Look: white + greens (black + green in dark), **curved green header** with an arc, **curved bottom bar**
  with a raised round **Home** button in the center (see `docs/design/layout-reference.png`). Tab order
  right→left: المهمات · التنبيهات · (الرئيسية) · الإنجازات · صفحاتي. A "liquid" green blob follows the selected tab.
- **Use only `Theme` tokens** (`primary`, `primaryStrong`, `barMuted`, `surface`, `card`, `textPrimary`,
  `textSecondary`, `danger`, `gold`) — never raw colors. Gold is for achievements/levels/rewards only.
- Everything goes through `.appRoot()` (RTL, `ar_SA`, digit style, color scheme, tint, `.id(theme)` to
  rebuild on theme change). **Apply `.appRoot()` to every sheet/fullScreenCover.**
- Geometry that must not mirror (pager offsets, the bar) is laid out in an explicit LTR container.
- Accessibility rules followed throughout: state never by color alone (check + strikethrough, shapes),
  Dynamic Type friendly header, Reduce Motion → cross-fades, accessibility labels/hints in Arabic,
  haptics on success. Design basis: Apple HIG.
- Show numbers through the digit-style environment (`digits.format(...)` / `NumberFormatting`), and LTR-mark
  math expressions (`\u{200E}`).

## 7. Build, test, ship
```bash
# Unit tests (macOS, Swift toolchain) — the only thing that runs without Xcode/iOS:
swift test --package-path Packages/HabitCore

# On a Mac with Xcode 26:
brew install xcodegen
xcodegen generate            # creates Habits.xcodeproj from project.yml
open Habits.xcodeproj
```
CI (`.github/workflows/build.yml`, on push to `main`, tags `v*`, or manual):
1. Select newest Xcode 26 → install xcodegen + ldid → **run HabitCore tests** → generate project.
2. `xcodebuild` Release for `generic/platform=iOS` with code signing **disabled**; build number = run number.
3. `ldid -S` the extension then the app with their entitlements; **fail if the App Group is missing**.
4. Zip `Payload/Habits.app` → `Habits.ipa`; upload artifact.
5. On `main`: publish Release `build-<n>` (latest) and update the `altstore-source` release's `source.json`
   so AltStore always offers the newest build.

Bundle ids: app `com.ghazaly.habits`, widgets `com.ghazaly.habits.widgets`, URL scheme `habits`.
Info.plist usage strings (Arabic) exist for AlarmKit, location (when in use) and motion.

## 8. Rules for AI contributors
1. **Put logic in HabitCore with tests**; keep views thin. Pass `now`/`calendar` in; no hidden clocks.
2. **Don't store derived numbers** (XP, points, streak, level). Derive them.
3. **Never rewrite history**: use `endDay` instead of deleting tasks with completions.
4. **Backward-compatible data**: new SwiftData properties need default values (lightweight migration);
   new Codable fields use `decodeIfPresent` with a default; keep enum raw values and ids stable. If a backup
   shape breaks, bump `BackupDocument.currentVersion`; add new fields to backup export **and** restore.
5. Any change that affects ringing must change the alarm **fingerprint** so `replanKey` triggers a replan.
6. Respect system limits (64 pending notifications, AlarmKit max) — plan concrete dates in a rolling window.
7. Writes go through the `*Actions` enums; call `try? context.save()`; post `.achievementsNeedSync` when
   something outside tasks may earn an achievement.
8. UI text: **Arabic, Saudi casual tone**, via `Text("…")` / `String(localized:)` (Localizable.xcstrings is
   Arabic-source). Code, comments and commit messages are in **English**.
9. No paid services, no server, no Apple paid-account features; must keep working when sideloaded with a
   free Apple ID (App Group id may be renamed by AltStore — always use `AppGroup.identifier`).
10. Owner product decisions to respect: no streak freeze; main and secondary tasks give equal XP; Live
    Activity has no complete buttons; shop is cosmetic only; app is single-user and private.
11. The widget extension can't import HabitCore — put shared code in `Shared/` and mirror rules carefully.
12. Keep commits focused; history shows feature commits per "phase" and PR branches like
    `feature/...` / `fix/...`.

## 9. Quick map: "where do I change…?"
| I want to change… | File(s) |
|---|---|
| Streak rules | `HabitCore/Streak/StreakEngine.swift` (+ tests) |
| XP / points / level curve | `HabitCore/Progress/ProgressCalculator.swift` |
| Add an achievement | `HabitCore/Achievements/Achievements.swift` (new id, never reuse) |
| Add a shop item | `HabitCore/Shop/ShopCatalog.swift` + `Shared/Theme.swift` / `ShopSection` / assets / `project.yml` |
| Alarm timing math | `HabitCore/Alarms/NotificationPlanner.swift` |
| Talking to AlarmKit | `App/Services/AlarmScheduler.swift` |
| Notification-only alarms | `App/Services/AlarmNotifier.swift` |
| A new challenge type | `HabitCore/Alarms/AlarmChallenge.swift`, `ChallengeSection.swift`, `ChallengeView.swift` |
| A new page block | `HabitCore/Pages/PageSchema.swift` (`BlockKind`, `Block.make`), `BlockUseView`, `BlockConfigView`, `PageValueText` |
| Home screen cards | `App/Features/Home/HomeView.swift` |
| Live Activity / widget look | `Widgets/*.swift`, `Shared/ProgressVisuals.swift` |
| Backup contents | `HabitCore/Backup/BackupDocument.swift` + `App/Persistence/BackupService.swift` |
| Settings | `App/Features/Settings/SettingsView.swift`, keys in `App/Design/AppRoot.swift` |
| Header / tab bar / shapes | `App/Design/CurvedPage.swift`, `CurvedShapes.swift`, `Metrics.swift`, `Navigation/CurvedTabBar.swift` |

---
---

# الجزء الثاني — العربية

## ١. وش هو التطبيق

**Habits** (اسمه المعروض **عاداتي**، واسم المستودع **ClockForME**) هو **تطبيق آيفون شخصي لمالك واحد فقط**،
وما هو موجود في App Store. هدفه يساعد صاحبه يبني عاداته عن طريق الجمع بين:

- **المهمات** (رئيسية وفرعية) بتكرار يومي/أسبوعي/شهري/مرة واحدة.
- **التنبيهات** اللي ترن فعلاً (عن طريق **AlarmKit** من أبل، iOS 26) أو إشعار فقط، بوقت ساعة عادي
  **أو بالنسبة لأوقات الصلاة** ("بعد العصر بـ 30 دقيقة"، أو على أكثر من صلاة مع بعض).
- **منبهات التحدي** اللي ما توقف إلا بعد ما تحل تحدي (معادلات رياضية، مشي خطوات، كتابة جملة، هز الجوال،
  حفظ أرقام)، و**وجهة بعد الإيقاف** (يفتح رابط / تطبيق / اختصار بعد ما توقف المنبه).
- **التلعيب (Gamification)**: ستريك، خبرة XP، مستويات بألقاب عربية، نقاط، تقريباً ٥٠ إنجاز، **متجر**
  تجميلي (ثيمات، إطارات لبطاقة المستوى، مؤثرات احتفال، أشكال شريط التقدم، أيقونات بديلة للتطبيق)، و
  **جوائز يحددها المالك لنفسه** ("جوائزي").
- **الصفحات الخاصة** ("صفحاتي"): باني صفحات من قطع (مثل نوشن مصغر) لسجل التمارين، القراءة، الماء،
  المذاكرة… فيها جلسات، سجل، رسوم بيانية، مؤقتات، وموعد اختياري يسوي تنبيه ومهمة رئيسية.
- **عرض حي على شاشة القفل (Live Activity)**، **ويدجت** للشاشة الرئيسية وشاشة القفل، إحصائيات (خريطة حرارية،
  نسبة الإنجاز الأسبوعية، خط الخبرة)، **نسخ احتياطي واسترجاع** لملف JSON، وتذكير قبل ما ينتهي توقيع التطبيق المجاني.

**اللغة والثقافة:** الواجهة **عربية فقط ومن اليمين لليسار**، ومكتوبة **بلهجة سعودية عامية**
(مثل "ما عندك مهمات"، "وش تبي نسوي"). اللغة المحلية `ar_SA`، التقويم ميلادي والأسبوع يبدأ **الأحد**،
والتاريخ الهجري (أم القرى) يظهر في الرئيسية. خانات الكتابة لازم تقبل الإنجليزي. الأرقام تنعرض غربية (123)
أو عربية هندية (١٢٣) حسب الإعدادات.

**قيود المالك (مهمة جداً لأي قرار):**
- المالك **ما عنده ماك** و**ما يدفع** اشتراك مطوري أبل.
- عشان كذا التطبيق **ينبني في السحابة عن طريق GitHub Actions** (جهاز macOS)، ويطلع ملف **IPA غير موقّع**،
  يتوقّع توقيع وهمي بـ `ldid`، و**يتثبّت بـ AltStore** بحساب Apple ID مجاني (التوقيع يدوم ٧ أيام).
- جوال المالك على **iOS 26.x**، وأقل إصدار مدعوم **iOS 26.1**.
- ما فيه سيرفر ولا حساب ولا مزامنة سحابية. **كل البيانات على الجوال** (SwiftData + UserDefaults).

## ٢. التقنيات المستخدمة

| المجال | التقنية |
|---|---|
| اللغة | Swift بوضع 5 (`SWIFT_VERSION: 5.0`)، وأدوات Swift 5.9 للحزمة |
| الواجهة | SwiftUI (`@Observable`، `@Query`، `@AppStorage`) |
| التخزين | **SwiftData** (سجلات `@Model`) + `UserDefaults` للإعدادات |
| المنبهات | **AlarmKit** (`AlarmManager`، `AlarmAttributes`، `AlarmPresentation`) |
| الإشعارات | `UserNotifications` (تنبيهات الإشعار فقط، تذكير الصباح، المؤقتات، تذكيرات التجديد) |
| شاشة القفل | **ActivityKit** للعرض الحي + **WidgetKit** للويدجت (هدف إضافة منفصل) |
| الأوامر | `AppIntents` (`LiveActivityIntent` لزر إيقاف المنبه) |
| الخلفية | تحديث خلفي بـ `BGTaskScheduler` (`com.ghazaly.habits.refresh`) |
| الحساسات | CoreMotion (`CMPedometer` للخطوات، ومقياس التسارع للهز)، CoreLocation (مرة واحدة) |
| أوقات الصلاة | مكتبة `adhan-swift` 1.5.0 — طريقة **أم القرى**، والعصر على المذهب **الشافعي** |
| توليد المشروع | **XcodeGen** (`project.yml`) — ملف `.xcodeproj` غير مرفوع في git |
| البناء والتوزيع | GitHub Actions على `macos-26`، `ldid`، GitHub Releases، ملف مصدر لـ AltStore |
| الاختبارات | XCTest، تقريباً ١٦٧ اختبار على حزمة `HabitCore` الصافية |

## ٣. هيكل المستودع

```
ClockForME/
├── project.yml                 # مواصفات XcodeGen: هدف Habits (التطبيق) + HabitsWidgets (الإضافة)
├── .github/workflows/build.yml # بناء سحابي ← IPA ← Release ← مصدر AltStore
├── .gitignore                  # يتجاهل *.xcodeproj و build/ و *.ipa و Config/*.entitlements و Config/*-Info.plist
├── docs/design/layout-reference.png   # مرجع التصميم: هيدر أخضر مقوس، شريط سفلي مقوس، زر رئيسية دائري
├── Packages/HabitCore/         # حزمة المنطق الصافي (بدون واجهة وبدون SwiftData) + كل الاختبارات
│   ├── Sources/HabitCore/
│   │   ├── Common/             # DayKey، المظهر، نمط الأرقام وتنسيقها، حساب انتهاء التوقيع
│   │   ├── Tasks/              # نوع المهمة، TaskSpec، تقدم اليوم DayProgress
│   │   ├── Recurrence/         # أيام الأسبوع، التكرار (مرة / أسبوعي / شهري)
│   │   ├── Streak/             # محرك الستريك (يعيد تشغيل التاريخ)
│   │   ├── Progress/           # الخبرة، النقاط، المستويات، الألقاب، المحطات
│   │   ├── Achievements/       # كتالوج الإنجازات (~٥٠) + المقيّم + توقيت (قبل الظهر / بعد العشاء)
│   │   ├── Rewards/            # شروط جوائز المالك
│   │   ├── Shop/               # كتالوج المتجر (تجميلي فقط)
│   │   ├── Stats/              # إحصائيات التاريخ، الإنجاز الأسبوعي، الخريطة الحرارية، خط الخبرة
│   │   ├── Home/               # التحية، الصلاة الجاية، العد التنازلي، المهمة الرئيسية التالية
│   │   ├── Prayer/             # الصلوات، قبل/بعد، مزود الأوقات، AdhanPrayerTimes
│   │   ├── Alarms/             # AlarmRule، TimeSpec، طريقة التنبيه، مخطط الإشعارات، التحديات والسلسلة والسجل
│   │   ├── Pages/              # مخطط الصفحات (Block، PageDefinition…)، الجلسات ومنطقها، شجرة القطع، القوالب
│   │   └── Backup/             # مستند النسخة الاحتياطية (JSON بإصدار) وترميزه
│   └── Tests/HabitCoreTests/   # ملف اختبار لكل مجال + TestSupport (أوقات صلاة ثابتة وغيرها)
├── App/                        # هدف تطبيق iOS
│   ├── AppMain.swift           # نقطة البداية: RootView + AppRouter + .appRoot() + قاعدة البيانات
│   ├── Navigation/             # RootView (المركز)، AppRouter، AppTab، CurvedTabBar
│   ├── Persistence/            # نماذج SwiftData + ملفات "Actions" (كل الكتابة تمر عليها)
│   ├── Services/               # جدولة المنبهات، الإشعارات، العرض الحي، AppDelegate، الأصوات، الأيقونات، الموقع، التوقيع
│   ├── Design/                 # الهيدر والصفحة المقوسة، الأشكال، المقاسات، الحركة، الشرائح، مفاتيح الإعدادات
│   ├── Features/
│   │   ├── Home/               # الرئيسية + شريط التقويم
│   │   ├── Tasks/              # قائمة المهمات، المحرر، سطر المهمة، نص التكرار
│   │   ├── Alarms/             # قائمة التنبيهات، المحرر، قسم التحدي، اختيار طريقة التنبيه، النصوص
│   │   ├── Challenges/         # شاشة التحدي الكاملة
│   │   ├── Pages/              # قائمة الصفحات، التفاصيل، الاستخدام، التعديل، عرض/إعداد القطع، إعدادات الصفحة، الموعد
│   │   ├── Progress/           # الإنجازات (إنجازات / جوائزي / المتجر)، بطاقة المستوى، الإحصائيات، الاحتفالات
│   │   └── Settings/           # الإعدادات، إعدادات الصلاة، صوت المنبه، النسخ الاحتياطي، فحص المنبهات
│   └── Resources/              # ملفات الترجمة (اللغة الأساسية عربي)، الأصول (أيقونة أساسية + ١٠ بديلة)
├── Shared/                     # ينبني داخل التطبيق والإضافة الاثنين
│   ├── AppGroup.swift          # يحدد معرف مجموعة التطبيق (يقرأ ALTAppGroups من AltStore أول)
│   ├── Theme.swift             # رموز التصميم + ألوان ثيمات المتجر
│   ├── WidgetSnapshot.swift    # JSON يكتبه التطبيق للويدجت
│   ├── TodayActivityAttributes.swift  # خصائص وحالة العرض الحي
│   ├── AlarmMetadata.swift     # بيانات إضافية للمنبه في AlarmKit
│   ├── ProgressVisuals.swift   # شريط الأجزاء (بأشكال المتجر)، حلقة التقدم
│   └── SharedFormat.swift      # تنسيق الأرقام والوقت والنسبة + الروابط (habits://today، habits://start)
└── Widgets/                    # إضافة الويدجت: TodayWidget، TodayLiveActivity، HabitAlarmActivity
```

> **ما فيه README**. ومجلد `Config/` غير موجود في git: XcodeGen يولّد ملفات Info.plist والصلاحيات من `project.yml`.

## ٤. البنية المعمارية (أهم قسم)

### ٤.١ ثلاث طبقات
١. **`HabitCore` (القواعد الصافية).** أنواع قيم ودوال صافية بس: بدون SwiftUI ولا SwiftData ولا
   `UserDefaults` ولا أطر النظام غير Foundation (+ Adhan). أي قاعدة ممكن تنختبر مكانها هنا و**لها اختبارات**.
   الوقت دايماً ينمرر (`now`، `calendar`) وما ينقرأ من داخل الدالة.
٢. **`App/Persistence` (السجلات والإجراءات).** كلاسات SwiftData تخزن البيانات؛ القيم المعقدة تنحفظ
   **JSON كـ `Data`** (مثل `repetitionData`، `timeData`، `definitionData`) وتنعرض بخصائص محسوبة تحوّلها
   لأنواع HabitCore (`TaskRecord.spec`، `AlarmRecord.rule`، `PageRecord.definition`). **كل تعديل يمر عن
   طريق ملفات `*Actions`** (`TaskActions`، `AlarmActions`، `PageActions`، `AchievementActions`، `BackupService`).
٣. **`App/Features` (واجهات SwiftUI).** تقرأ بـ `@Query` / `@AppStorage`، وتحسب الحالة المشتقة بـ
   `ProgressSnapshot.make(...)`، وتنادي الـ Actions للكتابة.

### ٤.٢ القاعدة الذهبية: "يُشتق، ما يُخزن"
الخبرة والنقاط والمستوى والستريك والأيام المكتملة والإحصائيات **ما تنحفظ أبداً**. تنحسب من جديد من التاريخ
(سجلات الإنجاز `CompletionRecord` + مواصفات المهمات) كل مرة عن طريق `ProgressSnapshot.make`. النتيجة:
- لو ألغيت إنجاز مهمة تنسحب خبرتها ونقاطها تلقائياً (ما فيه تلاعب).
- تعديل الماضي يظل متسق.
- الأشياء الوحيدة المخزنة: `AchievementUnlockRecord` (الإنجاز إذا انفتح **يظل** حتى لو تغير التاريخ)،
  `PurchaseRecord` (نقاط مصروفة)، و`RewardRecord.claimedCost` (نقاط مصروفة).

**لا تضيف عداد مخزن للخبرة أو النقاط أو الستريك.** أضف قاعدة في HabitCore واشتقها.

### ٤.٣ "لا تعيد كتابة الماضي"
- حذف مهمة **لها إنجازات** ما يحذفها فعلياً: يحط `endDay = اليوم` (غير شامل)، فالأيام الماضية والستريك
  تظل نفسها. المهمة اللي ما لها تاريخ تنحذف كلياً. والاثنين لهم تراجع (`DeleteUndo`).
- تغيير موعد (النوع/التكرار) مهمة مرتبطة بتنبيه أو صفحة **ولها تاريخ** ينهي المهمة القديمة اليوم ويسوي
  مهمة **جديدة** من اليوم.

### ٤.٤ اليوم
`DayKey` (سنة/شهر/يوم) هو وحدة التاريخ. إعداد **ساعة بداية اليوم** (`dayStartHour` من ٠ إلى ٢٣) يخلي
الشغل بعد منتصف الليل ينحسب لليوم اللي قبله. استخدم دايماً `Calendar.app` (ميلادي، الأسبوع يبدأ الأحد،
المنطقة الزمنية للجهاز) و`DayKey(date:calendar:dayStartHour:)`.

### ٤.٥ RootView هو المركز
`RootView` يحمل التبويبات الخمسة كصفحات جنب بعض (كلها شغالة، تسحب من حواف الشاشة، وتتلاشى بدل الحركة
لو "تقليل الحركة" مفعّل)، و**هيدر مقوس واحد مشترك يتحول** (كل صفحة ترسل `HeaderConfig` عن طريق preference)،
والشريط السفلي `CurvedTabBar`، والنوافذ (الإعدادات، المستوى الجديد، فتح إنجاز)، وطبقة اكتمال اليوم، وشاشة
التحدي الكاملة، وهذي المهام الخلفية:
- `.task(id: replanKey)` ← `AlarmActions.replan` كل ما تغيرت بصمة أي تنبيه أو الموقع أو الصوت أو اليوم.
- `.task(id: widgetKey)` ← يعيد بناء `WidgetSnapshot` ويزامن العرض الحي.
- النسخ الاحتياطي الأسبوعي، تذكير التوقيع، تذكير الصباح، مزامنة الإنجازات، الروابط (`habits://`)،
  تغير اليوم `NSCalendarDayChanged`، تغير حالة التطبيق، وإشعار `.achievementsNeedSync`.

`AppRouter` (`@Observable`) يحفظ حالة التنقل: `selectedTab`، `showSettings`، `openPageID`، الاحتفالات
(`levelUp`، `unlock`، `showDayComplete`)، `alarmStoppedAt`، `activeChallenge`.
`AppEnvironment.shared` يملك `ModelContainer` والراوتر (ويوصله الـ Intents والعمل في الخلفية).

## ٥. قواعد المجال (بالأرقام الدقيقة)

### ٥.١ المهمات
- `TaskKind.main` (رئيسية): تحرك **الستريك** والعرض الحي والويدجت و"اكتمال اليوم".
- `TaskKind.secondary` (فرعية): نفس الخبرة، **ما تأثر على الستريك**. ممكن تكون بدون تكرار = "بدون موعد لين تنجزها".
- التكرار `Repetition`: `.once(DayKey)`، `.weekly(أيام)` (`.daily` = كل الأيام)، `.monthly(أرقام أيام)`.
  لو الشهر ما فيه اليوم المختار (٣١ في أبريل) تنفذ في **آخر يوم** من الشهر.
- المهمات المسوّاة من تنبيه تحمل وقته (والصلوات الإضافية) عشان القوائم ترتب بالوقت.
- `TaskRecord.routineEnd` (شامل، منسوخ من نهاية روتين التنبيه) غير `endDay` (غير شامل، "أوقفها المالك").

### ٥.٢ تقدم اليوم والستريك (`StreakEngine`، حسب طلب المالك)
- يوم مكتمل ١٠٠٪ ← الستريك **+١** وعداد الغياب يرجع صفر.
- يوم جزئي (١–٩٩٪) ← الستريك **يثبت** وعداد الغياب يرجع صفر.
- يوم ٠٪ (وكان فيه مهمات رئيسية) ← عداد الغياب +١؛ وبعد **٣** أيام سماح متتالية، الستريك ينقص **١ عن كل يوم غياب زيادة** (وما ينزل تحت الصفر).
- يوم بدون مهمات رئيسية ← محايد.
- اليوم الحالي ينحسب بس إذا اكتمل؛ وما يعتبر "غياب" قبل ما يخلص.
- **ما فيه تجميد ستريك ولا تخطي، وهذا مقصود.** لا تضيفه.

### ٥.٣ الخبرة والنقاط والمستويات (`ProgressRules`)
- المهمة: **١٠ خبرة، ١ نقطة**. اليوم المكتمل: **٢٠ خبرة، ٣ نقاط**.
- محطات أفضل ستريك: ٧ أيام (٥٠ خبرة/٥ نقاط)، ١٤ (١٠٠/١٠)، ٣٠ (٢٠٠/٢٠)، ٦٠ (٣٠٠/٣٠)، ١٠٠ (٥٠٠/٥٠)، ٢٠٠ (٨٠٠/٨٠)، ٣٦٥ (١٥٠٠/١٥٠).
- الخبرة المطلوبة من مستوى L إلى L+1 = **١٠٠ + ٢٥ × (L − ١)**.
- الألقاب: مبتدئ ١–٤، مثابر ٥–٩، منضبط ١٠–١٩، متقن ٢٠–٣٤، قدوة ٣٥–٤٩، أسطورة ٥٠+.
- الملخص النهائي = الأساس (من التاريخ) + مكافآت الإنجازات − النقاط المصروفة. الإنجازات تنحكم على
  **المستوى الأساسي** (بدون خبرة الإنجازات) عشان ما تصير حلقة.

### ٥.٤ الإنجازات (`AchievementCatalog`)
تقريباً ٥٠ تعريف بمعرفات نصية ثابتة (مثل `tasks.100`، `streak.30`، `run.7`، `level.10`، `hidden.comeback`،
`bigday.5`، `early.1`، `night.10`، `page.1`، `sessions.50`). الشروط: مجموع المهمات، الأيام المكتملة، أفضل
ستريك، أيام مكتملة متتالية، المستوى الأساسي، العودة (تكمل يوم بعد ٣ أيام غياب أو أكثر)، المهمات الفرعية،
اليوم الحافل (عدد مهمات رئيسية في يوم مكتمل)، الطير المبكر (آخر مهمة رئيسية قبل **الظهر**)، ختامها مسك (بعد
**العشاء**)، عدد الصفحات المنشأة، وعدد جلسات الصفحات. المخفية تظهر "؟؟؟" لين تنفتح. **لا تغيّر أي معرف
موجود** (محفوظ في سجلات الفتح والنسخ الاحتياطية).

### ٥.٥ الجوائز ("جوائزي") والمتجر
- المالك يسوي جوائز بشرط: مستوى، ستريك، عدد مهمات، أيام مكتملة، إنجاز، أو **دفع نقاط** (تنخصم عند
  الاستلام). الحالات: مقفلة / مفتوحة / مستلمة.
- المتجر (`ShopCatalog`): **تجميلي فقط** — ممنوع أي شي يأثر على الستريك أو الخبرة. الفئات: ثيم (١٠)،
  إطار (٧)، مؤثر (٦)، شكل الشريط (٥)، أيقونة (١١). كل عنصر له سعر ومستوى مطلوب. المعرفات مثل `theme.ocean`
  و`icon.gold`. العناصر المجهزة تنحفظ في مفاتيح `SettingsKey.equipped*`.
- ألوان الثيمات في `Shared/Theme.swift` (`ThemePalette.palette(for:)`) ولازم تطابق معرفات الكتالوج.
  أسماء الأيقونات البديلة = `Icon` + اللاحقة بحرف كبير (`icon.night` ← `IconNight`) ولازم تكون مذكورة في
  `project.yml` تحت `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.

### ٥.٦ أوقات الصلاة
- `AdhanPrayerTimes(latitude:longitude:)` — أم القرى + الشافعي. خمس صلوات: الفجر، الظهر، العصر، المغرب، العشاء.
- الموقع: GPS **مرة وحدة** (`LocationService`)، أو قائمة ٢٠ مدينة سعودية (`SaudiCity.all`)، أو إحداثيات
  يدوية. ينحفظ في UserDefaults. بدون موقع، العناصر المرتبطة بالصلاة تعرض وصفها ("بعد العصر بـ 10 دقائق")
  بدل الوقت وما تنجدول.

### ٥.٧ التنبيهات
- `AlarmRule` (صافي) ⇄ `AlarmRecord` (SwiftData). الحقول: العنوان، الملاحظة، مفعّل، التكرار، `TimeSpec`
  (`.clock(ساعة,دقيقة)` أو `.prayer(صلاة, قبل/بعد, ساعات, دقائق)`)، `extraPrayers` (نفس الفارق على أكثر
  من صلاة)، `endDay` (شامل)، `isMainTask`، `linkedPageID`، `delivery` (`.alarm` منبه | `.notification`
  إشعار فقط)، `challenge`، `stopDestination`.
- **تنبيه المهمة الرئيسية**: `AlarmActions.syncLinkedTask` يخلي مهمة رئيسية وحدة مرتبطة متماشية معه. حذف
  التنبيه يحذف مهمته (مع الحفاظ على التاريخ) والعكس، مع إمكانية التراجع.
- **التخطيط**: `NotificationPlanner.plan` يبني مواعيد رنين فعلية لـ **١٤ يوم** قدام (ويبدأ من يوم قبل،
  لأن "بعد العشاء" ممكن يعدّي منتصف الليل)، مرتبة ومحدودة العدد (٦٠ لـ AlarmKit، و٤٠ للإشعارات؛ iOS يسمح
  بـ ٦٤ إشعار معلّق). المعرفات ثابتة: `alarm.<uuid>.<yyyyMMddHHmm>`.
- **AlarmScheduler** (AlarmKit): منبهات لمرة وحدة بموعد ثابت؛ معرفات AlarmKit هي **UUID ثابتة مشتقة من
  SHA-256** للمعرف + البصمة، فإعادة التخطيط مجرد مقارنة رخيصة. يلغي القديم المجدول، وما يلمس المنبهات اللي
  ترن أو مؤجلة أو موقوفة (إلا اليتيمة)، ويعطي أولوية لأول ٤٨ ساعة ولسلاسل التحدي، ويشيل المنبهات البعيدة إذا
  وصل الحد الأقصى، ويرجع لمنبه عادي لو النظام رفض نسخة التحدي. التأجيل = ١٠ دقائق (وما فيه تأجيل لمنبه
  التحدي). يكتب تقرير `AlarmScheduleReport` يظهر في الإعدادات ← فحص النظام.
- **AlarmNotifier**: تنبيهات الإشعار فقط عبارة عن إشعارات بمؤقت وبادئة `com.ghazaly.habits.alarmnote.`؛
  الضغط عليها يفتح المهمات / الصفحة / التنبيهات.
- التنبيه اللي لمرة وحدة يطفي نفسه بعد ما يرن (`expireFinished`).
- إعادة التخطيط تصير عند التشغيل، والرجوع للتطبيق، وتغير اليوم، وأي تغيير في التنبيهات/الموقع/الصوت، وفي
  التحديث الخلفي (تقريباً كل ٦ ساعات، والقرار لـ iOS).
- زر الإيقاف ← `OpenHabitsIntent` (يفتح التطبيق) ← الراوتر يروح للمهمات / الصفحة / التنبيهات ويحط
  `alarmStoppedAt` ← RootView يشيك إذا فيه تحدي أو وجهة منتظرة.

### ٥.٨ منبهات التحدي
- الأنواع: `math` معادلات (سهل/متوسط/صعب، ١–١٠ أسئلة، جمع وطرح، والناتج ما يكون سالب)، `steps` خطوات
  (١٠–٢٠٠٠ عن طريق `CMPedometer`)، `typing` كتابة (جمل عربية؛ يتجاهل التشكيل والتطويل والمسافات الزايدة)،
  `shake` هز (١٠–٢٠٠)، `memory` حفظ أرقام (٣–١٠ أرقام، وما تبدأ بصفر). كل القيم محصورة بحدود.
- لأن زر الإيقاف حق النظام ما ينمنع، تنجدول **سلسلة** من ١٠ منبهات إضافية (وحدة كل دقيقة) بعد كل رنة من
  أول **رنتين** قادمة؛ و`ChallengeLedger` (JSON في UserDefaults) يتابع الرنات المعلقة والمكتملة. إكمال
  التحدي يلغي باقي السلسلة. النافذة = ١٠ دقائق + دقيقتين.
- `ChallengeView` شاشة كاملة **ما تنقفل** لين يخلص التحدي (أو تنتهي النافذة). إذا الجهاز ما يدعم الخطوات أو
  الهز يتحول لمعادلات.
- `StopDestination`: `.link` رابط (https، روابط التطبيقات، mailto، tel؛ ممنوع `javascript/file/data/vbscript`؛
  والدومين بدون بروتوكول ينضاف له `https://`) أو `.shortcut` اختصار (`shortcuts://run-shortcut?name=…`).
  ينفتح بعد التحدي.

### ٥.٩ الصفحات الخاصة ("صفحاتي")
- `PageDefinition` (JSON في `PageRecord.definitionData`): الاسم، الإيموجي، اللون، **التبويبات** (كل وحدة
  قائمة قطع `Block`)، `rotatesTabs` (الجلسات المجدولة تدور أ←ب←ج)، `PageSchedule` اختياري (نفس محرر
  التنبيهات ← يسوي تنبيه مرتبط، ولو `isMainTask` يسوي مهمة رئيسية مرتبطة)، `pinnedToHome`، `anchorDay`.
- `Block` **struct واحد مرن** فيه `kind` وحقول كثيرة اختيارية، وكل حقل له قيمة افتراضية في فك الترميز، عشان
  الصفحات القديمة دايماً تنقرأ. **خلّه كذا** (أضف الحقول بقيم افتراضية، وارفع `pageSchemaVersion` بس لو
  التغيير يكسر التوافق).
- ٢١ نوع قطعة: عنوان، نص، مربع (يحتوي قطع)، مربع كتابة، رقم، جدول مجموعات (وزن × عدّات)، عداد، مربع
  اختيار، قائمة تحقق، اختيار، تقييم، تاريخ ووقت، مؤقت (إشعار لما يخلص)، ساعة إيقاف، شريط تقدم (يقدر يجمع
  أكثر من مصدر)، رسم بياني (القيمة، أعلى وزن، الحجم الكلي، مجموع العدّات)، السجل، فاصل، صورة (JPEG في
  Documents وتدخل في النسخ الاحتياطي)، رابط (موقع أو صفحة)، زر (إنهاء الجلسة، إكمال مهمة، تشغيل مؤقت، فتح
  صفحة، فتح تنبيه، إضافة مهمة فرعية، مسح الحقول).
- `PageSession`: القيم المكتوبة في استخدام واحد، بمفتاح معرف القطعة؛ تلميحات "آخر مرة"؛ الجلسة اللي ما
  انلمست ما تنحفظ؛ و**إنهاء الجلسة** يكمل المهمة الرئيسية المرتبطة لليوم.
- الأوضاع: **استخدام** (`PageUseView`) و**تعديل** (`PageEditView`: إضافة/إعداد/ترتيب/تكرار/نقل داخل
  المربعات/حذف مع تراجع). تعديل الشجرة الصافي في `PageTree.swift`.
- القوالب: الجاهزة **تمارين** (تدوير Full Body A/B/C)، **قراءة**، **شرب الماء**، **مذاكرة**؛ وقوالب
  المالك المحفوظة (`PageRecord.isTemplate`).

### ٥.١٠ العرض الحي والويدجت
- التطبيق يكتب `WidgetSnapshot` كـ JSON في حاوية **App Group** (`group.com.ghazaly.habits`، ويحددها
  `AppGroup` اللي يفضّل مفتاح `ALTAppGroups` من AltStore) ويحدّث الويدجت.
- العرض الحي (`TodayActivityAttributes`): جزء لكل مهمة رئيسية، المهمة التالية ووقتها، النسبة، ورابط "الانتقال
  إلى التطبيق" (**بدون أزرار إكمال**، باختيار المالك). يبدأ تلقائياً، ويتجدد (تقريباً كل ٧ ساعات؛ وفيه إشعار
  يذكرك تفتح التطبيق لأن العرض يدوم حوالي ٨ ساعات)، وفيه خيار "إيقاف لليوم".
- `TodayWidget`: صغير، متوسط، ودوائر/مستطيل/سطر لشاشة القفل. و`HabitAlarmActivity` مطلوب من AlarmKit
  للمنبهات المؤجلة.
- إضافة الويدجت **ما تستورد HabitCore**: المنطق اللي تحتاجه مكرر في `Shared/` (خل
  `WidgetSnapshot.nextItem/effectiveTime` متطابق مع `NextMainTask` و`TodayTaskItem.effectiveTime`).
- معرف الثيم ينسخ لإعدادات App Group عشان الويدجت تستخدم الثيم المجهز.

### ٥.١١ النسخ الاحتياطي
- `BackupDocument` (الإصدار **١**، تواريخ ISO-8601، مفاتيح مرتبة) فيه كل أنواع السجلات، وإعدادات مختارة
  (`BackupService.settingKeys`)، وصور الصفحات. فك الترميز يرفض الإصدارات الأحدث ويتأكد إن المعرفات ما
  تتكرر. الاسترجاع **يستبدل كل شي**. التصدير والاستيراد بملف؛ و**نسخ تلقائية أسبوعية** في
  `Documents/Backups` (`habits-backup-yyyy-MM-dd.json`، يحتفظ بآخر ٤، وتظهر في تطبيق الملفات لأن
  `UIFileSharingEnabled` مفعّل). فيه خيار "حذف كل البيانات". ملف صوت المنبه ما يدخل في النسخة.

### ٥.١٢ الإعدادات (مفاتيح UserDefaults في `SettingsKey`)
المظهر (تلقائي/فاتح/داكن)، نمط الأرقام، ساعة بداية اليوم، مفاتيح موقع الصلاة، عناصر المتجر المجهزة، تفعيل
العرض الحي وبدايته التلقائية، تذكير الصباح (تفعيل/ساعة/دقيقة)، صوت المنبه (ملف صوتي مستورد يتحول لـ `.caf`
في `Library/Sounds`، أقصاه ٢٩ ثانية)، عرض كل أوقات المهمة، المهمة التالية تتبع الرنة الجاية، النسخ التلقائي،
وقت آخر نسخة، تذكير التوقيع. تاريخ انتهاء التوقيع ينقرأ من `embedded.mobileprovision`، والتذكير يجي قبلها
بيوم ("جدّد التطبيق من AltStore").

## ٦. نظام التصميم
- الشكل: أبيض + درجات أخضر (أسود + أخضر في الداكن)، **هيدر أخضر مقوس**، و**شريط سفلي مقوس** بزر
  **رئيسية** دائري بارز في النص (شوف `docs/design/layout-reference.png`). ترتيب التبويبات من اليمين لليسار:
  المهمات · التنبيهات · (الرئيسية) · الإنجازات · صفحاتي. وفيه "فقاعة سائلة" خضراء تلحق التبويب المختار.
- **استخدم رموز `Theme` بس** (`primary`، `primaryStrong`، `barMuted`، `surface`، `card`، `textPrimary`،
  `textSecondary`، `danger`، `gold`) — ممنوع الألوان المباشرة. الذهبي للإنجازات والمستويات والجوائز فقط.
- كل شي يمر عن طريق `.appRoot()` (اتجاه RTL، `ar_SA`، نمط الأرقام، المظهر، اللون، و`.id(theme)` عشان يعيد
  البناء لما يتغير الثيم). **طبّق `.appRoot()` على كل sheet و fullScreenCover.**
- الأشكال اللي ما لازم تنعكس (إزاحة الصفحات والشريط) تنرسم داخل حاوية LTR صريحة.
- قواعد الوصولية مطبقة في كل مكان: الحالة ما تنعرف باللون بس (علامة صح + شطب، أشكال)، الهيدر يكبر مع حجم
  الخط، تقليل الحركة ← تلاشي، تسميات وتلميحات وصولية بالعربي، واهتزاز عند النجاح. أساس التصميم: إرشادات أبل HIG.
- اعرض الأرقام عن طريق بيئة نمط الأرقام (`digits.format(...)` / `NumberFormatting`)، وحط علامة LTR
  (`\u{200E}`) قبل المعادلات.

## ٧. البناء والاختبار والتوزيع
```bash
# اختبارات الوحدة (على macOS بأدوات Swift) — الشي الوحيد اللي يشتغل بدون Xcode/iOS:
swift test --package-path Packages/HabitCore

# على ماك فيه Xcode 26:
brew install xcodegen
xcodegen generate            # يسوي Habits.xcodeproj من project.yml
open Habits.xcodeproj
```
خط البناء (`.github/workflows/build.yml`، عند الدفع لـ `main`، أو وسوم `v*`، أو يدوي):
١. يختار أحدث Xcode 26 ← يثبت xcodegen و ldid ← **يشغّل اختبارات HabitCore** ← يولّد المشروع.
٢. `xcodebuild` بوضع Release لـ `generic/platform=iOS` مع **إيقاف التوقيع**؛ رقم البناء = رقم التشغيل.
٣. `ldid -S` للإضافة ثم التطبيق مع صلاحياتهم؛ و**يفشل البناء لو App Group مو موجود**.
٤. يضغط `Payload/Habits.app` ← `Habits.ipa`؛ ويرفعه كـ artifact.
٥. على `main`: ينشر Release باسم `build-<n>` (الأحدث) ويحدث `source.json` في Release `altstore-source`
   عشان AltStore دايماً يعرض آخر نسخة.

المعرفات: التطبيق `com.ghazaly.habits`، الويدجت `com.ghazaly.habits.widgets`، والرابط `habits`.
نصوص طلب الأذونات (بالعربي) موجودة لـ AlarmKit والموقع (أثناء الاستخدام) والحركة.

## ٨. قواعد للذكاء الاصطناعي اللي يشتغل على المشروع
١. **حط المنطق في HabitCore مع اختبارات**؛ وخل الواجهات خفيفة. مرّر `now`/`calendar`؛ ممنوع ساعات مخفية.
٢. **لا تخزن أرقام مشتقة** (خبرة، نقاط، ستريك، مستوى). اشتقها.
٣. **لا تعيد كتابة التاريخ**: استخدم `endDay` بدل حذف المهمات اللي لها إنجازات.
٤. **توافق البيانات القديمة**: أي خاصية جديدة في SwiftData لازم لها قيمة افتراضية؛ وأي حقل Codable جديد
   يستخدم `decodeIfPresent` مع قيمة افتراضية؛ وخل قيم الـ enum والمعرفات ثابتة. لو تغير شكل النسخة الاحتياطية
   بشكل يكسرها ارفع `BackupDocument.currentVersion`؛ وأضف الحقول الجديدة للتصدير **و**الاسترجاع.
٥. أي تغيير يأثر على الرنين لازم يغير **بصمة** التنبيه عشان `replanKey` يعيد التخطيط.
٦. احترم حدود النظام (٦٤ إشعار معلّق، والحد الأقصى لـ AlarmKit) — خطط مواعيد فعلية في نافذة متجددة.
٧. الكتابة تمر عن طريق `*Actions`؛ ونادِ `try? context.save()`؛ وأرسل `.achievementsNeedSync` لما شي خارج
   المهمات ممكن يفتح إنجاز.
٨. نصوص الواجهة: **عربي بلهجة سعودية عامية**، عن طريق `Text("…")` / `String(localized:)` (ملف الترجمة
   لغته الأساسية عربي). الكود والتعليقات ورسائل الـ commit **بالإنجليزي**.
٩. ممنوع خدمات مدفوعة أو سيرفر أو ميزات تحتاج حساب أبل مدفوع؛ ولازم يظل يشتغل لما يتثبت بحساب مجاني (AltStore
   ممكن يغير اسم App Group — استخدم دايماً `AppGroup.identifier`).
١٠. قرارات المالك لازم تنحترم: ما فيه تجميد ستريك؛ المهمات الرئيسية والفرعية نفس الخبرة؛ العرض الحي بدون أزرار
    إكمال؛ المتجر تجميلي فقط؛ والتطبيق لمستخدم واحد وخاص.
١١. إضافة الويدجت ما تقدر تستورد HabitCore — حط الكود المشترك في `Shared/` وطابق القواعد بحرص.
١٢. خل الـ commits مركزة؛ التاريخ يوضح commits لكل "مرحلة" وفروع PR بأسماء مثل `feature/...` و`fix/...`.

## ٩. خريطة سريعة: "وين أعدّل…؟"
| أبي أعدل… | الملفات |
|---|---|
| قواعد الستريك | `HabitCore/Streak/StreakEngine.swift` (+ الاختبارات) |
| الخبرة / النقاط / منحنى المستويات | `HabitCore/Progress/ProgressCalculator.swift` |
| إضافة إنجاز | `HabitCore/Achievements/Achievements.swift` (معرف جديد، لا تعيد استخدام قديم) |
| إضافة عنصر للمتجر | `HabitCore/Shop/ShopCatalog.swift` + `Shared/Theme.swift` / `ShopSection` / الأصول / `project.yml` |
| حساب مواعيد التنبيهات | `HabitCore/Alarms/NotificationPlanner.swift` |
| التعامل مع AlarmKit | `App/Services/AlarmScheduler.swift` |
| تنبيهات الإشعار فقط | `App/Services/AlarmNotifier.swift` |
| نوع تحدي جديد | `HabitCore/Alarms/AlarmChallenge.swift`، `ChallengeSection.swift`، `ChallengeView.swift` |
| قطعة صفحة جديدة | `HabitCore/Pages/PageSchema.swift` (`BlockKind`، `Block.make`)، `BlockUseView`، `BlockConfigView`، `PageValueText` |
| بطاقات الرئيسية | `App/Features/Home/HomeView.swift` |
| شكل العرض الحي / الويدجت | `Widgets/*.swift`، `Shared/ProgressVisuals.swift` |
| محتوى النسخة الاحتياطية | `HabitCore/Backup/BackupDocument.swift` + `App/Persistence/BackupService.swift` |
| الإعدادات | `App/Features/Settings/SettingsView.swift`، والمفاتيح في `App/Design/AppRoot.swift` |
| الهيدر / الشريط / الأشكال | `App/Design/CurvedPage.swift`، `CurvedShapes.swift`، `Metrics.swift`، `Navigation/CurvedTabBar.swift` |
