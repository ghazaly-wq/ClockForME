import HabitCore
import SwiftUI

/// One step of "how do I get a key", drawn as a small mock of what the user will see.
struct GuideStep: Identifiable {
    let id = UUID()
    let text: String
    let symbol: String      // SF Symbol shown in the illustration
    let mock: String        // the label the user will look for on screen
}

extension AIProvider {
    var steps: [GuideStep] {
        switch self {
        case .google: [
            GuideStep(text: "افتح صفحة Google AI Studio وسجّل دخول بحساب Google.", symbol: "person.crop.circle", mock: "Sign in with Google"),
            GuideStep(text: "اضغط «Create API key» (إنشاء مفتاح).", symbol: "plus.circle.fill", mock: "Create API key"),
            GuideStep(text: "اختر مشروع (أو اترك الافتراضي) واضغط «Create».", symbol: "folder.fill", mock: "Select a project"),
            GuideStep(text: "انسخ المفتاح اللي يبدأ بـ AIza (أيقونة النسخ جنبه).", symbol: "doc.on.doc.fill", mock: "AIza••••••••"),
        ]
        case .openai: [
            GuideStep(text: "افتح صفحة OpenAI API keys وسجّل دخول. تحتاج حساب API فيه رصيد (منفصل عن اشتراك ChatGPT).", symbol: "person.crop.circle", mock: "Log in"),
            GuideStep(text: "اضغط «Create new secret key».", symbol: "plus.circle.fill", mock: "Create new secret key"),
            GuideStep(text: "سمّه أي اسم (مثلاً Habits) واضغط «Create secret key».", symbol: "textformat", mock: "Name: Habits"),
            GuideStep(text: "انسخ المفتاح اللي يبدأ بـ sk- فوراً. ما يظهر لك مرة ثانية.", symbol: "doc.on.doc.fill", mock: "sk-••••••••"),
        ]
        case .kimi: [
            GuideStep(text: "افتح منصة Moonshot (Kimi) وسجّل دخول أو سوّ حساب.", symbol: "person.crop.circle", mock: "Sign in"),
            GuideStep(text: "من القائمة اختر «API Keys».", symbol: "key.fill", mock: "API Keys"),
            GuideStep(text: "اضغط «Create API Key» وسمّه أي اسم.", symbol: "plus.circle.fill", mock: "Create API Key"),
            GuideStep(text: "انسخ المفتاح اللي يبدأ بـ sk- فوراً.", symbol: "doc.on.doc.fill", mock: "sk-••••••••"),
        ]
        case .qwen: [
            GuideStep(text: "افتح Alibaba Cloud Model Studio وسجّل دخول أو سوّ حساب.", symbol: "person.crop.circle", mock: "Sign in"),
            GuideStep(text: "فعّل الخدمة لو طلب منك، ثم اختر «API Key».", symbol: "key.fill", mock: "API Key"),
            GuideStep(text: "اضغط «Create API Key».", symbol: "plus.circle.fill", mock: "Create API Key"),
            GuideStep(text: "انسخ المفتاح اللي يبدأ بـ sk-.", symbol: "doc.on.doc.fill", mock: "sk-••••••••"),
        ]
        case .deepseek: [
            GuideStep(text: "افتح منصة DeepSeek وسجّل دخول أو سوّ حساب.", symbol: "person.crop.circle", mock: "Sign in"),
            GuideStep(text: "من القائمة اختر «API keys».", symbol: "key.fill", mock: "API keys"),
            GuideStep(text: "اضغط «Create new API key» وسمّه أي اسم.", symbol: "plus.circle.fill", mock: "Create new API key"),
            GuideStep(text: "انسخ المفتاح اللي يبدأ بـ sk- فوراً. ما يظهر لك مرة ثانية.", symbol: "doc.on.doc.fill", mock: "sk-••••••••"),
        ]
        }
    }

    var costNote: String {
        switch self {
        case .google: "فيه طبقة مجانية بحدود يومية."
        case .openai: "مدفوع بالاستخدام وتحتاج رصيد في حساب API."
        case .kimi: "مدفوع بالاستخدام، وأحياناً فيه رصيد تجريبي."
        case .qwen: "مدفوع بالاستخدام، وأحياناً فيه رصيد تجريبي."
        case .deepseek: "رخيص، مدفوع بالاستخدام وتحتاج رصيد."
        }
    }
}

/// Illustrated, numbered steps for the chosen provider, plus a button that opens its key page.
struct AIProviderGuideView: View {
    let provider: AIProvider
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("كيف أجيب مفتاح \(provider.displayName)؟")
                .font(.headline)
            Text(provider.costNote)
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(Array(provider.steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Theme.primary, in: Circle())
                    VStack(alignment: .leading, spacing: 8) {
                        Text(step.text).font(.callout)
                        mock(step)
                    }
                }
            }

            if let url = URL(string: provider.keyPageURL) {
                Button {
                    openURL(url)
                } label: {
                    Label("افتح صفحة المفتاح", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
            }
        }
        .padding(.vertical, 4)
    }

    /// A tiny drawing of the control the user should look for.
    private func mock(_ step: GuideStep) -> some View {
        HStack(spacing: 8) {
            Image(systemName: step.symbol)
                .foregroundStyle(Theme.primary)
            Text(step.mock)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .environment(\.layoutDirection, .leftToRight)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(uiColor: .separator), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}
