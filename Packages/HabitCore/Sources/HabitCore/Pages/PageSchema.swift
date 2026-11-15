import Foundation

/// Bump when the stored shape changes in a way old data can't decode into.
public let pageSchemaVersion = 1

public enum BlockKind: String, Codable, CaseIterable, Sendable {
    case heading, text, container, textField, number, sets, counter, checkbox, checklist, choice
    case rating, dateTime, timer, stopwatch, progress, chart, history, divider, image, link, button

    /// Arabic name shown in the builder.
    public var arabicName: String {
        switch self {
        case .heading: return "عنوان"
        case .text: return "نص"
        case .container: return "مربع"
        case .textField: return "مربع كتابة"
        case .number: return "رقم"
        case .sets: return "جدول مجموعات"
        case .counter: return "عداد"
        case .checkbox: return "مربع اختيار"
        case .checklist: return "قائمة تحقق"
        case .choice: return "اختيار"
        case .rating: return "تقييم"
        case .dateTime: return "تاريخ ووقت"
        case .timer: return "مؤقت"
        case .stopwatch: return "ساعة إيقاف"
        case .progress: return "شريط تقدم"
        case .chart: return "رسم بياني"
        case .history: return "السجل"
        case .divider: return "فاصل"
        case .image: return "صورة"
        case .link: return "رابط"
        case .button: return "زر"
        }
    }

    public var symbol: String {
        switch self {
        case .heading: return "textformat.size"
        case .text: return "text.alignright"
        case .container: return "square.on.square"
        case .textField: return "character.cursor.ibeam"
        case .number: return "number"
        case .sets: return "tablecells"
        case .counter: return "plusminus.circle"
        case .checkbox: return "checkmark.square"
        case .checklist: return "checklist"
        case .choice: return "list.bullet.circle"
        case .rating: return "star"
        case .dateTime: return "calendar"
        case .timer: return "timer"
        case .stopwatch: return "stopwatch"
        case .progress: return "chart.bar.fill"
        case .chart: return "chart.xyaxis.line"
        case .history: return "clock.arrow.circlepath"
        case .divider: return "minus"
        case .image: return "photo"
        case .link: return "link"
        case .button: return "button.horizontal"
        }
    }

    /// Blocks the owner fills in during a session (their values are saved).
    public var isInput: Bool {
        switch self {
        case .textField, .number, .sets, .counter, .checkbox, .checklist, .choice, .rating, .dateTime, .stopwatch:
            return true
        default:
            return false
        }
    }

    /// Input blocks whose values can be plotted.
    public var isChartable: Bool {
        switch self {
        case .number, .sets, .counter, .rating, .stopwatch: return true
        default: return false
        }
    }

    /// Blocks that can be the target of a progress bar.
    public var isNumeric: Bool {
        switch self {
        case .number, .counter, .stopwatch, .rating: return true
        default: return false
        }
    }

    /// Builder categories (for the "إضافة قطعة" sheet).
    public static var categories: [(name: String, kinds: [BlockKind])] {
        [
            ("التنسيق", [.heading, .text, .divider, .container, .image, .link]),
            ("الإدخال", [.textField, .number, .sets, .counter, .checkbox, .checklist, .choice, .rating, .dateTime]),
            ("الوقت", [.timer, .stopwatch]),
            ("العرض", [.progress, .chart, .history]),
            ("الإجراءات", [.button])
        ]
    }
}

public enum HeadingSize: String, Codable, CaseIterable, Sendable {
    case large, medium, small
    public var arabicName: String {
        switch self {
        case .large: return "كبير"
        case .medium: return "متوسط"
        case .small: return "صغير"
        }
    }
}

public enum ChartMetric: String, Codable, CaseIterable, Sendable {
    /// The block's own number (number, counter, rating, stopwatch).
    case value
    /// Sets table: heaviest value of the first column.
    case setsMax
    /// Sets table: sum of first column × second column.
    case setsVolume
    /// Sets table: sum of the second column.
    case setsTotal

    public var arabicName: String {
        switch self {
        case .value: return "القيمة"
        case .setsMax: return "أعلى وزن"
        case .setsVolume: return "الحجم الكلي"
        case .setsTotal: return "مجموع العدّات"
        }
    }
}

/// What a button does when pressed (in use mode).
public enum ButtonAction: Codable, Equatable, Sendable {
    /// Saves the session and completes the page's linked main task for today.
    case finishSession
    /// Completes a chosen task for today.
    case completeTask(UUID)
    /// Starts a timer block of this page.
    case startTimer(UUID)
    case openPage(UUID)
    case openAlarm(UUID)
    /// Quick-creates a secondary task with this title.
    case addSecondaryTask(String)
    /// Resets the values typed in the current session.
    case clearFields
}

/// One element of a page. A single flexible struct (not an enum per type) so old saved
/// pages keep decoding when a field is added: every field has a default.
public struct Block: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: BlockKind
    /// Label / heading text / button caption.
    public var title: String
    /// Static text for `.text`.
    public var text: String
    public var unit: String
    public var allowDecimal: Bool
    public var multiline: Bool
    /// Show the value from the last session as a hint.
    public var showLast: Bool
    public var step: Double
    public var target: Double?
    /// Checklist items / choice options.
    public var options: [String]
    public var multiSelect: Bool
    /// Sets-table column names (first = weight-like, second = count-like).
    public var columns: [String]
    /// Top of a rating (stars) — 3...10.
    public var maxRating: Int
    /// Timer length.
    public var seconds: Int
    public var headingSize: HeadingSize
    /// Source blocks for progress / chart / history.
    public var sourceIDs: [UUID]
    public var metric: ChartMetric
    public var action: ButtonAction?
    public var linkURL: String
    public var linkPageID: UUID?
    /// File name of a stored image (in the app's pages folder).
    public var imageFile: String
    public var collapsed: Bool
    public var children: [Block]

    public init(
        id: UUID = UUID(), kind: BlockKind, title: String = "", text: String = "", unit: String = "",
        allowDecimal: Bool = false, multiline: Bool = false, showLast: Bool = true, step: Double = 1,
        target: Double? = nil, options: [String] = [], multiSelect: Bool = false, columns: [String] = [],
        maxRating: Int = 5, seconds: Int = 90, headingSize: HeadingSize = .medium, sourceIDs: [UUID] = [],
        metric: ChartMetric = .value, action: ButtonAction? = nil, linkURL: String = "", linkPageID: UUID? = nil,
        imageFile: String = "", collapsed: Bool = false, children: [Block] = []
    ) {
        self.id = id; self.kind = kind; self.title = title; self.text = text; self.unit = unit
        self.allowDecimal = allowDecimal; self.multiline = multiline; self.showLast = showLast; self.step = step
        self.target = target; self.options = options; self.multiSelect = multiSelect; self.columns = columns
        self.maxRating = maxRating; self.seconds = seconds; self.headingSize = headingSize; self.sourceIDs = sourceIDs
        self.metric = metric; self.action = action; self.linkURL = linkURL; self.linkPageID = linkPageID
        self.imageFile = imageFile; self.collapsed = collapsed; self.children = children
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, title, text, unit, allowDecimal, multiline, showLast, step, target, options, multiSelect
        case columns, maxRating, seconds, headingSize, sourceIDs, metric, action, linkURL, linkPageID, imageFile
        case collapsed, children
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(BlockKind.self, forKey: .kind) ?? .text
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
        allowDecimal = try c.decodeIfPresent(Bool.self, forKey: .allowDecimal) ?? false
        multiline = try c.decodeIfPresent(Bool.self, forKey: .multiline) ?? false
        showLast = try c.decodeIfPresent(Bool.self, forKey: .showLast) ?? true
        step = try c.decodeIfPresent(Double.self, forKey: .step) ?? 1
        target = try c.decodeIfPresent(Double.self, forKey: .target)
        options = try c.decodeIfPresent([String].self, forKey: .options) ?? []
        multiSelect = try c.decodeIfPresent(Bool.self, forKey: .multiSelect) ?? false
        columns = try c.decodeIfPresent([String].self, forKey: .columns) ?? []
        maxRating = try c.decodeIfPresent(Int.self, forKey: .maxRating) ?? 5
        seconds = try c.decodeIfPresent(Int.self, forKey: .seconds) ?? 90
        headingSize = try c.decodeIfPresent(HeadingSize.self, forKey: .headingSize) ?? .medium
        sourceIDs = try c.decodeIfPresent([UUID].self, forKey: .sourceIDs) ?? []
        metric = try c.decodeIfPresent(ChartMetric.self, forKey: .metric) ?? .value
        action = try c.decodeIfPresent(ButtonAction.self, forKey: .action)
        linkURL = try c.decodeIfPresent(String.self, forKey: .linkURL) ?? ""
        linkPageID = try c.decodeIfPresent(UUID.self, forKey: .linkPageID)
        imageFile = try c.decodeIfPresent(String.self, forKey: .imageFile) ?? ""
        collapsed = try c.decodeIfPresent(Bool.self, forKey: .collapsed) ?? false
        children = try c.decodeIfPresent([Block].self, forKey: .children) ?? []
    }

    /// A new block of a kind with sensible Arabic defaults.
    public static func make(_ kind: BlockKind) -> Block {
        var b = Block(kind: kind)
        switch kind {
        case .heading: b.title = "عنوان"; b.headingSize = .large
        case .text: b.text = "نص"
        case .container: b.title = "مربع"
        case .textField: b.title = "ملاحظات"; b.multiline = true
        case .number: b.title = "رقم"
        case .sets: b.title = "المجموعات"; b.columns = ["الوزن (كجم)", "العدّات"]
        case .counter: b.title = "عداد"
        case .checkbox: b.title = "تم"
        case .checklist: b.title = "قائمة"; b.options = ["عنصر ١"]
        case .choice: b.title = "اختيار"; b.options = ["خيار ١", "خيار ٢"]
        case .rating: b.title = "تقييم"
        case .dateTime: b.title = "التاريخ والوقت"
        case .timer: b.title = "راحة"; b.seconds = 90
        case .stopwatch: b.title = "ساعة إيقاف"
        case .progress: b.title = "التقدم"
        case .chart: b.title = "رسم بياني"
        case .history: b.title = "السجل"
        case .divider: break
        case .image: b.title = "صورة"
        case .link: b.title = "رابط"
        case .button: b.title = "إنهاء الجلسة"; b.action = .finishSession
        }
        return b
    }

    /// Whether the fixed layout of a page lets this block nest children.
    public var isContainer: Bool { kind == .container }
}

/// A sub-list inside a page (e.g. "Full Body A").
public struct PageTab: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var blocks: [Block]

    public init(id: UUID = UUID(), name: String, blocks: [Block] = []) {
        self.id = id; self.name = name; self.blocks = blocks
    }
}

/// When a page's session happens: the same rules and editor as alarms.
public struct PageSchedule: Codable, Equatable, Sendable {
    public var repetition: Repetition
    public var time: TimeSpec
    /// More prayers with the same offset as `time` (same idea as `AlarmRule.extraPrayers`).
    public var extraPrayers: [Prayer]
    /// Last day the routine still happens (inclusive); nil = never ends.
    public var endDay: DayKey?

    public init(repetition: Repetition, time: TimeSpec, extraPrayers: [Prayer] = [], endDay: DayKey? = nil) {
        self.repetition = repetition; self.time = time; self.extraPrayers = extraPrayers; self.endDay = endDay
    }

    private enum CodingKeys: String, CodingKey { case repetition, time, extraPrayers, endDay }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        repetition = try c.decode(Repetition.self, forKey: .repetition)
        time = try c.decode(TimeSpec.self, forKey: .time)
        extraPrayers = try c.decodeIfPresent([Prayer].self, forKey: .extraPrayers) ?? []
        endDay = try c.decodeIfPresent(DayKey.self, forKey: .endDay)
    }
}

/// The page template: its structure. What the owner types lives in `PageSession`.
public struct PageDefinition: Codable, Equatable, Identifiable, Sendable {
    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var emoji: String
    /// Accent palette name (resolved by the app: green, blue, purple, orange, pink, gray).
    public var accent: String
    public var tabs: [PageTab]
    /// With a schedule, sessions cycle through the tabs in order.
    public var rotatesTabs: Bool
    public var schedule: PageSchedule?
    public var isMainTask: Bool
    public var pinnedToHome: Bool
    /// First day the rotation counts from.
    public var anchorDay: DayKey

    public init(
        schemaVersion: Int = pageSchemaVersion, id: UUID = UUID(), name: String, emoji: String = "📄",
        accent: String = "green", tabs: [PageTab] = [], rotatesTabs: Bool = false, schedule: PageSchedule? = nil,
        isMainTask: Bool = false, pinnedToHome: Bool = false,
        anchorDay: DayKey = DayKey(year: 2026, month: 1, day: 1)
    ) {
        self.schemaVersion = schemaVersion; self.id = id; self.name = name; self.emoji = emoji; self.accent = accent
        self.tabs = tabs; self.rotatesTabs = rotatesTabs; self.schedule = schedule; self.isMainTask = isMainTask
        self.pinnedToHome = pinnedToHome; self.anchorDay = anchorDay
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, emoji, accent, tabs, rotatesTabs, schedule, isMainTask, pinnedToHome, anchorDay
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji) ?? "📄"
        accent = try c.decodeIfPresent(String.self, forKey: .accent) ?? "green"
        tabs = try c.decodeIfPresent([PageTab].self, forKey: .tabs) ?? []
        rotatesTabs = try c.decodeIfPresent(Bool.self, forKey: .rotatesTabs) ?? false
        schedule = try c.decodeIfPresent(PageSchedule.self, forKey: .schedule)
        isMainTask = try c.decodeIfPresent(Bool.self, forKey: .isMainTask) ?? false
        pinnedToHome = try c.decodeIfPresent(Bool.self, forKey: .pinnedToHome) ?? false
        anchorDay = try c.decodeIfPresent(DayKey.self, forKey: .anchorDay) ?? DayKey(year: 2026, month: 1, day: 1)
    }

    /// Every block of every tab, containers flattened.
    public var allBlocks: [Block] { tabs.flatMap { $0.blocks.flattened } }

    public func tab(withID id: UUID) -> PageTab? { tabs.first { $0.id == id } }
}

// MARK: - Values typed during a session

public struct SetRow: Codable, Equatable, Sendable {
    public var values: [Double?]
    public init(values: [Double?]) { self.values = values }
}

public enum BlockValue: Codable, Equatable, Sendable {
    case text(String)
    case number(Double)
    case bool(Bool)
    case rows([SetRow])
    /// Checklist: one flag per item.
    case flags([Bool])
    /// Choice: selected option indexes.
    case choices([Int])
    case date(Date)
    /// Stopwatch: elapsed seconds.
    case duration(Double)

    /// The value as a single number when it makes sense (for hints and charts).
    public var asNumber: Double? {
        switch self {
        case .number(let n): return n
        case .duration(let d): return d
        default: return nil
        }
    }

    /// Nothing was entered.
    public var isEmpty: Bool {
        switch self {
        case .text(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .number, .date: return false
        case .bool(let b): return !b
        case .rows(let rows): return rows.allSatisfy { $0.values.allSatisfy { $0 == nil } }
        case .flags(let f): return !f.contains(true)
        case .choices(let c): return c.isEmpty
        case .duration(let d): return d <= 0
        }
    }
}
