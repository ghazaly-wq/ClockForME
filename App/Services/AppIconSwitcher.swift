import UIKit

/// Switches the home-screen icon. Shop ids look like `icon.ocean`; the asset-catalog set is `IconOcean`
/// (listed in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in project.yml). The default icon is `nil`.
@MainActor
enum AppIconSwitcher {
    static func assetName(for shopID: String) -> String? {
        guard shopID != "icon.default", shopID.hasPrefix("icon.") else { return nil }
        return "Icon" + shopID.dropFirst("icon.".count).capitalized
    }

    static func apply(shopID: String) {
        let application = UIApplication.shared
        guard application.supportsAlternateIcons else { return }
        let name = assetName(for: shopID)
        guard application.alternateIconName != name else { return }
        application.setAlternateIconName(name) { _ in }
    }
}
