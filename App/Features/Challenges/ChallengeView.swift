import CoreMotion
import HabitCore
import SwiftUI

/// The full-screen challenge of a challenge alarm. It can't be dismissed until the challenge is done
/// (the chain of alarms keeps ringing meanwhile); only after the chain has ended can it be closed.
struct ChallengeView: View {
    let active: ActiveChallenge
    let onFinished: () -> Void
    let onClose: () -> Void

    @State private var challenge: AlarmChallenge
    @State private var fallbackNote: String?
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(active: ActiveChallenge, onFinished: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.active = active
        self.onFinished = onFinished
        self.onClose = onClose
        _challenge = State(initialValue: active.challenge)
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            if let fallbackNote {
                Text(fallbackNote)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if now >= active.expiresAt {
                Button("انتهت مهلة التحدي — إغلاق", action: onClose)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
        .onReceive(ticker) { now = $0 }
        .interactiveDismissDisabled()
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.primaryStrong)
                .accessibilityHidden(true)
            Text(active.title)
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("أكمل التحدي عشان يوقف المنبه")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch challenge.kind {
        case .math:
            MathChallengeView(level: challenge.mathLevel, total: challenge.questionCount, onSuccess: onFinished)
        case .steps:
            StepsChallengeView(target: challenge.stepCount, onSuccess: onFinished, onUnavailable: {
                useMath(String(localized: "عدّاد الخطوات مو متاح (أو ما أعطيت التطبيق إذن الحركة)، فبدلناه بمعادلات."))
            })
        case .typing:
            TypingChallengeView(onSuccess: onFinished)
        case .shake:
            ShakeChallengeView(target: challenge.shakeCount, onSuccess: onFinished, onUnavailable: {
                useMath(String(localized: "حساس الحركة مو متاح، فبدلناه بمعادلات."))
            })
        case .memory:
            MemoryChallengeView(length: challenge.memoryLength, onSuccess: onFinished)
        }
    }

    /// A phone that can't count steps or feel a shake must not trap the owner: switch to math.
    private func useMath(_ note: String) {
        fallbackNote = note
        challenge = AlarmChallenge(kind: .math, mathLevel: .medium, questionCount: 3)
    }
}

// MARK: - Math

private struct MathChallengeView: View {
    let level: MathLevel
    let total: Int
    let onSuccess: () -> Void

    @Environment(\.digitStyle) private var digits
    @State private var question: MathQuestion
    @State private var solved = 0
    @State private var answer = ""
    @State private var wrongTries = 0
    @FocusState private var focused: Bool

    init(level: MathLevel, total: Int, onSuccess: @escaping () -> Void) {
        self.level = level
        self.total = total
        self.onSuccess = onSuccess
        _question = State(initialValue: MathGenerator.question(level: level))
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(digits.format(String(localized: "السؤال \(solved + 1) من \(total)")))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            // Digits and operators always read left to right.
            Text("\u{200E}" + digits.format(question.text))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .environment(\.layoutDirection, .leftToRight)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            TextField("الجواب", text: $answer)
                .keyboardType(.numberPad)
                .focused($focused)
                .multilineTextAlignment(.center)
                .font(.title.bold())
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                .onSubmit(check)
            if wrongTries > 0 {
                Text("غلط، جرّب مرة ثانية")
                    .font(.callout.bold())
                    .foregroundStyle(Theme.danger)
            }
            Button(action: check) {
                Text("تحقق")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color.white)
            }
            .disabled(NumberFormatting.parse(answer) == nil)
            ProgressView(value: Double(solved), total: Double(total))
                .tint(Theme.primaryStrong)
        }
        .onAppear { focused = true }
        .sensoryFeedback(.error, trigger: wrongTries)
    }

    private func check() {
        guard let value = NumberFormatting.parse(answer) else { return }
        if Int(value.rounded()) == question.answer && value == value.rounded() {
            solved += 1
            answer = ""
            wrongTries = 0
            if solved >= total {
                onSuccess()
            } else {
                question = MathGenerator.question(level: level)
            }
        } else {
            wrongTries += 1
            answer = ""
        }
    }
}

// MARK: - Steps

private struct StepsChallengeView: View {
    let target: Int
    let onSuccess: () -> Void
    let onUnavailable: () -> Void

    @Environment(\.digitStyle) private var digits
    @State private var steps = 0
    @State private var pedometer = CMPedometer()
    @State private var finished = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "figure.walk")
                .font(.system(size: 52))
                .foregroundStyle(Theme.primaryStrong)
                .accessibilityHidden(true)
            Text(digits.format("\(min(steps, target)) / \(target)"))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .environment(\.layoutDirection, .leftToRight)
            Text("قم وامشِ، والجوال معك. العدّاد يبدأ من الحين.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            ProgressView(value: Double(min(steps, target)), total: Double(target))
                .tint(Theme.primaryStrong)
        }
        .task { start() }
        .onDisappear { pedometer.stopUpdates() }
    }

    private func start() {
        let status = CMPedometer.authorizationStatus()
        guard CMPedometer.isStepCountingAvailable(), status != .denied, status != .restricted else {
            onUnavailable()
            return
        }
        let startDate = Date()
        pedometer.startUpdates(from: startDate) { data, error in
            DispatchQueue.main.async {
                if error != nil, data == nil, steps == 0 {
                    // Typically "motion permission refused" the first time it is asked.
                    if CMPedometer.authorizationStatus() == .denied { onUnavailable() }
                    return
                }
                guard let data else { return }
                steps = data.numberOfSteps.intValue
                if steps >= target, !finished {
                    finished = true
                    pedometer.stopUpdates()
                    onSuccess()
                }
            }
        }
    }
}

// MARK: - Typing

private struct TypingChallengeView: View {
    let onSuccess: () -> Void

    @State private var phrase: String
    @State private var text = ""
    @FocusState private var focused: Bool

    init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
        var rng = SystemRandomNumberGenerator()
        _phrase = State(initialValue: TypingChallenge.phrase(using: &rng))
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("اكتب هذي الجملة بالضبط")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Text(phrase)
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            TextField("اكتب هنا", text: $text, axis: .vertical)
                .focused($focused)
                .autocorrectionDisabled()
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                .onChange(of: text) { _, value in
                    if TypingChallenge.matches(value, phrase: phrase) { onSuccess() }
                }
        }
        .onAppear { focused = true }
    }
}

// MARK: - Shake

private struct ShakeChallengeView: View {
    let target: Int
    let onSuccess: () -> Void
    let onUnavailable: () -> Void

    @State private var shakes = 0
    @State private var motion = CMMotionManager()
    @State private var lastShake = Date.distantPast
    @State private var finished = false
    @Environment(\.digitStyle) private var digits

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 52))
                .foregroundStyle(Theme.primaryStrong)
                .accessibilityHidden(true)
            Text(digits.format("\(min(shakes, target)) / \(target)"))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .environment(\.layoutDirection, .leftToRight)
            Text("هز الجوال بقوة")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
            ProgressView(value: Double(min(shakes, target)), total: Double(target))
                .tint(Theme.primaryStrong)
        }
        .task { start() }
        .onDisappear { motion.stopAccelerometerUpdates() }
    }

    private func start() {
        guard motion.isAccelerometerAvailable else {
            onUnavailable()
            return
        }
        motion.accelerometerUpdateInterval = 1.0 / 30.0
        motion.startAccelerometerUpdates(to: .main) { data, _ in
            guard let a = data?.acceleration, !finished else { return }
            let force = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            let nowDate = Date()
            if force > 2.2, nowDate.timeIntervalSince(lastShake) > 0.3 {
                lastShake = nowDate
                shakes += 1
                if shakes >= target {
                    finished = true
                    motion.stopAccelerometerUpdates()
                    onSuccess()
                }
            }
        }
    }
}

// MARK: - Memory

private struct MemoryChallengeView: View {
    let length: Int
    let onSuccess: () -> Void

    private enum Phase { case showing, entering }

    @State private var sequence: String
    @State private var phase: Phase = .showing
    @State private var answer = ""
    @State private var wrongTries = 0
    @FocusState private var focused: Bool
    @Environment(\.digitStyle) private var digits

    init(length: Int, onSuccess: @escaping () -> Void) {
        self.length = length
        self.onSuccess = onSuccess
        var rng = SystemRandomNumberGenerator()
        _sequence = State(initialValue: MemoryChallenge.sequence(length: length, using: &rng))
    }

    var body: some View {
        VStack(spacing: 18) {
            switch phase {
            case .showing:
                Text("احفظ الأرقام")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Text("\u{200E}" + digits.format(sequence))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                ProgressView().tint(Theme.primaryStrong)
            case .entering:
                Text("اكتب الأرقام اللي شفتها")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                TextField("الأرقام", text: $answer)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .multilineTextAlignment(.center)
                    .font(.title.bold())
                    .padding(12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                if wrongTries > 0 {
                    Text("غلط، بنعرض لك أرقام جديدة")
                        .font(.callout.bold())
                        .foregroundStyle(Theme.danger)
                }
                Button(action: check) {
                    Text("تحقق")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Color.white)
                }
                .disabled(answer.isEmpty)
            }
        }
        .task(id: sequence) {
            phase = .showing
            try? await Task.sleep(for: .seconds(4))
            phase = .entering
            focused = true
        }
    }

    private func check() {
        let typed = digitsOnly(answer)
        if typed == sequence {
            onSuccess()
        } else {
            wrongTries += 1
            answer = ""
            var rng = SystemRandomNumberGenerator()
            sequence = MemoryChallenge.sequence(length: length, using: &rng)
        }
    }

    /// Accepts Arabic-Indic digits too.
    private func digitsOnly(_ text: String) -> String {
        let mapped = text.map { character -> Character in
            if let value = character.wholeNumberValue, character.isNumber { return Character(String(value)) }
            return character
        }
        return String(mapped).filter { $0.isASCII && $0.isNumber }
    }
}
