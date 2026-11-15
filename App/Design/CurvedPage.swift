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
    @Environment(\.pageTab) private var tab
    @Environment(\.headerEnabled) private var headerEnabled
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
            // Inside the main shell the single shared header (owned by RootView) is used and this page only
            // describes what it should show. Elsewhere (no tab in the environment) it draws its own header.
            if tab == nil {
                CurvedHeader(title: title, subtitle: subtitle, onAdd: onAdd, onBack: onBack, extraButtons: extraButtons) {
                    router.showSettings = true
                }
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
        .preference(key: HeaderPreferenceKey.self, value: headerValue)
    }

    private var headerValue: [AppTab: HeaderConfig] {
        guard let tab, headerEnabled else { return [:] }
        return [tab: HeaderConfig(
            title: title, titleKey: String(describing: title), subtitle: subtitle,
            onAdd: onAdd, onBack: onBack, extraButtons: extraButtons, stamp: HeaderConfig.nextStamp()
        )]
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


// MARK: - Shared header

/// What one page wants the shared header to show.
struct HeaderConfig: Equatable {
    var title: LocalizedStringKey
    var titleKey: String
    var subtitle: String?
    var onAdd: (() -> Void)?
    var onBack: (() -> Void)?
    var extraButtons: [HeaderButton]
    /// Increases with every evaluation: when two views of one tab overlap (a list and its detail during
    /// a push), the newest one decides what the header shows.
    var stamp: Int

    private static var counter = 0
    static func nextStamp() -> Int { counter += 1; return counter }

    static func == (a: HeaderConfig, b: HeaderConfig) -> Bool {
        a.titleKey == b.titleKey && a.subtitle == b.subtitle
            && (a.onAdd != nil) == (b.onAdd != nil) && (a.onBack != nil) == (b.onBack != nil)
            && a.extraButtons.map(\.symbol) == b.extraButtons.map(\.symbol)
    }
}

struct HeaderPreferenceKey: PreferenceKey {
    static var defaultValue: [AppTab: HeaderConfig] { [:] }
    static func reduce(value: inout [AppTab: HeaderConfig], nextValue: () -> [AppTab: HeaderConfig]) {
        for (tab, config) in nextValue() {
            if let old = value[tab], old.stamp > config.stamp { continue }
            value[tab] = config
        }
    }
}

private struct PageTabKey: EnvironmentKey {
    static let defaultValue: AppTab? = nil
}

extension EnvironmentValues {
    /// Set by RootView on each main page, so `CurvedPage` knows to use the shared header.
    var pageTab: AppTab? {
        get { self[PageTabKey.self] }
        set { self[PageTabKey.self] = newValue }
    }
}

private struct HeaderEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// A screen that is covered by another one of the same tab (the list under an opened page) turns this off,
    /// so only the visible screen drives the shared header.
    var headerEnabled: Bool {
        get { self[HeaderEnabledKey.self] }
        set { self[HeaderEnabledKey.self] = newValue }
    }
}
