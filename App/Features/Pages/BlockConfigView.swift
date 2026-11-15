import HabitCore
import PhotosUI
import SwiftData
import SwiftUI

/// Settings of one block (title, unit, options, which block a chart reads, what a button does...).
struct BlockConfigView: View {
    @Binding var page: PageDefinition
    let blockID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.digitStyle) private var digits
    @Query private var tasks: [TaskRecord]
    @Query private var alarms: [AlarmRecord]
    @Query private var pageRecords: [PageRecord]
    @State private var photoItem: PhotosPickerItem?

    private var block: Binding<Block> {
        Binding(
            get: { page.allBlocks.first { $0.id == blockID } ?? Block.make(.text) },
            set: { newValue in
                for index in page.tabs.indices {
                    page.tabs[index].blocks = page.tabs[index].blocks.updating(blockID) { $0 = newValue }
                }
            }
        )
    }

    var body: some View {
        let b = block
        NavigationStack {
            Form {
                kindSection(b)
            }
            .navigationTitle(b.wrappedValue.kind.arabicName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Per kind

    @ViewBuilder
    private func kindSection(_ b: Binding<Block>) -> some View {
        switch b.wrappedValue.kind {
        case .heading:
            Section {
                TextField("نص العنوان", text: b.title)
                Picker("الحجم", selection: b.headingSize) {
                    ForEach(HeadingSize.allCases, id: \.self) { Text($0.arabicName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        case .text:
            Section("النص") {
                TextField("اكتب النص", text: b.text, axis: .vertical).lineLimit(2...10)
            }
        case .divider:
            Section { Text("فاصل بسيط بين القطع.").foregroundStyle(Theme.textSecondary) }
        case .container:
            Section {
                TextField("اسم المربع", text: b.title)
                Toggle("يبدأ مطوياً", isOn: b.collapsed)
            }
        case .textField:
            Section {
                TextField("الاسم", text: b.title)
                Toggle("عدة أسطر", isOn: b.multiline)
                Toggle("أظهر آخر قيمة كتلميح", isOn: b.showLast)
            }
        case .number:
            Section {
                TextField("الاسم", text: b.title)
                TextField("الوحدة (كجم، صفحة، دقيقة...)", text: b.unit)
                Toggle("يقبل الكسور", isOn: b.allowDecimal)
                Toggle("أظهر آخر قيمة كتلميح", isOn: b.showLast)
            }
        case .sets:
            Section {
                TextField("الاسم", text: b.title)
                Toggle("أظهر مجموعات آخر مرة كتلميح", isOn: b.showLast)
            }
            listEditor("الأعمدة", add: "إضافة عمود", items: b.columns, limit: 3, minimum: 1)
        case .counter:
            Section {
                TextField("الاسم", text: b.title)
                numberRow("حجم الخطوة", value: Binding(get: { b.wrappedValue.step }, set: { b.wrappedValue.step = max($0 ?? 1, 0.1) }), decimal: true)
                numberRow("الهدف (اختياري)", value: b.target, decimal: true)
                TextField("الوحدة (اختياري)", text: b.unit)
                Toggle("أظهر آخر قيمة كتلميح", isOn: b.showLast)
            }
        case .checkbox:
            Section { TextField("النص", text: b.title) }
        case .checklist:
            Section { TextField("الاسم", text: b.title) }
            listEditor("العناصر", add: "إضافة عنصر", items: b.options, limit: 40, minimum: 1)
        case .choice:
            Section {
                TextField("الاسم", text: b.title)
                Toggle("أكثر من اختيار", isOn: b.multiSelect)
            }
            listEditor("الخيارات", add: "إضافة خيار", items: b.options, limit: 20, minimum: 2)
        case .rating:
            Section {
                TextField("الاسم", text: b.title)
                Stepper("أعلى تقييم: \(digits.format(b.wrappedValue.maxRating))", value: b.maxRating, in: 3...10)
            }
        case .dateTime, .stopwatch:
            Section { TextField("الاسم", text: b.title) }
        case .timer:
            Section {
                TextField("الاسم", text: b.title)
                Stepper(
                    "المدة: " + digits.format(NumberFormatting.clock(seconds: Double(b.wrappedValue.seconds))),
                    value: b.seconds, in: 5...7200, step: 5
                )
            } footer: {
                Text("لما ينتهي المؤقت يجيك إشعار حتى لو التطبيق مقفل.")
            }
        case .progress:
            Section {
                TextField("الاسم", text: b.title)
                numberRow("الهدف (اختياري، وإلا مجموع أهداف العدادات)", value: b.target, decimal: true)
            } footer: {
                Text("تقدر تربط الشريط بأكثر من عداد: الشريط يجمع قيمهم.")
            }
            Section("العدادات اللي يتابعها") {
                let candidates = page.allBlocks.filter { $0.kind.isNumeric }
                if candidates.isEmpty {
                    Text("أضف عداداً أو رقماً أول.")
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(candidates) { candidate in
                    Button {
                        var ids = b.wrappedValue.sourceIDs
                        if let at = ids.firstIndex(of: candidate.id) { ids.remove(at: at) } else { ids.append(candidate.id) }
                        b.wrappedValue.sourceIDs = ids
                    } label: {
                        HStack {
                            Text(name(of: candidate)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if b.wrappedValue.sourceIDs.contains(candidate.id) {
                                Image(systemName: "checkmark").foregroundStyle(Theme.primaryStrong)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityAddTraits(b.wrappedValue.sourceIDs.contains(candidate.id) ? .isSelected : [])
                }
            }
        case .chart:
            Section {
                TextField("الاسم", text: b.title)
                sourcePicker(b, title: "يرسم", candidates: page.allBlocks.filter { $0.kind.isChartable })
                if let source = page.allBlocks.first(where: { $0.id == b.wrappedValue.sourceIDs.first }), source.kind == .sets {
                    Picker("القياس", selection: b.metric) {
                        ForEach([ChartMetric.setsMax, .setsVolume, .setsTotal], id: \.self) { Text($0.arabicName).tag($0) }
                    }
                }
            }
        case .history:
            Section { TextField("الاسم", text: b.title) }
            Section("القطع المعروضة") {
                ForEach(page.allBlocks.filter { $0.kind.isInput }) { candidate in
                    Button {
                        var ids = b.wrappedValue.sourceIDs
                        if let at = ids.firstIndex(of: candidate.id) { ids.remove(at: at) } else { ids.append(candidate.id) }
                        b.wrappedValue.sourceIDs = ids
                    } label: {
                        HStack {
                            Text(name(of: candidate)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if b.wrappedValue.sourceIDs.contains(candidate.id) {
                                Image(systemName: "checkmark").foregroundStyle(Theme.primaryStrong)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        case .image:
            imageSection(b)
        case .link:
            linkSection(b)
        case .button:
            buttonSection(b)
        }
    }

    private func name(of block: Block) -> String {
        let title = block.title.isEmpty ? block.kind.arabicName : block.title
        let tab = page.tabs.first { $0.blocks.flattened.contains { $0.id == block.id } }?.name ?? ""
        return tab.isEmpty ? title : "\(title) · \(tab)"
    }

    // MARK: - Helpers

    private func numberRow(_ title: String, value: Binding<Double?>, decimal: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            NumberInput(placeholder: "—", allowDecimal: decimal, value: value)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 44)
    }

    private func sourcePicker(_ b: Binding<Block>, title: String, candidates: [Block]) -> some View {
        Picker(title, selection: Binding<UUID?>(
            get: { b.wrappedValue.sourceIDs.first },
            set: { newValue in
                b.wrappedValue.sourceIDs = newValue.map { [$0] } ?? []
                if let id = newValue, let src = page.allBlocks.first(where: { $0.id == id }) {
                    b.wrappedValue.metric = src.kind == .sets ? .setsMax : .value
                }
            }
        )) {
            Text("بدون").tag(UUID?.none)
            ForEach(candidates) { candidate in
                Text(name(of: candidate)).tag(UUID?.some(candidate.id))
            }
        }
    }

    /// Editable list of short texts (options, checklist items, table columns).
    @ViewBuilder
    private func listEditor(_ title: String, add: String, items: Binding<[String]>, limit: Int, minimum: Int) -> some View {
        Section(title) {
            ForEach(items.wrappedValue.indices, id: \.self) { index in
                TextField("نص", text: Binding(
                    get: { items.wrappedValue.indices.contains(index) ? items.wrappedValue[index] : "" },
                    set: { if items.wrappedValue.indices.contains(index) { items.wrappedValue[index] = $0 } }
                ))
            }
            .onDelete { offsets in
                guard items.wrappedValue.count - offsets.count >= minimum else { return }
                items.wrappedValue.remove(atOffsets: offsets)
            }
            if items.wrappedValue.count < limit {
                Button(add) { items.wrappedValue.append("") }
                    .frame(minHeight: 44)
            }
        }
    }

    // MARK: - Image

    @ViewBuilder
    private func imageSection(_ b: Binding<Block>) -> some View {
        Section {
            TextField("الوصف (لقارئ الشاشة)", text: b.title)
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(b.wrappedValue.imageFile.isEmpty ? "اختيار صورة" : "تغيير الصورة", systemImage: "photo")
                    .frame(minHeight: 44)
            }
            if let image = PageImageStore.load(b.wrappedValue.imageFile) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(maxHeight: 180)
            }
        } footer: {
            Text("الصورة تنحفظ داخل التطبيق فقط.")
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let name = PageImageStore.save(image) {
                    let old = b.wrappedValue.imageFile
                    b.wrappedValue.imageFile = name
                    PageImageStore.remove(old)
                }
                photoItem = nil
            }
        }
    }

    // MARK: - Link

    private enum LinkKind: Hashable { case web, page }

    @ViewBuilder
    private func linkSection(_ b: Binding<Block>) -> some View {
        let kind = Binding<LinkKind>(
            get: { b.wrappedValue.linkPageID != nil ? .page : .web },
            set: { newValue in
                if newValue == .page {
                    b.wrappedValue.linkPageID = pageRecords.first { !$0.isTemplate && $0.id != page.id }?.id
                    b.wrappedValue.linkURL = ""
                } else {
                    b.wrappedValue.linkPageID = nil
                }
            }
        )
        Section {
            TextField("نص الرابط", text: b.title)
            Picker("الوجهة", selection: kind) {
                Text("موقع").tag(LinkKind.web)
                Text("صفحة").tag(LinkKind.page)
            }
            .pickerStyle(.segmented)
            if kind.wrappedValue == .web {
                TextField("https://...", text: b.linkURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .environment(\.layoutDirection, .leftToRight)
            } else {
                let others = pageRecords.filter { !$0.isTemplate && $0.id != page.id }
                if others.isEmpty {
                    Text("ما عندك صفحات ثانية.").foregroundStyle(Theme.textSecondary)
                } else {
                    Picker("الصفحة", selection: Binding<UUID?>(
                        get: { b.wrappedValue.linkPageID },
                        set: { b.wrappedValue.linkPageID = $0 }
                    )) {
                        ForEach(others) { record in
                            Text(record.definition.emoji + " " + record.definition.name).tag(UUID?.some(record.id))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Button

    private enum ActionKind: String, CaseIterable, Identifiable {
        case finish, completeTask, startTimer, openPage, openAlarm, addTask, clear
        var id: String { rawValue }
        var arabic: String {
            switch self {
            case .finish: return "إنهاء الجلسة"
            case .completeTask: return "إكمال مهمة"
            case .startTimer: return "بدء مؤقت"
            case .openPage: return "فتح صفحة"
            case .openAlarm: return "فتح تنبيه"
            case .addTask: return "إضافة مهمة فرعية"
            case .clear: return "مسح الحقول"
            }
        }
    }

    private func kind(of action: ButtonAction?) -> ActionKind {
        switch action {
        case .finishSession, .none: return .finish
        case .completeTask: return .completeTask
        case .startTimer: return .startTimer
        case .openPage: return .openPage
        case .openAlarm: return .openAlarm
        case .addSecondaryTask: return .addTask
        case .clearFields: return .clear
        }
    }

    @ViewBuilder
    private func buttonSection(_ b: Binding<Block>) -> some View {
        let activeTasks = tasks.filter { $0.endDay == nil }
        let timers = page.allBlocks.filter { $0.kind == .timer }
        let otherPages = pageRecords.filter { !$0.isTemplate && $0.id != page.id }
        Section {
            TextField("نص الزر", text: b.title)
            Picker("وش يسوي؟", selection: Binding<ActionKind>(
                get: { kind(of: b.wrappedValue.action) },
                set: { newKind in
                    switch newKind {
                    case .finish: b.wrappedValue.action = .finishSession
                    case .completeTask: b.wrappedValue.action = .completeTask(activeTasks.first?.id ?? UUID())
                    case .startTimer: b.wrappedValue.action = .startTimer(timers.first?.id ?? UUID())
                    case .openPage: b.wrappedValue.action = .openPage(otherPages.first?.id ?? UUID())
                    case .openAlarm: b.wrappedValue.action = .openAlarm(alarms.first?.id ?? UUID())
                    case .addTask: b.wrappedValue.action = .addSecondaryTask(b.wrappedValue.title)
                    case .clear: b.wrappedValue.action = .clearFields
                    }
                }
            )) {
                ForEach(ActionKind.allCases) { Text($0.arabic).tag($0) }
            }
            actionDetail(b, tasks: activeTasks, timers: timers, pages: otherPages)
        } footer: {
            if kind(of: b.wrappedValue.action) == .finish {
                Text("يحفظ الجلسة، ولو الصفحة مهمة رئيسية يكمّل مهمة اليوم (تنحسب الخبرة والستريك).")
            }
        }
    }

    @ViewBuilder
    private func actionDetail(_ b: Binding<Block>, tasks: [TaskRecord], timers: [Block], pages: [PageRecord]) -> some View {
        switch b.wrappedValue.action {
        case .completeTask(let id):
            if tasks.isEmpty {
                Text("ما عندك مهمات.").foregroundStyle(Theme.textSecondary)
            } else {
                Picker("المهمة", selection: Binding<UUID>(get: { id }, set: { b.wrappedValue.action = .completeTask($0) })) {
                    ForEach(tasks) { Text($0.title).tag($0.id) }
                }
            }
        case .startTimer(let id):
            if timers.isEmpty {
                Text("أضف قطعة مؤقت للصفحة أول.").foregroundStyle(Theme.textSecondary)
            } else {
                Picker("المؤقت", selection: Binding<UUID>(get: { id }, set: { b.wrappedValue.action = .startTimer($0) })) {
                    ForEach(timers) { Text(name(of: $0)).tag($0.id) }
                }
            }
        case .openPage(let id):
            if pages.isEmpty {
                Text("ما عندك صفحات ثانية.").foregroundStyle(Theme.textSecondary)
            } else {
                Picker("الصفحة", selection: Binding<UUID>(get: { id }, set: { b.wrappedValue.action = .openPage($0) })) {
                    ForEach(pages) { Text($0.definition.emoji + " " + $0.definition.name).tag($0.id) }
                }
            }
        case .openAlarm(let id):
            if alarms.isEmpty {
                Text("ما عندك تنبيهات.").foregroundStyle(Theme.textSecondary)
            } else {
                Picker("التنبيه", selection: Binding<UUID>(get: { id }, set: { b.wrappedValue.action = .openAlarm($0) })) {
                    ForEach(alarms) { Text($0.title).tag($0.id) }
                }
            }
        case .addSecondaryTask(let title):
            TextField("اسم المهمة", text: Binding<String>(get: { title }, set: { b.wrappedValue.action = .addSecondaryTask($0) }))
        default:
            EmptyView()
        }
    }
}
