import SwiftUI

/// Curved bottom bar with a raised circular Home button in the center.
/// Tabs navigate (never act), have Arabic labels, and give selection haptics.
struct CurvedTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var glassNS

    // Right-to-left layout: the first item of an HStack sits on the right.
    private let rightTabs: [AppTab] = [.tasks, .alarms]
    private let leftTabs: [AppTab] = [.achievements, .pages]

    var body: some View {
        ZStack(alignment: .top) {
            BottomBarArcShape()
                .fill(Theme.barMuted)
                .ignoresSafeArea(edges: .bottom)

            // One glass track per side, and a single glass "lens" that slides (morphs) to the selected tab.
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 0) {
                    trackGroup(rightTabs)
                    Color.clear.frame(width: Metrics.homeRingDiameter)
                    trackGroup(leftTabs)
                }
            }
            .frame(height: Metrics.tabRowHeight)
            .padding(.top, Metrics.barRise)

            homeButton
                .offset(y: -Metrics.homeRingDiameter / 2)
        }
        .frame(height: Metrics.barHeight)
        // Keep the bar usable at accessibility text sizes.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func trackGroup(_ tabs: [AppTab]) -> some View {
        HStack(spacing: 0) { ForEach(tabs) { tabButton($0) } }
            .padding(3)
            .glassEffect(.regular, in: Capsule())
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(.smooth(duration: 0.4)) { selection = tab }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isSelected ? tab.selectedSymbol : tab.symbol)
                    .font(.title3)
                Text(tab.title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Color.white.opacity(isSelected ? 1 : 0.85))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if isSelected {
                    Color.clear
                        .glassEffect(.regular.tint(Theme.primary.opacity(0.85)).interactive(), in: Capsule())
                        .glassEffectID("lens", in: glassNS)
                }
            }
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
