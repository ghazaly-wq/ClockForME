import SwiftUI

/// Sizes shared by the curved shell (see docs/design/layout-reference.png).
enum Metrics {
    /// How much the page surface bulges up into the header at its center.
    static let headerRise: CGFloat = 22
    /// How much the bottom bar bulges up at its center.
    static let barRise: CGFloat = 22
    static let tabRowHeight: CGFloat = 56
    static var barHeight: CGFloat { barRise + tabRowHeight }
    /// Surface-colored ring cut into the bar around the Home button.
    static let homeRingDiameter: CGFloat = 84
    static let homeButtonDiameter: CGFloat = 66
}
