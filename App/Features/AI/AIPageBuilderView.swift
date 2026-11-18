import HabitCore
import SwiftUI

/// "Build a page with AI": describe the page, preview what the AI designed, ask for changes, then save it.
struct AIPageBuilderView: View {
    let onSave: (PageDefinition) -> Void

    @State private var request = ""
    @State private var conversation: [AIMessage] = []   // user, assistant, user, assistant …
    @State private var draft: PageDefinition?
    @State private var tabIndex = 0
    @State private var loading = false
    @State private var error: String?

    private var hasKeys: Bool { !AIKeyStore.load().entries.isEmpty }

    var body: some View {
        List {
            if !hasKeys {
                Section {
                    Text("تحتاج تضيف مفتاح ذكاء اصطناعي أول من الإعدادات ← مفاتيح الذكاء الاصطناعي.")
                        .foregroundStyle(Theme.danger)
                }
            }

            Section {
                TextField(
                    draft == nil
                        ? "مثلاً: صفحة لتمرين الصدر فيها جدول مجموعات ومؤقت راحة ورسم لتطور الوزن"
                        : "اكتب التعديل اللي تبيه (مثلاً: أضف تمرين تفتيح)",
                    text: $request, axis: .vertical
                )
                .lineLimit(2...8)

                Button(action: submit) {
                    HStack {
                        if loading { ProgressView() }
                        Text(draft == nil ? "ابنِ الصفحة" : "طبّق التعديل")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(loading || !hasKeys || request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let error {
                    Text(error).font(.footnote).foregroundStyle(Theme.danger)
                }
            } header: {
                Text(draft == nil ? "وش تبي الصفحة تكون؟" : "تعديل")
            } footer: {
                Text("الذكاء الاصطناعي يصمم الصفحة من القطع الموجودة، وتقدر تعدّلها بعد الحفظ مثل أي صفحة. التنبيه والجدول تضيفهم بنفسك بعدين.")
            }

            if let draft {
                Section("المعاينة") {
                    HStack(spacing: 12) {
                        Text(draft.emoji).font(.largeTitle)
                        Text(draft.name).font(.title3.bold())
                    }
                    if draft.tabs.count > 1 {
                        Picker("التبويب", selection: $tabIndex) {
                            ForEach(Array(draft.tabs.enumerated()), id: \.element.id) { index, tab in
                                Text(tab.name).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    preview(of: draft)
                }

                Section {
                    Button {
                        onSave(draft)
                    } label: {
                        Text("احفظ الصفحة").frame(maxWidth: .infinity).bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("صفحة بالذكاء الاصطناعي")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A non-interactive look at the page as it will appear in use mode.
    @ViewBuilder
    private func preview(of page: PageDefinition) -> some View {
        let index = min(tabIndex, max(page.tabs.count - 1, 0))
        if page.tabs.indices.contains(index) {
            let tab = page.tabs[index]
            let runtime = PageRuntime(
                session: PageSession(pageID: page.id, tabID: tab.id, day: DayKey(date: Date(), calendar: Calendar.app)),
                history: []
            )
            VStack(spacing: 10) {
                ForEach(tab.blocks) { block in
                    BlockUseView(block: block, page: page, runtime: runtime, perform: { _ in })
                }
            }
            .allowsHitTesting(false)
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
    }

    private func submit() {
        let text = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        loading = true
        error = nil
        var messages = conversation
        messages.append(AIMessage(role: .user, text: text))
        Task {
            do {
                let result = try await AIClient.ask(system: AIPageBuilder.systemPrompt, messages: messages, maxTokens: 8000)
                switch AIPageBuilder.page(from: result.text) {
                case .success(let page):
                    conversation = messages + [AIMessage(role: .assistant, text: result.text)]
                    draft = page
                    tabIndex = 0
                    request = ""
                case .failure(let problem):
                    switch problem {
                    case .noJSON: error = "المساعد ما رجّع صفحة (رد نصي بس). أعد المحاولة أو وضّح الطلب."
                    case .badJSON: error = "رد المساعد انقطع أو فيه خطأ في الصياغة. أعد المحاولة، ولو تكرر قصّر الطلب."
                    case .empty: error = "المساعد رجّع صفحة بدون قطع مدعومة. وضّح وش القطع اللي تبيها."
                    }
                }
            } catch let failure as AIChatError {
                error = AIChat.arabicReason(failure)
            } catch {
                self.error = AIChat.arabicReason(.network)
            }
            loading = false
        }
    }
}
