import Observation
import SwiftUI

/// Where the user is in the app. Deep links (`habits://...`) will drive this later.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var showSettings = false
}
