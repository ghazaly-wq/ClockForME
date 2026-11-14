import SwiftUI

/// Solid header whose bottom edge is a wide arc: thicker at the sides,
/// thinner in the center (the page surface bulges up into it).
struct HeaderArcShape: Shape {
    var rise: CGFloat = Metrics.headerRise

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // A quadratic curve reaches half of its control offset, so the
        // control point sits 2 × rise above the corners to peak at `rise`.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.maxY - 2 * rise)
        )
        path.closeSubpath()
        return path
    }
}

/// Bottom bar whose top edge is an upward arc: it touches the top of its
/// frame at the center and sits `rise` lower at the sides.
/// The circular cutout for the Home button is drawn by the tab bar as a
/// surface-colored ring on top of this shape.
struct BottomBarArcShape: Shape {
    var rise: CGFloat = Metrics.barRise

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rise))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rise),
            control: CGPoint(x: rect.midX, y: rect.minY - rise)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
