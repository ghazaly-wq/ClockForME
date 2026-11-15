import HabitCore
import SwiftData
import SwiftUI

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
        }
    }

    private func equip(_ item: ShopItem) {
        switch item.category {
        case .theme: theme = item.id
        case .frame: frame = item.id
        case .effect: effect = item.id
        case .liveStyle: liveStyle = item.id
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
            Image(systemName: item.id == "effect.stars" ? "sparkles" : "party.popper.fill")
                .font(.title2)
                .foregroundStyle(item.id == "effect.gold" ? Theme.gold : Theme.primaryStrong)
        }
    }
}
