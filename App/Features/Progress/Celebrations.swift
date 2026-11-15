import SwiftUI
import UIKit

/// Confetti that falls once. Purely decorative.
struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let x = CGFloat.random(in: 0...1)
        let width = CGFloat.random(in: 6...11)
        let delay = Double.random(in: 0...0.7)
        let duration = Double.random(in: 1.6...2.6)
        let rotation = Double.random(in: 180...720)
        let colorIndex = Int.random(in: 0..<4)
    }

    @State private var fall = false
    @State private var pieces: [Piece] = (0..<44).map { _ in Piece() }

    private var colors: [Color] { [Theme.primary, Theme.gold, Theme.primaryStrong, Theme.barMuted] }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(colors[piece.colorIndex])
                        .frame(width: piece.width, height: piece.width * 1.6)
                        .rotationEffect(.degrees(fall ? piece.rotation : 0))
                        .position(
                            x: piece.x * proxy.size.width,
                            y: fall ? proxy.size.height + 40 : -40
                        )
                        .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: fall)
                }
            }
        }
        .onAppear { fall = true }
        .accessibilityHidden(true)
    }
}

/// Shown when every main task of the day is done: confetti + a short banner.
/// With Reduce Motion on, only the banner fades in.
struct DayCompleteOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if !reduceMotion {
                ConfettiView()
            }
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(.largeTitle))
                    .foregroundStyle(Theme.gold)
                Text("أنجزت كل مهماتك اليوم 🎉")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 12, y: 6)
            .padding(.horizontal, 32)
            .accessibilityElement(children: .combine)
        }
        .allowsHitTesting(false)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

/// Level-up sheet: big level number, the title and a success haptic.
struct LevelUpSheet: View {
    let info: LevelUpInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.digitStyle) private var digits

    var body: some View {
        VStack(spacing: 20) {
            Text("مستوى جديد!")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)

            ZStack {
                Circle().fill(Theme.gold)
                Text(digits.format(info.level))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.black.opacity(0.85))
            }
            .frame(width: 140, height: 140)
            .accessibilityHidden(true)

            Text(info.title.arabicName)
                .font(.title.bold())
                .foregroundStyle(Theme.primaryStrong)

            Button {
                dismiss()
            } label: {
                Text("تم")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.ignoresSafeArea())
        .presentationDetents([.medium])
        .accessibilityElement(children: .contain)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
