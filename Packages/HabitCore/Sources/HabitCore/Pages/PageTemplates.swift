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
        Info(id: "study", name: "مذاكرة", emoji: "🎓", summary: "ساعة إيقاف، اختيار المادة، وملاحظات")
    ]

    public static func make(_ id: String) -> PageDefinition? {
        switch id {
        case "workout": return workout()
        case "reading": return reading()
        case "water": return water()
        case "study": return study()
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
}
