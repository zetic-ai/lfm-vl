#if DEBUG
import SwiftUI
import SessionHistory

/// Opt-in, separate archive for native UI verification without a model download.
/// This path is never used by normal launches or Release builds.
@MainActor
enum UITestFixtures {
    static func seed(_ store: SessionStore) async {
        guard store.sessions.isEmpty else { return }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 400)).image { context in
            UIColor(red: 0.8, green: 0.84, blue: 0.83, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 400))
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 230, width: 600, height: 36))
            UIColor.systemRed.setStroke()
            let wheel = UIBezierPath(ovalIn: CGRect(x: 100, y: 190, width: 120, height: 120))
            wheel.lineWidth = 12
            wheel.stroke()
            ("V-07" as NSString).draw(at: CGPoint(x: 260, y: 280), withAttributes: [
                .font: UIFont.systemFont(ofSize: 36), .foregroundColor: UIColor.darkGray,
            ])
        }
        guard let photo = try? image.sessionArchivePhoto() else { return }
        let now = Date()
        var first = VisionSession(createdAt: now, turns: [
            VisionTurn(question: "Que voit-on sur cette photo ?", answer: "Une vanne rouge est reliée à une canalisation.", phase: .finished),
            VisionTurn(question: "Pouvez-vous lire l’étiquette ?", answer: "L’étiquette indique « V-07 ».", phase: .finished),
        ])
        first.didChange(at: now)
        _ = await store.save(first, photo: photo)
        var second = VisionSession(createdAt: now.addingTimeInterval(-86400), turns: [
            VisionTurn(question: "Quels objets sont visibles ?", answer: "Une canalisation et une vanne rouge sont visibles.", phase: .interrupted),
        ])
        second.didChange(at: now.addingTimeInterval(-86400))
        _ = await store.save(second, photo: photo)
    }
}
#endif
