import SwiftUI

/// One place for how screens move, so everything feels the same and honours Reduce Motion
/// (a quick fade instead of sliding).
private struct MotionTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let edge: Edge

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity))
    }
}

private struct AppAnimation<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? .easeInOut(duration: 0.15) : .snappy(duration: 0.35), value: value)
    }
}

extension View {
    /// Slides in from / out to `edge` (leading = the right side in this RTL app), fading too.
    func motionTransition(edge: Edge) -> some View {
        modifier(MotionTransition(edge: edge))
    }

    /// The standard animation for in-place screen changes.
    func appAnimation<Value: Equatable>(value: Value) -> some View {
        modifier(AppAnimation(value: value))
    }
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
