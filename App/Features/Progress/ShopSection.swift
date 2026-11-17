import HabitCore
import SwiftData
import SwiftUI
import UIKit

/// "المتجر": cosmetic items bought with points. Nothing here affects streaks or XP.
struct ShopSection: View {
    let snapshot: ProgressSnapshot
    let purchases: [PurchaseRecord]
    @Environment(\.modelContext) private var context
    @Environment(\.digitStyle) private var digits
    @AppStorage(SettingsKey.equippedTheme) private var theme = ShopCatalog.defaultTheme
    @AppStorage(SettingsKey.equippedFrame) private var frame = ShopCatalog.defaultFrame
    @AppStorage(SettingsKey.equippedEffect) private var effect = ShopCatalog.defaultEffect
    @AppStorage(SettingsKey.equippedLiveStyle) private var liveStyle = ShopCatalog.defaultLiveStyle
    @AppStorage(SettingsKey.equippedIcon) private var icon = ShopCatalog.defaultIcon

    private var owned: Set<String> { Set(purchases.map(\.itemID)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(digits.format(String(localized: "رصيدك: \(snapshot.summary.points) نقطة")), systemImage: "circle.hexagongrid.fill")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.primaryStrong)

            section("ألوان التطبيق", .theme)
            section("إطارات بطاقة المستوى", .frame)
            section("تأثير الاحتفال", .effect)
            section("شكل شريط التقدم (شاشة القفل والويدجت)", .liveStyle)
            section("أيقونة التطبيق", .appIcon)
        }
    }

    private func section(_ title: LocalizedStringKey, _ category: ShopCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            ForEach(ShopCatalog.items(in: category)) { item in
                row(item)
            }
        }
    }

    private func equipped(_ category: ShopCategory) -> String {
        switch category {
        case .theme: return theme
        case .frame: return frame
        case .effect: return effect
        case .liveStyle: return liveStyle
        case .appIcon: return icon
        }
    }

    private func equip(_ item: ShopItem) {
        switch item.category {
        case .theme: theme = item.id
        case .frame: frame = item.id
        case .effect: effect = item.id
        case .liveStyle: liveStyle = item.id
        case .appIcon:
            icon = item.id
            AppIconSwitcher.apply(shopID: item.id)
        }
    }

    private func row(_ item: ShopItem) -> some View {
        let availability = ShopCatalog.availability(
            of: item, owned: owned, level: snapshot.summary.level, pointsBalance: snapshot.summary.points
        )
        let isEquipped = equipped(item.category) == item.id

        return HStack(spacing: 12) {
            preview(item)
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textPrimary)
                if !item.isFree {
                    Text(digits.format(String(localized: "\(item.price) نقطة")))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            action(item, availability: availability, isEquipped: isEquipped)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func action(_ item: ShopItem, availability: ShopCatalog.Availability, isEquipped: Bool) -> some View {
        switch availability {
        case .owned:
            if isEquipped {
                Label("مجهّز", systemImage: "checkmark.circle.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(Theme.primaryStrong)
            } else {
                Button("تجهيز") { equip(item) }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
            }
        case .purchasable:
            Button("شراء") {
                if AchievementActions.buy(item, owned: owned, snapshot: snapshot, context: context, now: Date()) {
                    SoundEffects.shared.play(.purchase)
                    equip(item)
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
        case .levelTooLow(let required):
            Label(digits.format(String(localized: "المستوى \(required)")), systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        case .notEnoughPoints(let missing):
            Text(digits.format(String(localized: "ينقصك \(missing) نقطة")))
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private func preview(_ item: ShopItem) -> some View {
        switch item.category {
        case .theme:
            let palette = ThemePalette.palette(for: item.id)
            HStack(spacing: 0) {
                Rectangle().fill(Theme.dynamic(light: palette.primaryLight, dark: palette.primaryDark))
                Rectangle().fill(Theme.dynamic(light: palette.strongLight, dark: palette.strongDark))
            }
            .clipShape(Circle())
        case .frame:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface)
                .overlay { FrameBorder(frameID: item.id, cornerRadius: 10) }
                .overlay {
                    if item.id == ShopCatalog.defaultFrame {
                        Image(systemName: "nosign").foregroundStyle(Theme.textSecondary)
                    }
                }
        case .liveStyle:
            SegmentBar(segments: [true, true, false], styleID: item.id, height: 8)
                .padding(.horizontal, 4)
        case .effect:
            Image(systemName: effectSymbol(item.id))
                .font(.title2)
                .foregroundStyle(effectColor(item.id))
        case .appIcon:
            IconPreview(shopID: item.id)
        }
    }
}

// MARK: - Previews

private func effectSymbol(_ id: String) -> String {
    switch id {
    case "effect.stars": return "sparkles"
    case "effect.hearts": return "heart.fill"
    case "effect.bubbles": return "circle.circle"
    case "effect.flames": return "flame.fill"
    default: return "party.popper.fill"
    }
}

private func effectColor(_ id: String) -> Color {
    switch id {
    case "effect.gold": return Theme.gold
    case "effect.hearts": return .red
    case "effect.bubbles": return .cyan
    case "effect.flames": return .orange
    default: return Theme.primaryStrong
    }
}

/// A small drawn copy of an alternate icon (asset-catalog app icons can't be loaded as images).
/// Colors mirror the icon generator: background, arc, circle, check.
private struct IconPreview: View {
    let shopID: String

    private var colors: (bg: UInt32, arc: UInt32, circle: UInt32, check: UInt32) {
        switch shopID {
        case "icon.night": return (0x0A0F0C, 0x123B2A, 0x1DBF7A, 0x0A0F0C)
        case "icon.ocean": return (0x1E88E5, 0x0D5FA8, 0xF1F8FF, 0x1E88E5)
        case "icon.violet": return (0x7E57C2, 0x4F2E9A, 0xF6F2FF, 0x7E57C2)
        case "icon.sunset": return (0xE64A19, 0xB23A12, 0xFFF5F0, 0xE64A19)
        case "icon.rose": return (0xD81B60, 0x9C1244, 0xFFF1F6, 0xD81B60)
        case "icon.graphite": return (0x546E7A, 0x2F4048, 0xF3F5F6, 0x546E7A)
        case "icon.teal": return (0x00897B, 0x00574B, 0xF0FAF9, 0x00897B)
        case "icon.indigo": return (0x3949AB, 0x24307A, 0xF3F4FF, 0x3949AB)
        case "icon.crimson": return (0xC62828, 0x8E1B1B, 0xFFF3F3, 0xC62828)
        case "icon.gold": return (0xB8860B, 0x7A5A06, 0xFFFAEB, 0xB8860B)
        default: return (0x12A96A, 0x0B7A4B, 0xF2FFF9, 0x12A96A)
        }
    }

    var body: some View {
        let c = colors
        GeometryReader { proxy in
            let side = proxy.size.width
            ZStack {
                Color(uiColor: UIColor(hex: c.bg))
                Circle()
                    .fill(Color(uiColor: UIColor(hex: c.arc)))
                    .frame(width: side * 1.7, height: side * 1.7)
                    .position(x: side / 2, y: side * 1.4)
                Circle()
                    .fill(Color(uiColor: UIColor(hex: c.circle)))
                    .frame(width: side * 0.6, height: side * 0.6)
                    .position(x: side / 2, y: side * 0.46)
                Image(systemName: "checkmark")
                    .font(.system(size: side * 0.3, weight: .heavy))
                    .foregroundStyle(Color(uiColor: UIColor(hex: c.check)))
                    .position(x: side / 2, y: side * 0.46)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: side * 0.225, style: .continuous))
        }
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
