import Foundation
import ZeticMLange
import SessionHistory

/// Owns the on-device model.
///
/// This is an actor so the model is created and prefilled off the main thread —
/// both `ZeticMLangeLLMModel.init` and `respond` block for a noticeable time on a
/// 450M vision model, and neither may run on the UI thread.
actor VisionEngine {
    private var model: ZeticMLangeLLMModel?

    /// Identity of the image whose tokens are currently in the model's context.
    private var contextInstructions: String?
    private var contextImageID: UUID?
    private var estimatedContextTokens = 0

    var isLoaded: Bool { model != nil }

    /// Downloads (first launch only) and loads the model. Subsequent calls are no-ops.
    func load(onProgress: @escaping @Sendable (Float) -> Void) async throws {
        guard model == nil else { return }
        model = try await makeModel(onProgress: onProgress)
    }

    /// Streams an answer about `image`.
    ///
    /// Context is deliberately *kept* between questions about the same image, so
    /// follow-ups work, and cleared when the image changes, so an answer never
    /// describes the previous photo.
    func answer(
        question: String,
        image: ZeticMLangeLLMModel.Image,
        imageID: UUID,
        history: [VisionTurn] = [],
        restoreContext: Bool = false,
        systemPrompt: String = Constants.Prompt.system
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let model else { throw VisionEngineError.notLoaded }

        let instructionTokens = try model.tokenize(systemPrompt, parseSpecial: false).count
        guard instructionTokens <= 160 else { throw VisionEngineError.instructionsTooLong }
        let questionTokens = try model.tokenize(question, parseSpecial: false).count
        guard questionTokens <= 256 else { throw VisionEngineError.questionTooLong }
        let rebuild = restoreContext || contextImageID != imageID || contextInstructions != systemPrompt || estimatedContextTokens + questionTokens > 640
        var prompt = question
        if rebuild {
            if contextImageID != nil { try clearContext(on: model) }
            prompt = try ConversationContext.restoredQuestion(
                question, turns: history, historyTokenBudget: min(192, max(0, 384 - questionTokens - instructionTokens)),
                tokenCount: { try model.tokenize($0, parseSpecial: false).count }
            )
            // Conservative headroom for image tokens and the next answer.
            estimatedContextTokens = 256 + instructionTokens
        }
        contextInstructions = systemPrompt
        contextImageID = imageID
        estimatedContextTokens += try model.tokenize(prompt, parseSpecial: false).count

        return try model.respond(
            systemPrompt: systemPrompt,
            userText: prompt,
            image: image
        )
    }

    func recordCompletion(_ answer: String, imageID: UUID) {
        guard contextImageID == imageID, let model else { return }
        estimatedContextTokens += (try? model.tokenize(answer, parseSpecial: false).count) ?? answer.count
    }

    func close() {
        model?.close()
        model = nil
        contextInstructions = nil
        contextImageID = nil
        estimatedContextTokens = 0
    }

    // MARK: - Context

    /// Clears model context before answering about a different image.
    private func clearContext(on model: ZeticMLangeLLMModel) throws {
        do {
            try model.cleanUp()
        } catch {
            throw VisionEngineError.contextResetFailed(underlying: error)
        }
    }

    private func makeModel(onProgress: (@Sendable (Float) -> Void)?) async throws -> ZeticMLangeLLMModel {
        guard let personalAccessKey = Constants.MLANGE.personalAccessKey?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !personalAccessKey.isEmpty,
            personalAccessKey != "dev_YOUR_KEY_HERE"
        else {
            throw VisionEngineError.missingPersonalAccessKey
        }

        let model = try await ZeticMLangeLLMModel(
            personalKey: personalAccessKey,
            name: Constants.MLANGE.modelName,
            modelMode: .RUN_AUTO,
            cacheHandlingPolicy: .KEEP_EXISTING,
            initOption: LLMInitOption(nCtx: 1024),
            onDownload: onProgress
        )
        return model
    }
}

enum VisionEngineError: LocalizedError {
    case notLoaded
    case missingPersonalAccessKey
    case instructionsTooLong
    case questionTooLong
    case contextResetFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notLoaded:
            return "Le modèle n’est pas encore prêt."
        case .instructionsTooLong:
            return "Raccourcissez les instructions de l’IA dans les paramètres, puis commencez une nouvelle conversation."
        case .questionTooLong:
            return "Cette question est trop longue. Essayez une formulation plus courte."
        case .missingPersonalAccessKey:
            return "Set ZETIC_PERSONAL_KEY in .env and run scripts/generate-secrets-xcconfig.sh before building."
        case .contextResetFailed(let underlying):
            return "Could not clear the previous image from the model: \(underlying.localizedDescription)"
        }
    }
}
