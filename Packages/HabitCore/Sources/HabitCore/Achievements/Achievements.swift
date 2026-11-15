import Foundation

/// Everything the achievement rules look at. All derived from history except `unlocked`.
public struct AchievementStats: Equatable, Sendable {
    public var completedTasks: Int
    public var completeDays: Int
    public var currentStreak: Int
    public var bestStreak: Int
    public var longestCompleteRun: Int
    public var comebacks: Int
    /// Level from task/day/streak XP only (achievement bonuses excluded, to avoid a loop).
    public var baseLevel: Int
    /// Completed secondary tasks.
    public var secondaryTasks: Int
    /// Most main tasks finished together in one complete day.
    public var biggestCompleteDay: Int
    /// Complete days whose last main task was done before Dhuhr.
    public var earlyBirdDays: Int
    /// Complete days whose last main task was done after Isha.
    public var nightFinisherDays: Int
    public var pagesCreated: Int
    public var pageSessions: Int

    public init(completedTasks: Int = 0, completeDays: Int = 0, currentStreak: Int = 0, bestStreak: Int = 0,
                longestCompleteRun: Int = 0, comebacks: Int = 0, baseLevel: Int = 1,
                secondaryTasks: Int = 0, biggestCompleteDay: Int = 0, earlyBirdDays: Int = 0,
                nightFinisherDays: Int = 0, pagesCreated: Int = 0, pageSessions: Int = 0) {
        self.secondaryTasks = secondaryTasks
        self.biggestCompleteDay = biggestCompleteDay
        self.earlyBirdDays = earlyBirdDays
        self.nightFinisherDays = nightFinisherDays
        self.pagesCreated = pagesCreated
        self.pageSessions = pageSessions
        self.completedTasks = completedTasks
        self.completeDays = completeDays
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.longestCompleteRun = longestCompleteRun
        self.comebacks = comebacks
        self.baseLevel = baseLevel
    }
}

public enum AchievementCondition: Equatable, Sendable {
    case streak(Int)        // best streak reached
    case tasks(Int)         // total tasks completed
    case completeDays(Int)  // total complete days
    case completeRun(Int)   // consecutive complete days
    case level(Int)         // base level
    case comeback           // came back after being away
    case comebacks(Int)     // came back N times
    case secondaryTasks(Int)
    case bigDay(Int)        // a complete day with N main tasks
    case earlyBird(Int)     // N complete days finished before Dhuhr
    case nightFinisher(Int) // N complete days finished after Isha
    case pagesCreated(Int)
    case pageSessions(Int)
}

public struct AchievementDef: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let symbol: String
    public let condition: AchievementCondition
    public let xp: Int
    public let points: Int
    /// Hidden ones show "؟؟؟" until unlocked.
    public let hidden: Bool

    public init(id: String, name: String, detail: String, symbol: String, condition: AchievementCondition,
                xp: Int, points: Int, hidden: Bool = false) {
        self.id = id
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.condition = condition
        self.xp = xp
        self.points = points
        self.hidden = hidden
    }
}

public enum AchievementCatalog {
    public static let all: [AchievementDef] = [
        AchievementDef(id: "tasks.1", name: "البداية", detail: "أكمل أول مهمة", symbol: "flag.fill", condition: .tasks(1), xp: 10, points: 1),
        AchievementDef(id: "tasks.10", name: "عشر خطوات", detail: "أكمل 10 مهام", symbol: "figure.walk", condition: .tasks(10), xp: 20, points: 2),
        AchievementDef(id: "tasks.100", name: "مئة إنجاز", detail: "أكمل 100 مهمة", symbol: "checkmark.seal.fill", condition: .tasks(100), xp: 60, points: 6),
        AchievementDef(id: "tasks.500", name: "عامل مجتهد", detail: "أكمل 500 مهمة", symbol: "hammer.fill", condition: .tasks(500), xp: 150, points: 15),
        AchievementDef(id: "tasks.1000", name: "الألف", detail: "أكمل 1000 مهمة", symbol: "crown.fill", condition: .tasks(1000), xp: 300, points: 30),

        AchievementDef(id: "days.1", name: "يوم مكتمل", detail: "أنجز كل مهام يوم كامل", symbol: "sun.max.fill", condition: .completeDays(1), xp: 15, points: 2),
        AchievementDef(id: "days.10", name: "عشرة أيام كاملة", detail: "أكمل 10 أيام", symbol: "calendar.badge.checkmark", condition: .completeDays(10), xp: 50, points: 5),
        AchievementDef(id: "days.50", name: "خمسون يوماً", detail: "أكمل 50 يوماً", symbol: "calendar", condition: .completeDays(50), xp: 120, points: 12),
        AchievementDef(id: "days.100", name: "مئة يوم", detail: "أكمل 100 يوم", symbol: "star.circle.fill", condition: .completeDays(100), xp: 250, points: 25),

        AchievementDef(id: "streak.3", name: "شرارة", detail: "سلسلة 3 أيام", symbol: "flame", condition: .streak(3), xp: 15, points: 2),
        AchievementDef(id: "streak.7", name: "أسبوع متواصل", detail: "سلسلة 7 أيام", symbol: "flame.fill", condition: .streak(7), xp: 25, points: 3),
        AchievementDef(id: "streak.30", name: "شهر من الالتزام", detail: "سلسلة 30 يوماً", symbol: "bolt.fill", condition: .streak(30), xp: 75, points: 8),
        AchievementDef(id: "streak.100", name: "المئة", detail: "سلسلة 100 يوم", symbol: "trophy.fill", condition: .streak(100), xp: 200, points: 20),
        AchievementDef(id: "streak.365", name: "سنة كاملة", detail: "سلسلة 365 يوماً", symbol: "medal.fill", condition: .streak(365), xp: 500, points: 50),

        AchievementDef(id: "run.7", name: "أسبوع مثالي", detail: "7 أيام مكتملة متتالية", symbol: "checkmark.circle.fill", condition: .completeRun(7), xp: 60, points: 6),

        AchievementDef(id: "level.5", name: "مثابر", detail: "اصل إلى المستوى 5", symbol: "5.circle.fill", condition: .level(5), xp: 40, points: 4),
        AchievementDef(id: "level.10", name: "منضبط", detail: "اصل إلى المستوى 10", symbol: "10.circle.fill", condition: .level(10), xp: 100, points: 10),
        AchievementDef(id: "level.25", name: "متقن", detail: "اصل إلى المستوى 25", symbol: "25.circle.fill", condition: .level(25), xp: 250, points: 25),
        AchievementDef(id: "level.50", name: "أسطورة", detail: "اصل إلى المستوى 50", symbol: "50.circle.fill", condition: .level(50), xp: 600, points: 60),

        AchievementDef(id: "hidden.comeback", name: "العودة", detail: "أكمل يوماً بعد غياب 3 أيام أو أكثر", symbol: "arrow.uturn.up.circle.fill", condition: .comeback, xp: 40, points: 4, hidden: true),
        AchievementDef(id: "hidden.run30", name: "شهر لا ينكسر", detail: "30 يوماً مكتملاً متتالياً", symbol: "infinity.circle.fill", condition: .completeRun(30), xp: 150, points: 15, hidden: true),

        // MARK: more milestones
        AchievementDef(id: "tasks.25", name: "ربع المئة", detail: "أكمل 25 مهمة", symbol: "list.bullet.clipboard.fill", condition: .tasks(25), xp: 25, points: 2),
        AchievementDef(id: "tasks.250", name: "ربع الألف", detail: "أكمل 250 مهمة", symbol: "shippingbox.fill", condition: .tasks(250), xp: 100, points: 10),
        AchievementDef(id: "tasks.2500", name: "الماكينة", detail: "أكمل 2500 مهمة", symbol: "gearshape.2.fill", condition: .tasks(2500), xp: 600, points: 60),

        AchievementDef(id: "days.5", name: "خمسة كاملة", detail: "أكمل 5 أيام", symbol: "5.square.fill", condition: .completeDays(5), xp: 25, points: 2),
        AchievementDef(id: "days.25", name: "خمسة وعشرون يوماً", detail: "أكمل 25 يوماً", symbol: "calendar.circle.fill", condition: .completeDays(25), xp: 80, points: 8),
        AchievementDef(id: "days.200", name: "مئتا يوم", detail: "أكمل 200 يوم", symbol: "rosette", condition: .completeDays(200), xp: 400, points: 40),
        AchievementDef(id: "days.365", name: "عام من الأيام الكاملة", detail: "أكمل 365 يوماً", symbol: "laurel.leading", condition: .completeDays(365), xp: 700, points: 70),

        AchievementDef(id: "streak.14", name: "أسبوعان متواصلان", detail: "سلسلة 14 يوماً", symbol: "flame.circle.fill", condition: .streak(14), xp: 40, points: 4),
        AchievementDef(id: "streak.60", name: "شهران متواصلان", detail: "سلسلة 60 يوماً", symbol: "bolt.circle.fill", condition: .streak(60), xp: 120, points: 12),
        AchievementDef(id: "streak.200", name: "المئتان", detail: "سلسلة 200 يوم", symbol: "sparkles", condition: .streak(200), xp: 350, points: 35),

        AchievementDef(id: "run.3", name: "ثلاثية", detail: "3 أيام مكتملة متتالية", symbol: "3.circle.fill", condition: .completeRun(3), xp: 20, points: 2),
        AchievementDef(id: "run.14", name: "أسبوعان مثاليان", detail: "14 يوماً مكتملاً متتالياً", symbol: "hands.sparkles.fill", condition: .completeRun(14), xp: 100, points: 10),
        AchievementDef(id: "run.60", name: "شهران مثاليان", detail: "60 يوماً مكتملاً متتالياً", symbol: "seal.fill", condition: .completeRun(60), xp: 300, points: 30),

        AchievementDef(id: "level.15", name: "ثابت الخطى", detail: "اصل إلى المستوى 15", symbol: "15.circle.fill", condition: .level(15), xp: 150, points: 15),
        AchievementDef(id: "level.35", name: "قدوة", detail: "اصل إلى المستوى 35", symbol: "35.circle.fill", condition: .level(35), xp: 400, points: 40),
        AchievementDef(id: "level.75", name: "ما بعد الأسطورة", detail: "اصل إلى المستوى 75", symbol: "sparkle", condition: .level(75), xp: 900, points: 90),

        AchievementDef(id: "hidden.comeback3", name: "ما يستسلم", detail: "ارجع وأكمل يوماً بعد غياب، 3 مرات", symbol: "arrow.triangle.2.circlepath.circle.fill", condition: .comebacks(3), xp: 80, points: 8, hidden: true),

        AchievementDef(id: "bigday.5", name: "يوم حافل", detail: "أنجز 5 مهمات رئيسية في يوم واحد", symbol: "rectangle.stack.fill", condition: .bigDay(5), xp: 50, points: 5),
        AchievementDef(id: "bigday.8", name: "يوم الوحوش", detail: "أنجز 8 مهمات رئيسية في يوم واحد", symbol: "bolt.heart.fill", condition: .bigDay(8), xp: 120, points: 12),

        AchievementDef(id: "secondary.25", name: "ما يكفيه الأساسي", detail: "أكمل 25 مهمة فرعية", symbol: "plus.circle.fill", condition: .secondaryTasks(25), xp: 50, points: 5),

        // MARK: timing (need the prayer location)
        AchievementDef(id: "early.1", name: "الطير المبكر", detail: "أنهِ كل مهماتك الرئيسية قبل الظهر", symbol: "sunrise.fill", condition: .earlyBird(1), xp: 30, points: 3),
        AchievementDef(id: "early.10", name: "صاحب الضحى", detail: "10 أيام أنهيت فيها كل المهمات قبل الظهر", symbol: "sun.horizon.fill", condition: .earlyBird(10), xp: 120, points: 12),
        AchievementDef(id: "night.1", name: "ختامها مسك", detail: "أنهِ كل مهماتك الرئيسية بعد العشاء", symbol: "moon.stars.fill", condition: .nightFinisher(1), xp: 30, points: 3),
        AchievementDef(id: "night.10", name: "سهران على الإنجاز", detail: "10 أيام أنهيت فيها كل المهمات بعد العشاء", symbol: "moon.zzz.fill", condition: .nightFinisher(10), xp: 100, points: 10),

        // MARK: builder (custom pages)
        AchievementDef(id: "page.1", name: "البنّاء", detail: "أنشئ أول صفحة خاصة", symbol: "square.grid.2x2.fill", condition: .pagesCreated(1), xp: 25, points: 3),
        AchievementDef(id: "sessions.10", name: "سجّل مواظب", detail: "سجّل 10 جلسات في صفحاتك", symbol: "pencil.and.list.clipboard", condition: .pageSessions(10), xp: 60, points: 6),
        AchievementDef(id: "sessions.50", name: "أرشيف كامل", detail: "سجّل 50 جلسة في صفحاتك", symbol: "books.vertical.fill", condition: .pageSessions(50), xp: 180, points: 18)
    ]

    public static func definition(id: String) -> AchievementDef? {
        all.first { $0.id == id }
    }
}

public struct AchievementProgress: Equatable, Sendable {
    public let current: Int
    public let target: Int
    public var isMet: Bool { current >= target }
    public var fraction: Double { target == 0 ? 1 : min(1, Double(current) / Double(target)) }
}

public enum AchievementEvaluator {
    public static func progress(of def: AchievementDef, stats: AchievementStats) -> AchievementProgress {
        switch def.condition {
        case .streak(let n): return AchievementProgress(current: min(stats.bestStreak, n), target: n)
        case .tasks(let n): return AchievementProgress(current: min(stats.completedTasks, n), target: n)
        case .completeDays(let n): return AchievementProgress(current: min(stats.completeDays, n), target: n)
        case .completeRun(let n): return AchievementProgress(current: min(stats.longestCompleteRun, n), target: n)
        case .level(let n): return AchievementProgress(current: min(stats.baseLevel, n), target: n)
        case .comeback: return AchievementProgress(current: min(stats.comebacks, 1), target: 1)
        case .comebacks(let n): return AchievementProgress(current: min(stats.comebacks, n), target: n)
        case .secondaryTasks(let n): return AchievementProgress(current: min(stats.secondaryTasks, n), target: n)
        case .bigDay(let n): return AchievementProgress(current: min(stats.biggestCompleteDay, n), target: n)
        case .earlyBird(let n): return AchievementProgress(current: min(stats.earlyBirdDays, n), target: n)
        case .nightFinisher(let n): return AchievementProgress(current: min(stats.nightFinisherDays, n), target: n)
        case .pagesCreated(let n): return AchievementProgress(current: min(stats.pagesCreated, n), target: n)
        case .pageSessions(let n): return AchievementProgress(current: min(stats.pageSessions, n), target: n)
        }
    }

    /// Achievements met now that are not yet recorded as unlocked.
    public static func newlyUnlocked(stats: AchievementStats, alreadyUnlocked: Set<String>) -> [AchievementDef] {
        AchievementCatalog.all.filter { !alreadyUnlocked.contains($0.id) && progress(of: $0, stats: stats).isMet }
    }

    /// XP and points granted by the unlocked achievements (unknown ids are ignored).
    public static func bonus(unlocked: Set<String>) -> (xp: Int, points: Int) {
        var xp = 0, points = 0
        for id in unlocked {
            if let def = AchievementCatalog.definition(id: id) { xp += def.xp; points += def.points }
        }
        return (xp, points)
    }
}
