import SwiftUI

/// Curved bottom bar with a raised circular Home button in the center.
/// Tabs navigate (never act), have Arabic labels, and give selection haptics.
struct CurvedTabBar: View {
    @Binding var selection: AppTab

    // Right-to-left layout: the first item of an HStack sits on the right.
    private let rightTabs: [AppTab] = [.tasks, .alarms]
    private let leftTabs: [AppTab] = [.achievements, .pages]

    var body: some View {
        ZStack(alignment: .top) {
            BottomBarArcShape()
                .fill(Theme.barMuted)
                .ignoresSafeArea(edges: .bottom)

            // Tabs sit on the arc: lower and tilted toward the sides, following the bar's curve.
            GeometryReader { geo in
                let w = geo.size.width
                let slot = (w - Metrics.homeRingDiameter) / 4
                GlassEffectContainer(spacing: 8) {
                    ZStack(alignment: .topLeading) {
                        arcTab(.tasks, x: w - slot * 0.5, width: w)
                        arcTab(.alarms, x: w - slot * 1.5, width: w)
                        arcTab(.achievements, x: slot * 1.5, width: w)
                        arcTab(.pages, x: slot * 0.5, width: w)
                    }
                }
            }
            .frame(height: Metrics.barHeight)

            homeButton
                .offset(y: -Metrics.homeRingDiameter / 2)
        }
        .frame(height: Metrics.barHeight)
        // Keep the bar usable at accessibility text sizes.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .sensoryFeedback(.selection, trigger: selection)
    }

    /// Places a tab at `x`, on the same quadratic arc as `BottomBarArcShape`:
    /// y = rise * (1 - 2u)^2 with u = x / width, tilted by the arc's slope there.
    private func arcTab(_ tab: AppTab, x: CGFloat, width: CGFloat) -> some View {
        let u = x / width
        let rise = Metrics.barRise
        let curveY = rise * pow(1 - 2 * u, 2)
        let slope = -4 * rise * (1 - 2 * u) / width
        let angle = Angle(radians: Double(atan(slope)))
        let h: CGFloat = 50
        let slot = (width - Metrics.homeRingDiameter) / 4
        return tabButton(tab)
            .frame(width: slot, height: h)
            .rotationEffect(angle)
            .position(x: x, y: curveY + 10 + h / 2)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isSelected ? tab.selectedSymbol : tab.symbol)
                    .font(.title3)
                Text(tab.title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Color.white.opacity(isSelected ? 1 : 0.85))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(
                isSelected ? .regular.tint(Theme.primary.opacity(0.9)).interactive() : .regular.interactive(),
                in: Capsule()
            )
            .padding(.horizontal, 3)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var homeButton: some View {
        Button {
            selection = .home
        } label: {
            ZStack {
                // Surface-colored ring: looks like a circular notch cut into the bar.
                Circle()
                    .fill(Theme.surface)
                    .frame(width: Metrics.homeRingDiameter, height: Metrics.homeRingDiameter)
                Circle()
                    .fill(Theme.primary)
                    .frame(width: Metrics.homeButtonDiameter, height: Metrics.homeButtonDiameter)
                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                Image(systemName: "house.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppTab.home.title))
        .accessibilityAddTraits(selection == .home ? .isSelected : [])
    }
}
