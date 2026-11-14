import SwiftUI

/// Green header with the arc, a bold white title and the settings gear.
/// It grows with Dynamic Type instead of clipping.
struct CurvedHeader: View {
    let title: LocalizedStringKey
    let subtitle: String?
    let onSettings: () -> Void

    init(title: LocalizedStringKey, subtitle: String? = nil, onSettings: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.onSettings = onSettings
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("الإعدادات"))
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
}

/// Shell shared by every main page: curved header + scrolling content.
/// The curved bottom bar is added once by `RootView`.
struct CurvedPage<Content: View>: View {
    @Environment(AppRouter.self) private var router
    let title: LocalizedStringKey
    let subtitle: String?
    let content: Content

    init(title: LocalizedStringKey, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            CurvedHeader(title: title, subtitle: subtitle) {
                router.showSettings = true
            }
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    // Room for the raised Home button that overlaps the page.
                    .padding(.bottom, Metrics.homeRingDiameter / 2 + 8)
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
