import Foundation

struct Constants {
    struct MLANGE {
        static let personalAccessKey =
            Bundle.main.object(forInfoDictionaryKey: "PERSONAL_KEY") as? String
        static let modelName = "changgeun/LFM2.5-VL-450M"
    }

    struct Prompt {
        static let system = "Tu es Aperçu, un assistant visuel concis. Réponds en français aux questions sur la photo fournie. Sois précis et factuel. Indique clairement lorsque la photo ne permet pas de répondre."
        static let defaultQuestion = "Que voit-on sur cette photo ?"

        /// One-tap questions. Typing on a phone is the main cost of asking, so the
        /// common cases should never require the keyboard.
        static let suggestions = [
            "Que voit-on sur cette photo ?",
            "Pouvez-vous lire le texte ?",
        ]
    }

    /// Longest edge, in pixels, an image is resized to before it reaches the model.
    /// The vision encoder works on a small fixed grid, so sending a full 12 MP photo
    /// costs memory and prefill time without improving the answer.
    static let maxImageDimension: CGFloat = 512
}
