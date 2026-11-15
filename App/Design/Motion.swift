import SwiftUI

/// How screens move. Following Apple's motion guidance: brief, purposeful, nothing slow on
/// frequent actions, and a plain cross-fade instead of movement when Reduce Motion is on.
///
/// - Switching tabs is frequent, so it is only a quick cross-dissolve (like the system TabView).
/// - Opening a page from the list is a push: the new screen comes in from the forward edge
///   (the left in this RTL app) while the old one drifts back a little.
/// - Switching modes or sub-tabs inside a screen is a short fade.
private struct Shift: ViewModifier {
    let x: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.offset(x: x).opacity(opacity)
    }
}

private struct PushDetail: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .zIndex(1)
            .transition(reduceMotion ? .opacity : .move(edge: .trailing))
    }
}

private struct PushBackground: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(
            reduceMotion
                ? .opacity
                // The screen underneath drifts toward the back edge (to the right in RTL) and dims.
                : .modifier(active: Shift(x: 90, opacity: 0.35), identity: Shift(x: 0, opacity: 1))
        )
    }
}

private struct PushAnimation<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .easeInOut(duration: 0.15) : .smooth(duration: 0.4), value: value)
    }
}

private struct FadeAnimation<Value: Equatable>: ViewModifier {
    let value: Value

    func body(content: Content) -> some View {
        content.animation(.easeInOut(duration: 0.2), value: value)
    }
}

extension View {
    /// The screen that opens on top (a page's detail). Pair with `pushAnimation`.
    func pushDetailTransition() -> some View { modifier(PushDetail()) }

    /// The screen underneath that the detail opens over.
    func pushBackgroundTransition() -> some View { modifier(PushBackground()) }

    func pushAnimation<Value: Equatable>(value: Value) -> some View { modifier(PushAnimation(value: value)) }

    /// A short cross-fade for switching content inside a screen.
    func fadeAnimation<Value: Equatable>(value: Value) -> some View { modifier(FadeAnimation(value: value)) }
}

extension AppTab {
    /// Position in the bar, from right to left (the order of the RTL bar).
    var order: Int {
        switch self {
        case .tasks: return 0
        case .alarms: return 1
        case .home: return 2
        case .achievements: return 3
        case .pages: return 4
        }
    }

    /// The tab next to this one in the bar; `step` is -1 (toward the right) or +1 (toward the left).
    func neighbor(_ step: Int) -> AppTab? {
        AppTab.allCases.first { $0.order == order + step }
    }
}
