import Foundation

public enum ConversationContext {
    /// The archive retains every message. Replay only recent completed exchanges
    /// that fit the token budget of the on-device runtime, omitting an answer
    /// when needed to retain its question.
    public static func restoredQuestion(
        _ question: String,
        turns: [VisionTurn],
        historyTokenBudget: Int,
        tokenCount: (String) throws -> Int
    ) rethrows -> String {
        var history = ""
        for turn in turns.reversed() where turn.phase == .finished && !turn.answer.isEmpty {
            var candidate = "Utilisateur : \(turn.question)\nAssistant : \(turn.answer)\n" + history
            if try tokenCount(candidate) > historyTokenBudget {
                candidate = "Utilisateur : \(turn.question)\nAssistant : [réponse omise]\n" + history
                guard try tokenCount(candidate) <= historyTokenBudget else { break }
            }
            history = candidate
        }
        guard !history.isEmpty else { return question }
        return "Échanges précédents à propos de cette même photo :\n\(history)\nQuestion actuelle : \(question)"
    }
}
