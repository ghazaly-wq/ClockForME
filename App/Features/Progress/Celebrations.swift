import HabitCore
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

    @AppStorage(SettingsKey.equippedEffect) private var effectID = ShopCatalog.defaultEffect
    @State private var fall = false
    @State private var pieces: [Piece] = (0..<44).map { _ in Piece() }

    private var colors: [Color] {
        switch effectID {
        case "effect.gold": return [Theme.gold, Color.yellow, Theme.gold.opacity(0.7), Color.orange]
        case "effect.hearts": return [Color.red, Color.pink, Color.red.opacity(0.7), Color.pink.opacity(0.8)]
        case "effect.bubbles": return [Color.cyan, Color.blue.opacity(0.6), Color.cyan.opacity(0.6), Theme.primary.opacity(0.7)]
        case "effect.flames": return [Color.orange, Color.red, Color.yellow, Color.orange.opacity(0.7)]
        default: return [Theme.primary, Theme.gold, Theme.primaryStrong, Theme.barMuted]
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    pieceShape(piece)
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

    /// SF Symbol used as the falling piece for each symbol-based effect.
    static func symbol(for effectID: String) -> String? {
        switch effectID {
        case "effect.stars": return "star.fill"
        case "effect.hearts": return "heart.fill"
        case "effect.flames": return "flame.fill"
        default: return nil
        }
    }

    @ViewBuilder
    private func pieceShape(_ piece: Piece) -> some View {
        if let symbol = Self.symbol(for: effectID) {
            Image(systemName: symbol)
                .font(.system(size: piece.width * 1.8))
                .foregroundStyle(colors[piece.colorIndex])
        } else if effectID == "effect.bubbles" {
            Circle()
                .strokeBorder(colors[piece.colorIndex], lineWidth: 2)
                .frame(width: piece.width * 2, height: piece.width * 2)
        } else {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(colors[piece.colorIndex])
                .frame(width: piece.width, height: piece.width * 1.6)
        }
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

/// Shown when one or more achievements are unlocked.
struct AchievementUnlockSheet: View {
    let info: UnlockInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.digitStyle) private var digits
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()
            if !reduceMotion { ConfettiView() }
            VStack(spacing: 18) {
                Text(info.achievements.count == 1 ? "إنجاز جديد!" : "إنجازات جديدة!")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(info.achievements) { def in
                            HStack(spacing: 12) {
                                Image(systemName: def.symbol)
                                    .font(.title2)
                                    .foregroundStyle(Color.black.opacity(0.85))
                                    .frame(width: 48, height: 48)
                                    .background(Theme.gold, in: Circle())
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(def.name)
                                        .font(.headline)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(def.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.textSecondary)
                                    Text(digits.format(String(localized: "+\(def.xp) خبرة · +\(def.points) نقطة")))
                                        .font(.caption.bold().monospacedDigit())
                                        .foregroundStyle(Theme.primaryStrong)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("تم")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
