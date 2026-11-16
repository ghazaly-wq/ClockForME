import HabitCore
import SwiftUI

/// Names of the challenges and their levels (shared by the editor and the challenge screen).
enum ChallengeText {
    static func name(of kind: ChallengeKind) -> String {
        switch kind {
        case .math: return String(localized: "معادلات")
        case .steps: return String(localized: "مشي")
        case .typing: return String(localized: "كتابة جملة")
        case .shake: return String(localized: "هز الجوال")
        case .memory: return String(localized: "ذاكرة أرقام")
        }
    }

    static func name(of level: MathLevel) -> String {
        switch level {
        case .easy: return String(localized: "سهل")
        case .medium: return String(localized: "متوسط")
        case .hard: return String(localized: "صعب")
        }
    }

    /// One line for the alarm list: "تحدي: معادلات (سهل)".
    static func summary(of challenge: AlarmChallenge, digits: DigitStyle) -> String {
        switch challenge.kind {
        case .math: return String(localized: "تحدي: معادلات (\(name(of: challenge.mathLevel)))")
        case .steps: return digits.format(String(localized: "تحدي: مشي \(challenge.stepCount) خطوة"))
        case .typing, .shake, .memory: return String(localized: "تحدي: ") + name(of: challenge.kind)
        }
    }
}

/// The two Form sections of an alarm: "تحدي لإيقاف المنبه" and "زر الإيقاف يفتح...".
/// Shared by the alarm editor and the schedule fields of a task or a page. Both only apply to a ringing alarm.
struct ChallengeSection: View {
    @Binding var challenge: AlarmChallenge?
    @Binding var destination: StopDestination?
    let delivery: AlarmDelivery

    @Environment(\.digitStyle) private var digits

    var body: some View {
        if delivery == .alarm {
            challengeSection
            destinationSection
        }
    }

    // MARK: - Challenge

    private var challengeOn: Binding<Bool> {
        Binding(
            get: { challenge != nil },
            set: { challenge = $0 ? (challenge ?? AlarmChallenge()) : nil }
        )
    }

    private var kind: Binding<ChallengeKind> {
        Binding(get: { challenge?.kind ?? .math }, set: { challenge?.kind = $0 })
    }

    private var mathLevel: Binding<MathLevel> {
        Binding(get: { challenge?.mathLevel ?? .easy }, set: { challenge?.mathLevel = $0 })
    }

    @ViewBuilder
    private var challengeSection: some View {
        Section {
            Toggle("تحدي لإيقاف المنبه", isOn: challengeOn.animation())
            if let current = challenge {
                Picker("نوع التحدي", selection: kind) {
                    ForEach(ChallengeKind.allCases, id: \.self) { Text(ChallengeText.name(of: $0)).tag($0) }
                }
                switch current.kind {
                case .math:
                    Picker("المستوى", selection: mathLevel) {
                        ForEach(MathLevel.allCases, id: \.self) { Text(ChallengeText.name(of: $0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Stepper(
                        digits.format(String(localized: "عدد المعادلات: \(current.questionCount)")),
                        value: Binding(get: { current.questionCount }, set: { challenge?.questionCount = $0 }),
                        in: AlarmChallenge.questionsRange
                    )
                case .steps:
                    Stepper(
                        digits.format(String(localized: "عدد الخطوات: \(current.stepCount)")),
                        value: Binding(get: { current.stepCount }, set: { challenge = challenge?.settingSteps($0) }),
                        in: AlarmChallenge.stepsRange, step: 10
                    )
                case .shake:
                    Stepper(
                        digits.format(String(localized: "عدد الهزات: \(current.shakeCount)")),
                        value: Binding(get: { current.shakeCount }, set: { challenge?.shakeCount = $0 }),
                        in: AlarmChallenge.shakeRange, step: 5
                    )
                case .memory:
                    Stepper(
                        digits.format(String(localized: "عدد الأرقام: \(current.memoryLength)")),
                        value: Binding(get: { current.memoryLength }, set: { challenge?.memoryLength = $0 }),
                        in: AlarmChallenge.memoryRange
                    )
                case .typing:
                    EmptyView()
                }
            }
        } header: {
            Text("التحدي")
        } footer: {
            Text(challenge == nil
                 ? "اخلِ المنبه ما يوقف إلا إذا أكملت تحدي."
                 : "إذا أوقفت المنبه بدون ما تكمل التحدي يرن مرة ثانية بعد دقيقة، لين 10 مرات. ما فيه تأجيل.")
        }
    }

    // MARK: - Destination

    private var destinationOn: Binding<Bool> {
        Binding(
            get: { destination != nil },
            set: { destination = $0 ? (destination ?? StopDestination(kind: .link, value: "")) : nil }
        )
    }

    private var destinationKind: Binding<StopDestinationKind> {
        Binding(get: { destination?.kind ?? .link }, set: { destination?.kind = $0 })
    }

    private var destinationValue: Binding<String> {
        Binding(get: { destination?.value ?? "" }, set: { destination?.value = $0 })
    }

    @ViewBuilder
    private var destinationSection: some View {
        Section {
            Toggle("زر الإيقاف يفتح موقع أو تطبيق", isOn: destinationOn.animation())
            if let current = destination {
                Picker("النوع", selection: destinationKind) {
                    Text("رابط").tag(StopDestinationKind.link)
                    Text("اختصار").tag(StopDestinationKind.shortcut)
                }
                .pickerStyle(.segmented)
                TextField(current.kind == .link ? "youtube.com" : "اسم الاختصار", text: destinationValue)
                    .keyboardType(current.kind == .link ? .URL : .default)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !current.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !current.isValid {
                    Text("الرابط مو صالح.")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            }
        } header: {
            Text("بعد الإيقاف")
        } footer: {
            Text(footerText)
        }
    }

    private var footerText: LocalizedStringKey {
        guard let destination else { return "الافتراضي: يفتح التطبيق." }
        switch destination.kind {
        case .link: return "موقع (youtube.com) أو رابط تطبيق (مثل whatsapp://). يفتح بعد التحدي إذا فيه تحدي."
        case .shortcut: return "اسم اختصار سويته في تطبيق الاختصارات، وهو اللي يفتح أي تطبيق تبيه. يفتح بعد التحدي إذا فيه تحدي."
        }
    }
}
