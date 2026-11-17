import AppIntents
import Foundation

/// A Shortcuts action: "is anything blocking my apps right now?". It answers yes or no without opening the app, so the
/// owner's automation can open Habits only while a task is blocking, and otherwise let the chosen app open normally.
struct BlockStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "فيه قفل؟"
    static var description = IntentDescription(
        "يرجّع «نعم» إذا فيه مهمة عليها قفل التطبيقات وفات وقتها وما خلصتها، وإلا «لا». ما يفتح التطبيق."
    )
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: BlockStatus.isBlocking())
    }
}
