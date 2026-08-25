import Foundation
import ZeticMLange

/// Owns the on-device model.
///
/// This is an actor so the model is created and prefilled off the main thread —
/// both `ZeticMLangeLLMModel.init` and `respond` block for a noticeable time on a
/// 450M vision model, and neither may run on the UI thread.
actor VisionEngine {
    private var model: ZeticMLangeLLMModel?

    /// Identity of the image whose tokens are currently in the model's context.
    private var contextImageID: UUID?

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
        imageID: UUID
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let model else { throw VisionEngineError.notLoaded }

        switch contextImageID {
        case nil, imageID:
            break
        default:
            try clearContext(on: model)
        }
        contextImageID = imageID

        return try model.respond(
            systemPrompt: Constants.Prompt.system,
            userText: question,
            image: image
        )
    }

    func close() {
        model?.close()
        model = nil
        contextImageID = nil
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
            initOption: LLMInitOption(nCtx: 1024),
            onDownload: onProgress
        )
        return model
    }
}

enum VisionEngineError: LocalizedError {
    case notLoaded
    case missingPersonalAccessKey
    case contextResetFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notLoaded:
            return "The model is not loaded yet."
        case .missingPersonalAccessKey:
            return "Set ZETIC_PERSONAL_KEY in .env and run scripts/generate-secrets-xcconfig.sh before building."
        case .contextResetFailed(let underlying):
            return "Could not clear the previous image from the model: \(underlying.localizedDescription)"
        }
    }
}
