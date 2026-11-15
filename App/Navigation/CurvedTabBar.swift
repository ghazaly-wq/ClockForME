import SwiftUI

/// Curved bottom bar with a raised circular Home button in the center.
/// Tabs navigate (never act), have Arabic labels, and give selection haptics.
struct CurvedTabBar: View {
    @Binding var selection: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gooRunning = false
    @State private var gooToken = 0

    // Right-to-left layout: the first item of an HStack sits on the right.
    private let rightTabs: [AppTab] = [.tasks, .alarms]
    private let leftTabs: [AppTab] = [.achievements, .pages]

    var body: some View {
        ZStack(alignment: .top) {
            BottomBarArcShape()
                .fill(Theme.barMuted)
                .ignoresSafeArea(edges: .bottom)

            // Liquid green blob behind the selected tab (or pooled under Home), then the tabs on the arc.
            GeometryReader { geo in
                let w = geo.size.width
                let slot = (w - Metrics.homeRingDiameter) / 4
                ZStack(alignment: .topLeading) {
                    GooBlob(selection: selection, width: w, running: gooRunning, reduceMotion: reduceMotion)
                        .overlay { sectionDividers(width: w, slot: slot) }
                        .clipShape(BottomBarArcShape())
                        .allowsHitTesting(false)
                    arcTab(.tasks, x: w - slot * 0.5, width: w)
                    arcTab(.alarms, x: w - slot * 1.5, width: w)
                    arcTab(.achievements, x: slot * 1.5, width: w)
                    arcTab(.pages, x: slot * 0.5, width: w)
                }
            }
            .frame(height: Metrics.barHeight)

            homeButton
                .offset(y: -Metrics.homeRingDiameter / 2)
        }
        .frame(height: Metrics.barHeight)
        // Keep the bar usable at accessibility text sizes.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        // Plain screen coordinates for the arc layout, so tab positions, blob and pager all agree.
        .environment(\.layoutDirection, .leftToRight)
        .sensoryFeedback(.selection, trigger: selection)
        .onChange(of: selection) {
            gooToken += 1
            let token = gooToken
            gooRunning = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                if token == gooToken { gooRunning = false }   // only the latest change may stop the animation
            }
        }
    }

    /// Thin lines between the bar's sections (like the owner's reference).
    private func sectionDividers(width: CGFloat, slot: CGFloat) -> some View {
        let side = slot * 2
        return Canvas { ctx, size in
            for x in [slot, side, width - side, width - slot] {
                var line = Path()
                line.move(to: CGPoint(x: x, y: Metrics.barRise + 6))
                line.addLine(to: CGPoint(x: x, y: size.height + 40))
                ctx.stroke(line, with: .color(.white.opacity(0.14)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
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
            .foregroundStyle(Color.white.opacity(isSelected ? 1 : 0.8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
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


/// Spring state for the liquid blobs. A bouncy lead blob and a softer trailing blob chase the same target;
/// drawn together through a blur + alpha threshold they stretch and snap together like a liquid.
private final class GooSim {
    struct Body { var p = SIMD3<Double>(0, 0, 0); var v = SIMD3<Double>(0, 0, 0) }
    var lead = Body()
    var tail = Body()
    var ready = false
    var last: Date?

    func step(now: Date, target: SIMD3<Double>, snap: Bool) {
        if !ready || snap {
            lead = Body(p: target); tail = Body(p: target); ready = true; last = now; return
        }
        let dt = min(max(now.timeIntervalSince(last ?? now), 0), 1.0 / 30.0)
        last = now
        integrate(&lead, target: target, k: 300, c: 15, dt: dt)
        integrate(&tail, target: target, k: 170, c: 19, dt: dt)
    }

    private func integrate(_ b: inout Body, target: SIMD3<Double>, k: Double, c: Double, dt: Double) {
        let a = (target - b.p) * k - b.v * c
        b.v += a * dt
        b.p += b.v * dt
    }
}

private struct GooBlob: View {
    let selection: AppTab
    let width: CGFloat
    let running: Bool
    let reduceMotion: Bool
    @State private var sim = GooSim()

    private func target() -> SIMD3<Double> {
        let w = Double(width)
        let slot = (w - Double(Metrics.homeRingDiameter)) / 4
        let rise = Double(Metrics.barRise)
        func onArc(_ x: Double) -> SIMD3<Double> {
            let u = x / w
            _ = u; _ = rise
            return SIMD3(x, 0, slot / 2 - 3)
        }
        switch selection {
        case .tasks: return onArc(w - slot * 0.5)
        case .alarms: return onArc(w - slot * 1.5)
        case .achievements: return onArc(slot * 1.5)
        case .pages: return onArc(slot * 0.5)
        case .home: return SIMD3(w / 2, 0, Double(Metrics.homeRingDiameter) / 2 - 2)   // the section under Home
        }
    }

    var body: some View {
        TimelineView(.animation(paused: !running && sim.ready)) { timeline in
            Canvas { ctx, size in
                sim.step(now: timeline.date, target: target(), snap: reduceMotion || !running)
                ctx.addFilter(.alphaThreshold(min: 0.5, color: Theme.primary))
                ctx.addFilter(.blur(radius: 7))
                ctx.drawLayer { layer in
                    // A whole bar section lit up: the lead and tail sections plus a band between them,
                    // so a long jump stretches like one liquid instead of splitting into two.
                    let l = sim.lead, t = sim.tail
                    let hw = max(l.p.z, 4), hwT = max(t.p.z, 4)
                    func section(_ x0: Double, _ x1: Double) {
                        layer.fill(Path(CGRect(x: x0, y: -40, width: x1 - x0, height: size.height + 80)),
                                   with: .color(.white))
                    }
                    section(l.p.x - hw, l.p.x + hw)
                    section(t.p.x - hwT, t.p.x + hwT)
                    section(min(l.p.x - hw, t.p.x - hwT), max(l.p.x + hw, t.p.x + hwT))
                }
            }
        }
        .frame(height: Metrics.barHeight)
        .ignoresSafeArea(edges: .bottom)
    }
}
