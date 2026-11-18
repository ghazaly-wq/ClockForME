import Charts
import HabitCore
import SwiftUI

/// One block in "use" mode: the owner reads it and fills it in. Containers render their children.
struct BlockUseView: View {
    let block: Block
    let page: PageDefinition
    let runtime: PageRuntime
    var nested = false
    let perform: (ButtonAction) -> Void

    @Environment(\.digitStyle) private var digits
    @Environment(AppRouter.self) private var router
    @State private var expanded = true

    var body: some View {
        switch block.kind {
        case .heading: heading
        case .text:
            Text(block.text)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .divider: Divider().padding(.vertical, 4)
        case .container: container
        case .textField: card { textFieldBlock }
        case .number: card { numberBlock }
        case .sets: card { setsBlock }
        case .counter: card { counterBlock }
        case .checkbox: card { checkboxBlock }
        case .checklist: card { checklistBlock }
        case .choice: card { choiceBlock }
        case .rating: card { ratingBlock }
        case .dateTime: card { dateBlock }
        case .timer: card { timerBlock }
        case .stopwatch: card { stopwatchBlock }
        case .progress: card { progressBlock }
        case .chart: card { chartBlock }
        case .history: card { historyBlock }
        case .image: imageBlock
        case .link: linkBlock
        case .button: buttonBlock
        case .ai: card { AIBlockView(block: block, page: page, runtime: runtime) }
        case .calc: card { CalcBlockView(block: block, page: page, runtime: runtime) }
        case .nutrition: card { NutritionBlockView(block: block, page: page, runtime: runtime) }
        }
    }

    // MARK: - Shared pieces

    private func fmt(_ value: Double) -> String { NumberFormatting.string(value, style: digits) }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if nested {
            VStack(alignment: .leading, spacing: 8) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) { content() }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.bold())
            .foregroundStyle(Theme.textSecondary)
    }

    @ViewBuilder
    private var lastHint: some View {
        if block.showLast, let value = runtime.last(block.id), !value.isEmpty {
            Text("آخر مرة: " + PageValueText.text(value, block: block, digits: digits))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var lastPlaceholder: String {
        guard block.showLast, let value = runtime.last(block.id), !value.isEmpty else { return "" }
        return PageValueText.text(value, block: block, digits: digits)
    }

    // MARK: - Layout blocks

    private var heading: some View {
        Text(block.title)
            .font(block.headingSize == .large ? .title2.bold() : (block.headingSize == .medium ? .title3.bold() : .headline))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 4)
    }

    private var container: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Text(block.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expanded ? 0 : 90))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(expanded ? "مفتوح" : "مغلق"))

            if expanded {
                ForEach(block.children) { child in
                    AnyView(BlockUseView(block: child, page: page, runtime: runtime, nested: true, perform: perform))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .onAppear { expanded = !block.collapsed }
    }

    // MARK: - Input blocks

    private var textBinding: Binding<String> {
        Binding(
            get: { if case .text(let s)? = runtime.value(block.id) { return s } else { return "" } },
            set: { newValue in runtime.set(newValue.isEmpty ? nil : .text(newValue), for: block.id) }
        )
    }

    private var numberBinding: Binding<Double?> {
        Binding(
            get: { runtime.value(block.id)?.asNumber },
            set: { newValue in runtime.set(newValue.map { BlockValue.number($0) }, for: block.id) }
        )
    }

    @ViewBuilder
    private var textFieldBlock: some View {
        label(block.title)
        TextField(lastPlaceholder.isEmpty ? "اكتب هنا" : lastPlaceholder, text: textBinding, axis: .vertical)
            .lineLimit(block.multiline ? 2...8 : 1...2)
            .padding(10)
            .frame(minHeight: 44, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var numberBlock: some View {
        label(block.title)
        HStack(spacing: 8) {
            NumberInput(placeholder: lastPlaceholder.isEmpty ? "٠" : lastPlaceholder, allowDecimal: block.allowDecimal, value: numberBinding)
                .padding(10)
                .frame(minHeight: 44)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            if !block.unit.isEmpty {
                Text(block.unit).font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
        }
        lastHint
    }

    @ViewBuilder
    private var counterBlock: some View {
        let current = runtime.number(block.id)
        label(block.title)
        HStack(spacing: 16) {
            stepButton(symbol: "minus.circle.fill", name: "إنقاص") {
                runtime.set(.number(max(0, current - block.step)), for: block.id)
            }
            VStack(spacing: 2) {
                Text(fmt(current))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                if let target = block.target {
                    Text("من \(fmt(target))")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else if !block.unit.isEmpty {
                    Text(block.unit).font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            stepButton(symbol: "plus.circle.fill", name: "زيادة") {
                runtime.set(.number(current + block.step), for: block.id)
            }
        }
        .sensoryFeedback(.selection, trigger: current)
        lastHint
    }

    private func stepButton(symbol: String, name: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 36))
                .foregroundStyle(Theme.primaryStrong)
                .frame(width: 52, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name))
    }

    private var checked: Bool {
        if case .bool(let b)? = runtime.value(block.id) { return b }
        return false
    }

    @ViewBuilder
    private var checkboxBlock: some View {
        Button {
            runtime.set(.bool(!checked), for: block.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(checked ? Theme.primaryStrong : Theme.textSecondary)
                Text(block.title)
                    .font(.body)
                    .strikethrough(checked)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: checked)
    }

    private func flagValue(_ index: Int) -> Bool {
        if case .flags(let flags)? = runtime.value(block.id), flags.indices.contains(index) { return flags[index] }
        return false
    }

    private func toggleFlag(_ index: Int) {
        var flags: [Bool] = []
        if case .flags(let existing)? = runtime.value(block.id) { flags = existing }
        while flags.count < block.options.count { flags.append(false) }
        guard flags.indices.contains(index) else { return }
        flags[index].toggle()
        runtime.set(.flags(flags), for: block.id)
    }

    @ViewBuilder
    private var checklistBlock: some View {
        label(block.title)
        ForEach(block.options.indices, id: \.self) { index in
            let isOn = flagValue(index)
            Button { toggleFlag(index) } label: {
                HStack(spacing: 10) {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isOn ? Theme.primaryStrong : Theme.textSecondary)
                    Text(block.options[index])
                        .strikethrough(isOn)
                        .foregroundStyle(isOn ? Theme.textSecondary : Theme.textPrimary)
                    Spacer()
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }

    private var selectedChoices: [Int] {
        if case .choices(let list)? = runtime.value(block.id) { return list }
        return []
    }

    private func toggleChoice(_ index: Int) {
        var list = selectedChoices
        if block.multiSelect {
            if let at = list.firstIndex(of: index) { list.remove(at: at) } else { list.append(index) }
        } else {
            list = list == [index] ? [] : [index]
        }
        runtime.set(list.isEmpty ? nil : .choices(list), for: block.id)
    }

    @ViewBuilder
    private var choiceBlock: some View {
        label(block.title)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(block.options.indices, id: \.self) { index in
                ChoiceChip(label: block.options[index], isSelected: selectedChoices.contains(index)) {
                    toggleChoice(index)
                }
            }
        }
        lastHint
    }

    @ViewBuilder
    private var ratingBlock: some View {
        let current = Int(runtime.number(block.id))
        label(block.title)
        HStack(spacing: 4) {
            ForEach(1...max(block.maxRating, 1), id: \.self) { star in
                Button {
                    runtime.set(star == current ? nil : .number(Double(star)), for: block.id)
                } label: {
                    Image(systemName: star <= current ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(Theme.gold)
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(digits.format(star)) من \(digits.format(block.maxRating))"))
            }
        }
        .sensoryFeedback(.selection, trigger: current)
    }

    @ViewBuilder
    private var dateBlock: some View {
        label(block.title)
        if case .date(let date)? = runtime.value(block.id) {
            HStack {
                DatePicker(
                    block.title,
                    selection: Binding(get: { date }, set: { runtime.set(.date($0), for: block.id) }),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                Spacer()
                Button("مسح") { runtime.set(nil, for: block.id) }
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.primaryStrong)
                    .frame(minHeight: 44)
            }
        } else {
            Button("تحديد الوقت الآن") { runtime.set(.date(Date()), for: block.id) }
                .buttonStyle(.bordered)
                .tint(Theme.primaryStrong)
        }
    }

    // MARK: - Sets table

    private var setColumns: [String] { block.columns.isEmpty ? ["القيمة"] : block.columns }

    private var rows: [SetRow] {
        if case .rows(let r)? = runtime.value(block.id) { return r }
        return []
    }

    private func store(_ newRows: [SetRow]) {
        runtime.set(.rows(newRows), for: block.id)
    }

    private func cellBinding(_ row: Int, _ column: Int) -> Binding<Double?> {
        Binding(
            get: {
                let list = rows
                guard list.indices.contains(row), list[row].values.indices.contains(column) else { return nil }
                return list[row].values[column]
            },
            set: { newValue in
                var list = rows
                guard list.indices.contains(row) else { return }
                var values = list[row].values
                while values.count < setColumns.count { values.append(nil) }
                values[column] = newValue
                list[row] = SetRow(values: values)
                store(list)
            }
        )
    }

    @ViewBuilder
    private var setsBlock: some View {
        let placeholders = PageLogic.placeholderRows(from: runtime.last(block.id))
        label(block.title)
        HStack(spacing: 8) {
            Text("#").frame(width: 24)
            ForEach(setColumns.indices, id: \.self) { column in
                Text(setColumns[column]).frame(maxWidth: .infinity)
            }
            Color.clear.frame(width: 44, height: 1)
        }
        .font(.caption.bold())
        .foregroundStyle(Theme.textSecondary)

        ForEach(rows.indices, id: \.self) { row in
            HStack(spacing: 8) {
                Text(digits.format(row + 1))
                    .font(.subheadline.bold())
                    .frame(width: 24)
                    .foregroundStyle(Theme.textSecondary)
                ForEach(setColumns.indices, id: \.self) { column in
                    NumberInput(
                        placeholder: placeholder(placeholders, row, column),
                        allowDecimal: true,
                        value: cellBinding(row, column)
                    )
                    .padding(8)
                    .frame(minHeight: 44)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                }
                Button {
                    var list = rows
                    if list.indices.contains(row) { list.remove(at: row) }
                    store(list)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(Theme.danger)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("حذف المجموعة"))
            }
        }

        HStack {
            Button {
                var list = rows
                list.append(SetRow(values: Array(repeating: nil, count: setColumns.count)))
                store(list)
            } label: {
                Label("إضافة مجموعة", systemImage: "plus")
                    .font(.subheadline.bold())
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.primaryStrong)
            Spacer()
            if rows.isEmpty, !placeholders.isEmpty, block.showLast {
                Button {
                    store(placeholders.map { SetRow(values: Array(repeating: nil, count: $0.values.count)) })
                } label: {
                    Label("بنفس عدد مجموعات آخر مرة", systemImage: "doc.on.doc")
                        .font(.caption.bold())
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.primaryStrong)
            }
        }
    }

    private func placeholder(_ rows: [SetRow], _ row: Int, _ column: Int) -> String {
        guard block.showLast, rows.indices.contains(row), rows[row].values.indices.contains(column),
              let value = rows[row].values[column] else { return "–" }
        return fmt(value)
    }

    // MARK: - Time

    @ViewBuilder
    private var timerBlock: some View {
        label(block.title)
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = runtime.remaining(block.id, now: context.date)
            HStack(spacing: 12) {
                Image(systemName: remaining == 0 ? "checkmark.circle.fill" : "timer")
                    .font(.title2)
                    .foregroundStyle(Theme.primaryStrong)
                    .accessibilityHidden(true)
                Text(digits.format(NumberFormatting.clock(seconds: remaining ?? Double(block.seconds))))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                if remaining == 0 {
                    Text("انتهى").font(.subheadline.bold()).foregroundStyle(Theme.primaryStrong)
                }
                Spacer()
                if let remaining, remaining > 0 {
                    Button("إيقاف") { runtime.stopTimer(block.id) }
                        .buttonStyle(.bordered)
                        .tint(Theme.primaryStrong)
                } else {
                    Button(remaining == 0 ? "إعادة" : "ابدأ") { runtime.startTimer(block) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .sensoryFeedback(.success, trigger: remaining == 0)
        }
    }

    @ViewBuilder
    private var stopwatchBlock: some View {
        label(block.title)
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let running = runtime.isRunning(block.id)
            HStack(spacing: 12) {
                Text(digits.format(NumberFormatting.clock(seconds: runtime.elapsed(block.id, now: context.date))))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !running, runtime.number(block.id) > 0 {
                    Button("تصفير") { runtime.resetStopwatch(block.id) }
                        .buttonStyle(.bordered)
                        .tint(Theme.textSecondary)
                }
                Button(running ? "إيقاف" : "ابدأ") { runtime.toggleStopwatch(block.id, now: Date()) }
                    .buttonStyle(.borderedProminent)
            }
        }
        lastHint
    }

    // MARK: - Display blocks

    private func source(_ index: Int = 0) -> Block? {
        guard block.sourceIDs.indices.contains(index) else { return nil }
        let id = block.sourceIDs[index]
        return page.allBlocks.first { $0.id == id }
    }

    @ViewBuilder
    private var progressBlock: some View {
        let sources = block.sourceIDs.compactMap { id in page.allBlocks.first { $0.id == id } }
        let value = sources.reduce(0) { $0 + runtime.number($1.id) }
        let target = PageLogic.combinedTarget(explicit: block.target, sourceTargets: sources.map(\.target))
        let fraction = PageLogic.progress(value: value, target: target)
        label(block.title)
        if sources.isEmpty {
            Text("اختر الرقم اللي يتابعه الشريط من وضع التعديل.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.textSecondary.opacity(0.2))
                    Capsule().fill(Theme.primary).frame(width: max(proxy.size.width * fraction, fraction > 0 ? 14 : 0))
                }
            }
            .frame(height: 14)
            .animation(.spring(duration: 0.35), value: fraction)
            HStack {
                Text(target.map { "\(fmt(value)) من \(fmt($0))" } ?? fmt(value))
                    .font(.callout.bold())
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if target != nil {
                    Text(digits.format("\(Int((fraction * 100).rounded()))٪"))
                        .font(.callout.bold())
                        .foregroundStyle(Theme.primaryStrong)
                }
            }
            if sources.count > 1 {
                // What each followed counter contributes.
                ForEach(sources) { src in
                    HStack {
                        Text(src.title.isEmpty ? src.kind.arabicName : src.title)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(fmt(runtime.number(src.id)))
                            .font(.caption.bold())
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var chartBlock: some View {
        label(block.title)
        if let src = source() {
            let points = PageLogic.series(of: src.id, metric: block.metric, in: runtime.history, pageID: page.id)
            if points.isEmpty {
                Text("ما فيه سجل للرسم بعد. أنهِ جلسة وبيظهر هنا.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Chart(points, id: \.day) { point in
                    LineMark(x: .value("اليوم", PageValueText.date(of: point.day)), y: .value("القيمة", point.value))
                        .foregroundStyle(Theme.primaryStrong)
                    PointMark(x: .value("اليوم", PageValueText.date(of: point.day)), y: .value("القيمة", point.value))
                        .foregroundStyle(Theme.primaryStrong)
                }
                .frame(height: 180)
                .accessibilityLabel(Text(block.title))
                .accessibilityValue(Text(points.last.map { "آخر قيمة \(fmt($0.value))" } ?? ""))
            }
        } else {
            Text("اختر القطعة اللي يرسمها الرسم من وضع التعديل.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var historyBlock: some View {
        label(block.title)
        let sources = block.sourceIDs.compactMap { id in page.allBlocks.first { $0.id == id } }
        let sessions = Array(PageLogic.finished(runtime.history, pageID: page.id).reversed().prefix(8))
        if sources.isEmpty {
            Text("اختر القطع اللي يعرضها السجل من وضع التعديل.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        } else if sessions.isEmpty {
            Text("ما فيه جلسات منتهية بعد.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        } else {
            ForEach(sessions) { session in
                VStack(alignment: .leading, spacing: 2) {
                    Text(digits.format(PageValueText.date(of: session.day).formatted(date: .abbreviated, time: .omitted)))
                        .font(.caption.bold())
                        .foregroundStyle(Theme.primaryStrong)
                    ForEach(sources) { src in
                        if let value = session.value(for: src.id), !value.isEmpty {
                            Text(src.title + ": " + PageValueText.text(value, block: src, digits: digits))
                                .font(.callout)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
                .padding(.vertical, 2)
                Divider()
            }
        }
    }

    // MARK: - Media, links, buttons

    @ViewBuilder
    private var imageBlock: some View {
        if let image = PageImageStore.load(block.imageFile) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text(block.title))
        } else {
            Text("لا توجد صورة بعد (تضاف من وضع التعديل).")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var linkBlock: some View {
        let title = block.title.isEmpty ? "فتح" : block.title
        if let pageID = block.linkPageID {
            Button { router.openPageID = pageID } label: {
                Label(title, systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Theme.primaryStrong)
        } else if !block.linkURL.isEmpty, let url = URL(string: block.linkURL) {
            Link(destination: url) {
                Label(title, systemImage: "link")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Theme.primaryStrong)
        } else {
            Text("حدد وجهة الرابط من وضع التعديل.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var buttonBlock: some View {
        if let action = block.action {
            Button { perform(action) } label: {
                Text(block.title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Text("حدد وش يسوي الزر من وضع التعديل.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
