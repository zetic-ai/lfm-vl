import Foundation

/// JSON is the commit point: a new session becomes visible only after both image
/// copies are written. Model files and runtime state never live in this archive.
public actor SessionRepository {
    private struct Record: Codable {
        var version = 1
        let session: VisionSession
    }

    public enum ArchiveError: LocalizedError {
        case invalidRecord, missingPhoto, deletedSession, partialDeletion

        public var errorDescription: String? {
            switch self {
            case .invalidRecord: "Cette session ne peut pas être lue. Ses fichiers ont été conservés."
            case .missingPhoto: "La photo de cette session n’est pas disponible."
            case .deletedSession: "Cette session a été supprimée."
            case .partialDeletion: "Certaines sessions n’ont pas pu être supprimées. Réessayez."
            }
        }
    }

    private let root: URL
    private let files = FileManager.default
    private var deletedIDs: Set<UUID> = []

    public init(root: URL) { self.root = root }

    public func load(recoverInterrupted: Bool = true) throws -> SessionLoadResult {
        try prepareRoot()
        var sessions: [VisionSession] = []
        var unreadable = 0
        for directory in try directories() {
            do {
                let id = UUID(uuidString: directory.lastPathComponent)!
                var session = try readRecord(id: id)
                guard regularFile(directory.appendingPathComponent("photo.jpg")),
                      regularFile(directory.appendingPathComponent("thumbnail.jpg")) else {
                    throw ArchiveError.missingPhoto
                }
                if recoverInterrupted, session.recoverInterruptedTurns() { try writeRecord(session) }
                sessions.append(session)
            } catch {
                // A damaged or newer-format record stays intact for recovery.
                unreadable += 1
            }
        }
        return SessionLoadResult(sessions: sessions.sorted { $0.updatedAt > $1.updatedAt }, unreadableCount: unreadable)
    }

    public func save(_ session: VisionSession, photo: SessionPhoto? = nil) throws {
        guard !deletedIDs.contains(session.id) else { throw ArchiveError.deletedSession }
        guard !session.turns.isEmpty else { throw ArchiveError.invalidRecord }
        try prepareRoot()
        let directory = directory(for: session.id)
        if files.fileExists(atPath: directory.path) {
            guard safeDirectory(directory) else { throw ArchiveError.invalidRecord }
            let metadata = directory.appendingPathComponent("session.json")
            if files.fileExists(atPath: metadata.path) {
                let existing = try readRecord(id: session.id)
                // A delayed checkpoint must never replace a later final answer.
                if existing.revision >= session.revision { return }
            }
        } else {
            guard photo != nil else { throw ArchiveError.missingPhoto }
            try files.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        if let photo {
            try write(photo.image, to: directory.appendingPathComponent("photo.jpg"))
            try write(photo.thumbnail, to: directory.appendingPathComponent("thumbnail.jpg"))
        }
        guard regularFile(directory.appendingPathComponent("photo.jpg")),
              regularFile(directory.appendingPathComponent("thumbnail.jpg")) else { throw ArchiveError.missingPhoto }
        try writeRecord(session)
    }

    public func photo(for id: UUID, thumbnail: Bool = false) throws -> Data {
        let directory = directory(for: id)
        guard safeDirectory(directory) else { throw ArchiveError.missingPhoto }
        let url = directory.appendingPathComponent(thumbnail ? "thumbnail.jpg" : "photo.jpg")
        guard regularFile(url) else { throw ArchiveError.missingPhoto }
        return try Data(contentsOf: url)
    }

    public func delete(_ id: UUID) throws {
        let url = directory(for: id)
        if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
        deletedIDs.insert(id)
    }

    public func deleteAll() throws {
        try prepareRoot()
        var failed = false
        for directory in try directories(includeSymbolicLinks: true) {
            let id = UUID(uuidString: directory.lastPathComponent)!
            do { try delete(id) } catch { failed = true }
        }
        if failed { throw ArchiveError.partialDeletion }
    }

    private func prepareRoot() throws {
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        var url = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    private func directory(for id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }

    private func directories(includeSymbolicLinks: Bool = false) throws -> [URL] {
        try files.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            .filter { url in
                guard UUID(uuidString: url.lastPathComponent) != nil else { return false }
                return includeSymbolicLinks || safeDirectory(url)
            }
    }

    private func safeDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private func regularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else { return false }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private func readRecord(id: UUID) throws -> VisionSession {
        let directory = directory(for: id)
        let url = directory.appendingPathComponent("session.json")
        guard safeDirectory(directory), regularFile(url) else { throw ArchiveError.invalidRecord }
        let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
        guard record.version == 1, record.session.id == id, !record.session.turns.isEmpty else { throw ArchiveError.invalidRecord }
        return record.session
    }

    private func writeRecord(_ session: VisionSession) throws {
        try write(JSONEncoder().encode(Record(session: session)), to: directory(for: session.id).appendingPathComponent("session.json"))
    }

    private func write(_ data: Data, to url: URL) throws {
        if files.fileExists(atPath: url.path), !regularFile(url) { throw ArchiveError.invalidRecord }
        var options: Data.WritingOptions = .atomic
        #if os(iOS)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try data.write(to: url, options: options)
    }
}
