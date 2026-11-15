import SwiftUI

/// An extra round button in the header (e.g. the edit/use toggle on a custom page).
struct HeaderButton: Identifiable {
    let id = UUID()
    let symbol: String
    let label: LocalizedStringKey
    let action: () -> Void
}

/// Green header with the arc, a bold white title and its actions (optional "+", settings gear).
/// It grows with Dynamic Type instead of clipping.
struct CurvedHeader: View {
    let title: LocalizedStringKey
    let subtitle: String?
    let onAdd: (() -> Void)?
    let onBack: (() -> Void)?
    let extraButtons: [HeaderButton]
    let onSettings: () -> Void

    init(
        title: LocalizedStringKey,
        subtitle: String? = nil,
        onAdd: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil,
        extraButtons: [HeaderButton] = [],
        onSettings: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onAdd = onAdd
        self.onBack = onBack
        self.extraButtons = extraButtons
        self.onSettings = onSettings
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let onBack {
                headerButton(symbol: "chevron.backward", label: "رجوع", action: onBack)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                ForEach(extraButtons) { button in
                    headerButton(symbol: button.symbol, label: button.label, action: button.action)
                }
                if let onAdd {
                    headerButton(symbol: "plus", label: "إضافة", action: onAdd)
                }
                headerButton(symbol: "gearshape.fill", label: "الإعدادات", action: onSettings)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, Metrics.headerRise + 16)
        .frame(maxWidth: .infinity)
        .background {
            HeaderArcShape()
                .fill(Theme.primary)
                .ignoresSafeArea(edges: .top)
        }
    }

    private func headerButton(symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// Shell shared by every main page: curved header + content.
/// The curved bottom bar is added once by `RootView`.
/// Pass `scrollable: false` when the content is a `List` that scrolls by itself.
struct CurvedPage<Content: View>: View {
    @Environment(AppRouter.self) private var router
    let title: LocalizedStringKey
    let subtitle: String?
    let scrollable: Bool
    let onAdd: (() -> Void)?
    let onBack: (() -> Void)?
    let extraButtons: [HeaderButton]
    let content: Content

    init(
        title: LocalizedStringKey,
        subtitle: String? = nil,
        scrollable: Bool = true,
        onAdd: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil,
        extraButtons: [HeaderButton] = [],
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.scrollable = scrollable
        self.onAdd = onAdd
        self.onBack = onBack
        self.extraButtons = extraButtons
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            CurvedHeader(title: title, subtitle: subtitle, onAdd: onAdd, onBack: onBack, extraButtons: extraButtons) {
                router.showSettings = true
            }
            if scrollable {
                ScrollView {
                    content
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        // Room for the raised Home button that overlaps the page.
                        .padding(.bottom, Metrics.homeRingDiameter / 2 + 8)
                }
            } else {
                content
            }
        }
    }
}

/// Friendly empty state used by pages that are not built yet.
struct PlaceholderContent: View {
    let symbol: String
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(Theme.primaryStrong)
                .accessibilityHidden(true)
            Text("قريباً")
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
