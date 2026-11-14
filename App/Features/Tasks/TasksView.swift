import SwiftUI

struct TasksView: View {
    var body: some View {
        CurvedPage(title: "المهمات") {
            PlaceholderContent(symbol: "checkmark.circle", message: "هنا تظهر مهماتك الرئيسية والفرعية")
        }
    }
}
