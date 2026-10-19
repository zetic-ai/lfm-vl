#if DEBUG
import SwiftUI
import SessionHistory

/// Opt-in, separate archive for native UI verification without a model download.
/// This path is never used by normal launches or Release builds.
@MainActor
enum UITestFixtures {
    static let archiveDirectoryName = "ApercuUITestSessions-GasPipe-v1"

    static func seed(_ store: SessionStore) async {
        guard store.sessions.isEmpty else { return }
        guard let image = UIImage(named: "DemoGasPipe"),
              let photo = try? image.sessionArchivePhoto() else { return }
        let now = Date()
        var first = VisionSession(createdAt: now, turns: [
            VisionTurn(question: "Que voit-on sur cette photo ?", answer: "Une installation de gaz avec une grande canalisation jaune et une vanne à brides.", phase: .finished),
        ])
        first.didChange(at: now)
        _ = await store.save(first, photo: photo)
        var second = VisionSession(createdAt: now.addingTimeInterval(-86400), turns: [
            VisionTurn(question: "Quels équipements sont visibles ?", answer: "Une canalisation jaune, des vannes et des raccords à brides.", phase: .interrupted),
        ])
        second.didChange(at: now.addingTimeInterval(-86400))
        _ = await store.save(second, photo: photo)
    }
}
#endif
