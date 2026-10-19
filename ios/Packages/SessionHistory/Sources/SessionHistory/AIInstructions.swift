import Foundation

public enum AIInstructions {
    public static let defaultValue = "Tu es Aperçu, un assistant visuel concis. Réponds en français aux questions sur la photo fournie. Sois précis et factuel. Indique clairement lorsque la photo ne permet pas de répondre."
    public static let maximumCharacters = 400

    public static func validated(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && value.count <= maximumCharacters ? value : nil
    }

    /// Existing archives have no instruction field and retain the original behavior.
    public static func forSession(_ saved: String?) -> String { saved ?? defaultValue }
}
