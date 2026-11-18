import HabitCore
import SwiftUI

/// "بحث تغذية": type what you ate, the AI finds calories and macros, and the rows go into the chosen meal's table.
struct NutritionBlockView: View {
    let block: Block
    let page: PageDefinition
    let runtime: PageRuntime

    @Environment(\.digitStyle) private var digits
    @State private var text = ""
    @State private var mealID: UUID?
    @State private var loading = false
    @State private var error: String?
    @State private var answer: NutritionStore.Answer?
    @State private var items: [NutritionItem] = []
    @State private var added = false

    /// The meals this block can fill: its chosen containers/tables that actually contain a sets table.
    private var meals: [Block] {
        block.sourceIDs.compactMap { id in page.allBlocks.first { $0.id == id } }
            .filter { setsTable(of: $0) != nil }
    }

    private func setsTable(of meal: Block) -> Block? {
        meal.kind == .sets ? meal : meal.children.flattened.first { $0.kind == .sets }
    }

    private func notesField(of meal: Block) -> Block? {
        meal.kind == .container ? meal.children.flattened.first { $0.kind == .textField } : nil
    }

    private var selectedMeal: Block? { meals.first { $0.id == mealID } ?? meals.first }

    private func fmt(_ value: Double) -> String { NumberFormatting.string((value * 10).rounded() / 10, style: digits) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(block.title.isEmpty ? "ابحث عن أكلة" : block.title, systemImage: "fork.knife")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textSecondary)

            if meals.isEmpty {
                Text("حدد الوجبات من وضع التعديل (كل وجبة مربع فيه جدول مجموعات).")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            } else {
                Picker("الوجبة", selection: Binding(get: { selectedMeal?.id ?? meals[0].id }, set: { mealID = $0 })) {
                    ForEach(meals) { Text($0.title.isEmpty ? "وجبة" : $0.title).tag($0.id) }
                }
                .pickerStyle(.menu)

                HStack(alignment: .bottom, spacing: 8) {
                    TextField("مثلاً: بيضتين مسلوقة وكوب رز", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                    Button(action: search) { Image(systemName: "magnifyingglass.circle.fill").font(.title) }
                        .disabled(loading || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if loading { ProgressView().frame(maxWidth: .infinity) }
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }

            if let answer, !items.isEmpty {
                ForEach(items) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.callout.weight(.semibold))
                            Text("\(fmt(item.kcal)) سعرة · بروتين \(fmt(item.protein)) · كارب \(fmt(item.carbs)) · دهون \(fmt(item.fat))")
                                .font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Button { items.removeAll { $0.id == item.id } } label: {
                            Image(systemName: "xmark.circle").foregroundStyle(Theme.danger)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Text(sourceNote(answer))
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                Button(added ? "انضافت ✓" : "أضف للوجبة", action: addToMeal)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                    .disabled(added || selectedMeal == nil)
            }
        }
    }

    private func sourceNote(_ answer: NutritionStore.Answer) -> String {
        var parts: [String] = []
        if answer.searched || !answer.result.sources.isEmpty {
            let hosts = answer.result.sources.compactMap { URL(string: $0)?.host }.prefix(2)
            parts.append(hosts.isEmpty ? "من البحث في الويب" : "من البحث: " + hosts.joined(separator: "، "))
        } else {
            parts.append("تقدير بدون بحث في الويب")
        }
        if answer.fromCache { parts.append("محفوظ من قبل") }
        parts.append("الأرقام تقريبية")
        return parts.joined(separator: " · ")
    }

    private func search() {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        loading = true; error = nil; added = false; answer = nil; items = []
        Task {
            do {
                let result = try await NutritionStore.lookup(query)
                answer = result
                items = result.result.items
            } catch let failure as AIChatError {
                error = failure == .badResponse ? "ما قدرت أفهم رد المساعد. أعد المحاولة أو اكتب الأكل بشكل أوضح." : AIChat.arabicReason(failure)
            } catch {
                self.error = AIChat.arabicReason(.network)
            }
            loading = false
        }
    }

    private func addToMeal() {
        guard let meal = selectedMeal, let sets = setsTable(of: meal), !items.isEmpty else { return }
        var rows: [SetRow] = []
        if case .rows(let existing)? = runtime.value(sets.id) { rows = existing }
        let columns = sets.columns.isEmpty ? ["القيمة"] : sets.columns
        for item in items { rows.append(NutritionLookup.row(for: item, columns: columns)) }
        runtime.set(.rows(rows), for: sets.id)

        if let notes = notesField(of: meal) {
            var current = ""
            if case .text(let existing)? = runtime.value(notes.id) { current = existing }
            let lines = items.map { "• " + $0.name }.joined(separator: "\n")
            runtime.set(.text(current.isEmpty ? lines : current + "\n" + lines), for: notes.id)
        }
        added = true
        text = ""
    }
}
