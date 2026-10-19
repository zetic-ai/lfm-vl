import SwiftUI
import SessionHistory

@MainActor
final class AIInstructionStore: ObservableObject {
    private static let key = "apercu.aiInstructions.v1"
    private let defaults: UserDefaults
    @Published private(set) var value: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        value = defaults.string(forKey: Self.key).flatMap(AIInstructions.validated) ?? AIInstructions.defaultValue
    }

    func save(_ text: String) -> Bool {
        guard let clean = AIInstructions.validated(text) else { return false }
        defaults.set(clean, forKey: Self.key)
        value = clean
        return true
    }
}
