import SwiftUI
import SessionHistory

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [VisionSession] = []
    @Published private(set) var isLoaded = false
    @Published private(set) var unreadableCount = 0
    @Published var failure: String?
    let repository: SessionRepository
    private var deletedIDs: Set<UUID> = []

    init(root: URL? = nil) {
        let base = root ?? URL.applicationSupportDirectory.appendingPathComponent("ApercuSessions", isDirectory: true)
        repository = SessionRepository(root: base)
    }

    func load() async {
        do {
            let result = try await repository.load(recoverInterrupted: !isLoaded)
            sessions = result.sessions.filter { !deletedIDs.contains($0.id) }
            unreadableCount = result.unreadableCount
            isLoaded = true
        } catch { failure = "Impossible d’ouvrir l’historique. \(error.localizedDescription)" }
    }

    @discardableResult
    func save(_ session: VisionSession, photo: SessionPhoto? = nil) async -> Bool {
        guard !deletedIDs.contains(session.id) else { return false }
        do {
            try await repository.save(session, photo: photo)
            guard !deletedIDs.contains(session.id) else { return false }
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                if sessions[index].revision < session.revision { sessions[index] = session }
            } else { sessions.append(session) }
            sessions.sort { $0.updatedAt > $1.updatedAt }
            return true
        } catch {
            guard !deletedIDs.contains(session.id) else { return false }
            failure = "La session n’a pas pu être enregistrée. \(error.localizedDescription)"
            return false
        }
    }

    func image(for id: UUID, thumbnail: Bool = false) async throws -> UIImage {
        let data = try await repository.photo(for: id, thumbnail: thumbnail)
        guard let image = UIImage(data: data) else { throw SessionRepository.ArchiveError.missingPhoto }
        return image
    }

    @discardableResult
    func delete(_ id: UUID) async -> Bool {
        deletedIDs.insert(id)
        do {
            try await repository.delete(id)
            sessions.removeAll { $0.id == id }
            return true
        } catch {
            deletedIDs.remove(id)
            failure = "Impossible de supprimer cette session. \(error.localizedDescription)"
            return false
        }
    }

    func deleteAll() async {
        deletedIDs.formUnion(sessions.map(\.id))
        do {
            try await repository.deleteAll()
            sessions = []
            unreadableCount = 0
        } catch {
            if let result = try? await repository.load(recoverInterrupted: false) {
                deletedIDs.subtract(result.sessions.map(\.id))
                sessions = result.sessions
                unreadableCount = result.unreadableCount
            }
            failure = error.localizedDescription
        }
    }
}
