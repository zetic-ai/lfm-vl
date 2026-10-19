import SwiftUI
import ZeticMLange
import SessionHistory

@MainActor
final class VisionChatViewModel: ObservableObject {
    enum LoadPhase { case initializing, downloading, ready }

    @Published private(set) var image: UIImage?
    @Published var question = ""
    @Published private(set) var session: VisionSession?
    @Published private(set) var loadPhase: LoadPhase = .initializing
    @Published private(set) var downloadProgress: Float = 0
    @Published private(set) var isGenerating = false
    @Published private(set) var isLoadingModel = false
    @Published private(set) var isRestoring = false
    @Published private(set) var hasUnsavedChanges = false
    @Published var loadFailure: String?

    private let engine = VisionEngine()
    private let instructions: AIInstructionStore
    private let store: SessionStore
    private var generationTask: Task<Void, Never>?
    private var preparedPhoto: SessionPhoto?
    private var photoSaved = false
    private var savedRevision = 0
    private var restoreContext = true

    init(store: SessionStore, instructions: AIInstructionStore? = nil) {
        self.store = store
        self.instructions = instructions ?? AIInstructionStore()
    }

    var turns: [VisionTurn] { session?.turns ?? [] }
    var isModelReady: Bool { loadPhase == .ready }
    var canLeaveSession: Bool { !isGenerating && !isRestoring && !hasUnsavedChanges }
    var canAsk: Bool {
        isModelReady && !isGenerating && !isRestoring && image != nil && store.isLoaded
            && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var canRemoveDownloadedModel: Bool { !isGenerating && !isLoadingModel && !isRestoring }

    func loadModel() async {
        guard loadPhase != .ready, !isLoadingModel, loadFailure == nil else { return }
        isLoadingModel = true
        defer { isLoadingModel = false }
        do {
            try await engine.load { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress
                    self?.loadPhase = progress >= 1 ? .initializing : .downloading
                }
            }
            loadPhase = .ready
        } catch { loadFailure = error.localizedDescription }
    }

    func retryLoad() {
        loadFailure = nil
        downloadProgress = 0
        loadPhase = .initializing
        Task { await loadModel() }
    }

    @discardableResult
    func select(_ newImage: UIImage) -> Bool {
        guard canLeaveSession else { return false }
        applyPhoto(newImage)
        return true
    }

    func beginPhotoSelection() -> Bool {
        guard canLeaveSession else { return false }
        isRestoring = true
        return true
    }

    func finishPhotoSelection(_ newImage: UIImage?) {
        guard isRestoring else { return }
        if let newImage { applyPhoto(newImage) }
        isRestoring = false
    }

    private func applyPhoto(_ newImage: UIImage) {
        image = newImage
        session = VisionSession()
        question = ""
        preparedPhoto = nil
        photoSaved = false
        savedRevision = 0
        restoreContext = true
    }

    @discardableResult
    func newSession() -> Bool {
        guard canLeaveSession else { return false }
        image = nil
        session = nil
        question = ""
        preparedPhoto = nil
        photoSaved = false
        savedRevision = 0
        restoreContext = true
        return true
    }

    func resume(_ saved: VisionSession) async -> Bool {
        guard canLeaveSession else { return false }
        isRestoring = true
        defer { isRestoring = false }
        do {
            let photo = try await store.image(for: saved.id)
            image = photo
            session = saved
            question = ""
            preparedPhoto = nil
            photoSaved = true
            savedRevision = saved.revision
            restoreContext = true
            return true
        } catch { store.failure = error.localizedDescription; return false }
    }

    func ask(_ prompt: String? = nil) {
        if let prompt { question = prompt }
        guard canAsk, let image, var active = session else { return }
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let history = active.turns
        let turn = active.appendQuestion(text, instructions: instructions.value)
        let systemInstructions = AIInstructions.forSession(active.aiInstructions)
        session = active
        hasUnsavedChanges = true
        question = ""
        isGenerating = true
        let sessionID = active.id
        let shouldRestore = restoreContext

        generationTask = Task { [weak self] in
            guard let self else { return }
            let started = Date()
            var checkpoint = Date()
            defer { self.isGenerating = false; self.generationTask = nil }
            do {
                if !self.photoSaved && self.preparedPhoto == nil {
                    self.preparedPhoto = try await Task.detached(priority: .userInitiated) {
                        try image.sessionArchivePhoto()
                    }.value
                }
                // Persist the question and photo before starting the runtime.
                guard await self.persistCurrent() else {
                    self.update(turn.id) { $0.phase = .failed; $0.failure = "Enregistrement impossible. Réessayez avant de continuer." }
                    return
                }
                try Task.checkCancellation()
                let rgb = try await Task.detached(priority: .userInitiated) { try image.zeticRGBImage() }.value
                try Task.checkCancellation()
                let stream = try await self.engine.answer(
                    question: text, image: rgb, imageID: sessionID,
                    history: history, restoreContext: shouldRestore, systemPrompt: systemInstructions
                )
                for try await piece in stream {
                    try Task.checkCancellation()
                    self.update(turn.id) {
                        if $0.firstTokenMs == nil { $0.firstTokenMs = Self.elapsed(since: started) }
                        $0.phase = .answering
                        $0.answer += piece
                    }
                    if Date().timeIntervalSince(checkpoint) >= 0.5 {
                        _ = await self.persistCurrent()
                        checkpoint = Date()
                    }
                }
                try Task.checkCancellation()
                self.update(turn.id) { $0.phase = .finished; $0.durationMs = Self.elapsed(since: started) }
                await self.engine.recordCompletion(self.turns.last?.answer ?? "", imageID: sessionID)
                self.restoreContext = false
            } catch is CancellationError {
                self.update(turn.id) { $0.phase = .interrupted; $0.durationMs = Self.elapsed(since: started) }
                self.restoreContext = true
            } catch {
                self.update(turn.id) { $0.phase = .failed; $0.failure = error.localizedDescription }
                self.restoreContext = true
            }
            _ = await self.persistCurrent()
        }
    }

    func regenerateLast() {
        guard !isGenerating, let last = turns.last, session != nil else { return }
        session?.aiInstructions = AIInstructions.forSession(session?.aiInstructions)
        session?.turns.removeLast()
        session?.didChange()
        restoreContext = true
        ask(last.question)
    }

    func cancelGeneration() { generationTask?.cancel() }

    @discardableResult
    func persistCurrent() async -> Bool {
        guard let snapshot = session, !snapshot.turns.isEmpty else { return true }
        guard photoSaved || preparedPhoto != nil else { return false }
        let saved = await store.save(snapshot, photo: photoSaved ? nil : preparedPhoto)
        guard session?.id == snapshot.id else { return saved }
        if saved {
            savedRevision = max(savedRevision, snapshot.revision)
            photoSaved = true
            preparedPhoto = nil
        }
        hasUnsavedChanges = (session?.revision ?? 0) > savedRevision
        return saved
    }

    func forgetDeletedSession(_ id: UUID) {
        guard session?.id == id else { return }
        _ = newSession()
    }

    func closeModelForRemoval() async -> Bool {
        guard canRemoveDownloadedModel else { return false }
        await engine.close()
        restoreContext = true
        loadPhase = .initializing
        return true
    }

    private func update(_ id: UUID, mutation: (inout VisionTurn) -> Void) {
        guard let index = session?.turns.firstIndex(where: { $0.id == id }) else { return }
        mutation(&session!.turns[index])
        session?.didChange()
        hasUnsavedChanges = true
    }

    private static func elapsed(since date: Date) -> Int { Int(Date().timeIntervalSince(date) * 1_000) }
}
