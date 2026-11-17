import SwiftUI

/// How to set up the Shortcuts automation that makes the app block work. iOS doesn't let an app create
/// automations by itself, so this is a short manual guide.
struct AppBlockGuideView: View {
    var body: some View {
        List {
            Section {
                Text("iOS ما يسمح لأي تطبيق يقفل تطبيقات ثانية، ولا يسوي الأتمتة بدالك. فنستخدم حيلة: أتمتة في تطبيق الاختصارات تفتح «عاداتي» كل ما فتحت تطبيق من اللي تبي تقفله. وإذا عندك مهمة عليها القفل ولسا ما خلصتها، تطلع لك شاشة «خلّص مهمتك أول».")
                    .font(.callout)
            }

            Section("خطوات الأتمتة (مرة وحدة)") {
                step(1, "افتح تطبيق «الاختصارات» (Shortcuts) وروح لتبويب «الأتمتة» (Automation).")
                step(2, "اضغط «+» ثم اختر «التطبيق» (App).")
                step(3, "اختر التطبيقات اللي تبي تقفلها، وخل الخيار «تم فتحه» (Is Opened).")
                step(4, "اضغط «التالي» ثم «إضافة إجراء» وابحث عن «فتح تطبيق» (Open App) واختر «عاداتي».")
                step(5, "اضغط «التالي»، واختر «تشغيل فوري» (Run Immediately) بدل «اسأل قبل التشغيل»، وشغّل «إشعار عند التشغيل» لو تبي تطفيه.")
                step(6, "اضغط «تم».")
            }

            Section {
                Text("القفل يشتغل بس على المهام اللي فعّلت لها «اقفل التطبيقات لين أخلصها» (تلقاها في محرر المهمة لما يكون لها تنبيه). تبدأ تقفل من وقت تنبيه المهمة، وتفك لما تخلصها.")
                Text("لو تبي توقف كل شي مؤقتاً، طفّي «قفل التطبيقات» من الإعدادات. الأتمتة تظل شغالة بس ما تطلع الشاشة.")
            } header: {
                Text("ملاحظات")
            }
        }
        .navigationTitle("كيف أفعّل القفل؟")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Theme.primary, in: Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
        }
        .padding(.vertical, 2)
    }
}
