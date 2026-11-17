import SwiftUI

/// How to set up the Shortcuts automation that makes the app block work. iOS doesn't let an app create
/// automations by itself, so this is a short manual guide.
struct AppBlockGuideView: View {
    var body: some View {
        List {
            Section {
                Text("iOS ما يسمح لأي تطبيق يقفل تطبيقات ثانية، ولا يسوي الأتمتة بدالك. فنستخدم أتمتة في تطبيق الاختصارات: كل ما فتحت تطبيق من اللي تبي تقفله، تسأل «عاداتي»: «فيه قفل؟». إذا الجواب نعم تفتح «عاداتي» وتطلع شاشة «خلّص مهمتك أول»، وإذا لا ما تسوي شي ويفتح التطبيق عادي.")
                    .font(.callout)
            }

            Section("خطوات الأتمتة (مرة وحدة)") {
                step(1, "افتح تطبيق «الاختصارات» (Shortcuts) وروح لتبويب «الأتمتة» (Automation).")
                step(2, "اضغط «+» ثم اختر «التطبيق» (App).")
                step(3, "اختر التطبيقات اللي تبي تقفلها، وخل الخيار «تم فتحه» (Is Opened)، ثم «التالي».")
                step(4, "اضغط «إضافة إجراء» وابحث عن «عاداتي» واختر الأمر «فيه قفل؟».")
                step(5, "أضف إجراء «إذا» (If)، واجعل شرطه إن نتيجة «فيه قفل؟» تساوي «نعم» (Yes).")
                step(6, "داخل «إذا» أضف إجراء «فتح تطبيق» (Open App) واختر «عاداتي».")
                step(7, "اضغط «التالي»، واختر «تشغيل فوري» (Run Immediately) بدل «اسأل قبل التشغيل»، ثم «تم».")
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
