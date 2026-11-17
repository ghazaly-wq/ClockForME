import HabitCore
import SwiftUI

/// The "مساعد ذكي" block in use mode: a small chat whose behaviour is set by the block's system prompt.
/// The conversation lives only while the page is open.
struct AIBlockView: View {
    let block: Block
    let page: PageDefinition
    let runtime: PageRuntime

    @State private var messages: [AIMessage] = []
    @State private var question = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(block.title.isEmpty ? "اسأل المساعد" : block.title, systemImage: "sparkles")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if !messages.isEmpty {
                    Button("محادثة جديدة") { messages = []; error = nil }
                        .font(.footnote)
                        .buttonStyle(.borderless)
                }
            }

            ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                Text(message.text)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        message.role == .user ? Color(uiColor: .tertiarySystemFill) : Theme.primary.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }

            if loading { ProgressView().frame(maxWidth: .infinity) }
            if let error {
                Text(error).font(.footnote).foregroundStyle(Theme.danger)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("اكتب سؤالك", text: $question, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(loading || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var systemPrompt: String {
        var text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if block.aiIncludesPageData {
            let data = AIPageContext.summary(blocks: page.allBlocks, session: runtime.session)
            if !data.isEmpty {
                text += (text.isEmpty ? "" : "\n\n") + "البيانات اللي كتبها المستخدم في الصفحة الحين:\n" + data
            }
        }
        return text
    }

    private func send() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(AIMessage(role: .user, text: text))
        question = ""
        error = nil
        loading = true
        let history = messages
        let system = systemPrompt
        Task {
            do {
                let result = try await AIClient.ask(system: system.isEmpty ? nil : system, messages: history)
                messages.append(AIMessage(role: .assistant, text: result.text))
            } catch let failure as AIChatError {
                error = AIChat.arabicReason(failure)
            } catch {
                self.error = AIChat.arabicReason(.network)
            }
            loading = false
        }
    }
}
