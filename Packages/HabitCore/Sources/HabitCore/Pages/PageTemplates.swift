import Foundation

/// Built-in page templates. Every call makes fresh ids, so a template can be used many times.
public enum PageTemplates {
    public struct Info: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let emoji: String
        public let summary: String
    }

    public static let all: [Info] = [
        Info(id: "workout", name: "تمارين", emoji: "🏋️", summary: "ثلاث تبويبات (أ، ب، ج) بتمارين وجداول مجموعات ومؤقت راحة ورسم لتطور الوزن"),
        Info(id: "reading", name: "قراءة", emoji: "📚", summary: "عدّاد صفحات، اسم الكتاب، ملاحظات، ورسم بياني"),
        Info(id: "water", name: "شرب الماء", emoji: "💧", summary: "عدّاد أكواب بهدف يومي وشريط تقدم"),
        Info(id: "study", name: "مذاكرة", emoji: "🎓", summary: "ساعة إيقاف، اختيار المادة، وملاحظات"),
        Info(id: "calories", name: "سعراتي", emoji: "🥗", summary: "أهداف السعرات والماكروز، وجبات، بحث عن الأكل بالذكاء الاصطناعي، إجمالي اليوم والمتوسط الأسبوعي")
    ]

    public static func make(_ id: String) -> PageDefinition? {
        switch id {
        case "workout": return workout()
        case "reading": return reading()
        case "water": return water()
        case "study": return study()
        case "calories": return calories()
        default: return nil
        }
    }

    /// A blank page with one empty tab.
    public static func blank(name: String = "صفحة جديدة") -> PageDefinition {
        PageDefinition(name: name, tabs: [PageTab(name: "الرئيسية")])
    }

    // MARK: Workout

    public static func workout() -> PageDefinition {
        func exercise(_ name: String) -> (Block, Block) {
            var sets = Block.make(.sets)
            sets.title = "المجموعات"
            sets.allowDecimal = true
            var box = Block.make(.container)
            box.title = name
            box.children = [sets, Block.make(.timer)]
            return (box, sets)
        }
        func tab(_ name: String, _ exercises: [String]) -> PageTab {
            var blocks: [Block] = []
            var firstSets: Block?
            for ex in exercises {
                let (box, sets) = exercise(ex)
                if firstSets == nil { firstSets = sets }
                blocks.append(box)
            }
            if let firstSets {
                var chart = Block.make(.chart)
                chart.title = "تطور \(exercises[0])"
                chart.sourceIDs = [firstSets.id]
                chart.metric = .setsMax
                blocks.append(chart)
            }
            var note = Block.make(.textField)
            note.title = "ملاحظات الجلسة"
            blocks.append(note)
            blocks.append(Block.make(.button))
            return PageTab(name: name, blocks: blocks)
        }
        return PageDefinition(
            name: "تمارين", emoji: "🏋️", accent: "green",
            tabs: [
                tab("Full Body A", [
                    "Machine Shoulder Press", "Lat Pulldown", "Wide Grip Row Machine", "Chest Fly Machine",
                    "Leg Extension", "Leg Press", "Crunch Machine"
                ]),
                tab("Full Body B", [
                    "Triceps Extension", "Machine Preacher Curl", "Machine Shoulder Press", "Crunch Machine",
                    "Leg Extension", "Seated Leg Curl", "Leg Press"
                ]),
                tab("Full Body C", [
                    "Lat Pulldown", "Chest Fly Machine", "Wide Grip Row Machine", "Triceps Extension",
                    "Machine Preacher Curl", "Seated Leg Curl", "Leg Press"
                ])
            ],
            rotatesTabs: true
        )
    }

    // MARK: Reading

    public static func reading() -> PageDefinition {
        var book = Block.make(.textField)
        book.title = "اسم الكتاب"
        book.multiline = false
        var pages = Block.make(.counter)
        pages.title = "صفحات اليوم"
        pages.step = 5
        pages.target = 20
        var bar = Block.make(.progress)
        bar.title = "هدف اليوم"
        bar.sourceIDs = [pages.id]
        var notes = Block.make(.textField)
        notes.title = "ملاحظات وفوائد"
        var chart = Block.make(.chart)
        chart.title = "الصفحات عبر الأيام"
        chart.sourceIDs = [pages.id]
        return PageDefinition(
            name: "قراءة", emoji: "📚", accent: "blue",
            tabs: [PageTab(name: "اليوم", blocks: [book, pages, bar, notes, Block.make(.button), chart])]
        )
    }

    // MARK: Water

    public static func water() -> PageDefinition {
        var cups = Block.make(.counter)
        cups.title = "أكواب الماء"
        cups.target = 8
        var bar = Block.make(.progress)
        bar.title = "الهدف اليومي"
        bar.sourceIDs = [cups.id]
        var finish = Block.make(.button)
        finish.title = "إنهاء اليوم"
        return PageDefinition(
            name: "شرب الماء", emoji: "💧", accent: "blue",
            tabs: [PageTab(name: "اليوم", blocks: [cups, bar, finish])]
        )
    }

    // MARK: Study

    public static func study() -> PageDefinition {
        var subject = Block.make(.choice)
        subject.title = "المادة"
        subject.options = ["رياضيات", "برمجة", "إنجليزي", "أخرى"]
        var watch = Block.make(.stopwatch)
        watch.title = "مدة المذاكرة"
        var focus = Block.make(.rating)
        focus.title = "التركيز"
        var notes = Block.make(.textField)
        notes.title = "وش ذاكرت؟"
        var chart = Block.make(.chart)
        chart.title = "مدة المذاكرة عبر الأيام"
        chart.sourceIDs = [watch.id]
        return PageDefinition(
            name: "مذاكرة", emoji: "🎓", accent: "purple",
            tabs: [PageTab(name: "جلسة", blocks: [subject, watch, focus, notes, Block.make(.button), chart])]
        )
    }

    // MARK: Calories

    public static func calories() -> PageDefinition {
        func heading(_ title: String) -> Block {
            var block = Block.make(.heading)
            block.title = title
            block.headingSize = .small
            return block
        }
        func goal(_ title: String, unit: String) -> Block {
            var block = Block.make(.number)
            block.title = title
            block.unit = unit
            block.allowDecimal = true
            block.showLast = false
            block.carryForward = true
            return block
        }
        /// Grams of a macro from the calorie goal and its percentage: calories × % ÷ 100 ÷ (calories per gram).
        func gramsGoal(_ title: String, calories: Block, percent: Block, perGram: Double) -> Block {
            var block = Block.make(.calc)
            block.title = title
            block.unit = "جم"
            block.calcOp = .product
            block.terms = [CalcTerm(blockID: calories.id), CalcTerm(blockID: percent.id)]
            block.calcScale = 1 / (100 * perGram)
            return block
        }

        let calorieGoal = goal("هدف السعرات اليومي", unit: "سعرة")
        let proteinPct = goal("نسبة البروتين", unit: "%")
        let carbsPct = goal("نسبة الكارب", unit: "%")
        let fatPct = goal("نسبة الدهون", unit: "%")
        let proteinGoal = gramsGoal("هدف البروتين", calories: calorieGoal, percent: proteinPct, perGram: 4)
        let carbsGoal = gramsGoal("هدف الكارب", calories: calorieGoal, percent: carbsPct, perGram: 4)
        let fatGoal = gramsGoal("هدف الدهون", calories: calorieGoal, percent: fatPct, perGram: 9)

        var tables: [Block] = []
        var meals: [Block] = []
        for name in ["الفطور", "الغداء", "العشاء", "سناك"] {
            var notes = Block.make(.textField)
            notes.title = "وصف الوجبة"
            notes.multiline = true
            var table = Block.make(.sets)
            table.title = "الأطعمة"
            table.columns = ["السعرات", "البروتين", "الكارب", "الدهون"]
            table.allowDecimal = true
            table.showLast = false
            var box = Block.make(.container)
            box.title = name
            box.children = [notes, table]
            tables.append(table)
            meals.append(box)
        }

        var search = Block.make(.nutrition)
        search.title = "ابحث عن أكلة"
        search.sourceIDs = meals.map(\.id)

        /// A total of one nutrient column across every meal, against a goal.
        func total(_ title: String, column: Int, unit: String, goal: Block, period: CalcPeriod) -> Block {
            var block = Block.make(.calc)
            block.title = title
            block.unit = unit
            block.calcPeriod = period
            block.terms = tables.map { CalcTerm(blockID: $0.id, column: column) }
            block.targetSourceID = goal.id
            return block
        }

        var assistant = Block.make(.ai)
        assistant.title = "اسأل عن أكلك"
        assistant.text = "أنت مرشد تغذية. تجاوب بالعربي وباختصار. تشوف أهداف المستخدم ووجباته اليوم، وتقترح عليه وش يكمل فيه يومه ليوصل أهدافه. الأرقام تقريبية وما تعطي نصيحة طبية."
        assistant.aiIncludesPageData = true

        let blocks: [Block] = [heading("أهدافي"), calorieGoal, proteinPct, carbsPct, fatPct, proteinGoal, carbsGoal, fatGoal,
                               heading("وجباتي")] + meals + [search,
                               heading("إجمالي اليوم"),
                               total("السعرات", column: 0, unit: "سعرة", goal: calorieGoal, period: .today),
                               total("البروتين", column: 1, unit: "جم", goal: proteinGoal, period: .today),
                               total("الكارب", column: 2, unit: "جم", goal: carbsGoal, period: .today),
                               total("الدهون", column: 3, unit: "جم", goal: fatGoal, period: .today),
                               heading("المتوسط الأسبوعي"),
                               total("متوسط السعرات", column: 0, unit: "سعرة", goal: calorieGoal, period: .weekAverage),
                               total("متوسط البروتين", column: 1, unit: "جم", goal: proteinGoal, period: .weekAverage),
                               total("متوسط الكارب", column: 2, unit: "جم", goal: carbsGoal, period: .weekAverage),
                               total("متوسط الدهون", column: 3, unit: "جم", goal: fatGoal, period: .weekAverage),
                               assistant]
        return PageDefinition(name: "سعراتي", emoji: "🥗", accent: "green", tabs: [PageTab(name: "اليوم", blocks: blocks)])
    }
}
