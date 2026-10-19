import XCTest
@testable import SessionHistory

final class SessionHistoryTests: XCTestCase {
    private var root: URL!
    private let photo = SessionPhoto(image: Data([1, 2, 3]), thumbnail: Data([4, 5]))

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ApercuTests-\(UUID())")
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }

    private func sample(_ question: String = "Que voit-on ?") -> VisionSession {
        var session = VisionSession(turns: [VisionTurn(question: question, answer: "Une vanne « V-07 ».", phase: .finished)])
        session.didChange()
        return session
    }

    func testRelaunchRestoresPhotoTranscriptAndStableIDs() async throws {
        let session = sample()
        try await SessionRepository(root: root).save(session, photo: photo)
        let reopened = SessionRepository(root: root)
        let report = try await reopened.load()
        XCTAssertEqual(report.sessions, [session])
        let original = try await reopened.photo(for: session.id)
        let thumbnail = try await reopened.photo(for: session.id, thumbnail: true)
        XCTAssertEqual(original, photo.image)
        XCTAssertEqual(thumbnail, photo.thumbnail)
        XCTAssertEqual(report.unreadableCount, 0)
    }

    func testSessionOrderUsesMostRecentActivity() async throws {
        let repository = SessionRepository(root: root)
        var older = sample("Ancienne photo")
        older.updatedAt = Date(timeIntervalSince1970: 100)
        let recent = sample("Nouvelle photo")
        try await repository.save(older, photo: photo)
        try await repository.save(recent, photo: photo)
        older.didChange(at: Date().addingTimeInterval(60))
        try await repository.save(older)
        let report = try await repository.load()
        XCTAssertEqual(report.sessions.map(\.id), [older.id, recent.id])
        XCTAssertEqual(report.sessions[0].title, "Ancienne photo")
    }

    func testFirstQuestionRequiresPhotoAndDoesNotCreateEmptyArchiveEntry() async throws {
        let repository = SessionRepository(root: root)
        do { try await repository.save(sample()); XCTFail("Missing photo should fail") } catch {}
        let report = try await repository.load()
        XCTAssertTrue(report.sessions.isEmpty)
        XCTAssertEqual(report.unreadableCount, 0)
    }

    func testDraftWithoutQuestionsIsNotSaved() async throws {
        let repository = SessionRepository(root: root)
        do { try await repository.save(VisionSession(), photo: photo); XCTFail("Draft should fail") } catch {}
        let report = try await repository.load()
        XCTAssertTrue(report.sessions.isEmpty)
    }

    func testDelayedCheckpointCannotOverwriteFinalAnswer() async throws {
        let repository = SessionRepository(root: root)
        let checkpoint = sample()
        try await repository.save(checkpoint, photo: photo)
        var final = checkpoint
        final.turns[0].answer = "Réponse complète"
        final.didChange()
        try await repository.save(final)
        try await repository.save(checkpoint)
        let report = try await repository.load()
        XCTAssertEqual(report.sessions[0], final)
    }

    func testInterruptedStreamRetainsPartialTextAndRecoversOnce() async throws {
        let repository = SessionRepository(root: root)
        var session = sample()
        session.turns[0].phase = .answering
        session.turns[0].answer = "Texte partiel"
        try await repository.save(session, photo: photo)
        let first = try await repository.load()
        XCTAssertEqual(first.sessions[0].turns[0].phase, .interrupted)
        XCTAssertEqual(first.sessions[0].turns[0].answer, "Texte partiel")
        let second = try await SessionRepository(root: root).load()
        XCTAssertEqual(second.sessions, first.sessions)
    }

    func testReadingHistoryDoesNotInterruptAnActiveStream() async throws {
        let repository = SessionRepository(root: root)
        var session = sample()
        session.turns[0].phase = .answering
        try await repository.save(session, photo: photo)
        let report = try await repository.load(recoverInterrupted: false)
        XCTAssertEqual(report.sessions[0].turns[0].phase, .answering)
        XCTAssertEqual(report.sessions[0].revision, session.revision)
    }

    func testDeleteRemovesMediaAndRejectsLateSaves() async throws {
        let repository = SessionRepository(root: root)
        var session = sample()
        try await repository.save(session, photo: photo)
        try await repository.delete(session.id)
        session.didChange()
        do { try await repository.save(session, photo: photo); XCTFail("Deleted session must not return") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(session.id.uuidString).path))
        let report = try await repository.load()
        XCTAssertTrue(report.sessions.isEmpty)
    }

    func testCorruptRecordIsReportedAndPreserved() async throws {
        let repository = SessionRepository(root: root)
        let session = sample()
        try await repository.save(session, photo: photo)
        let file = root.appendingPathComponent(session.id.uuidString).appendingPathComponent("session.json")
        let corrupt = Data("broken record".utf8)
        try corrupt.write(to: file)
        let report = try await repository.load()
        XCTAssertEqual(report.unreadableCount, 1)
        XCTAssertTrue(report.sessions.isEmpty)
        do { try await repository.save(session, photo: photo); XCTFail("Do not overwrite a damaged record") } catch {}
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }

    func testMissingPhotoIsReportedWithoutDeletingTranscript() async throws {
        let repository = SessionRepository(root: root)
        let session = sample()
        try await repository.save(session, photo: photo)
        let directory = root.appendingPathComponent(session.id.uuidString)
        try FileManager.default.removeItem(at: directory.appendingPathComponent("photo.jpg"))
        let report = try await repository.load()
        XCTAssertEqual(report.unreadableCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("session.json").path))
    }

    func testClearHistoryRemovesReadableAndDamagedEntries() async throws {
        let repository = SessionRepository(root: root)
        let first = sample()
        let second = sample("Autre photo")
        try await repository.save(first, photo: photo)
        try await repository.save(second, photo: photo)
        try Data("broken".utf8).write(to: root.appendingPathComponent(first.id.uuidString).appendingPathComponent("session.json"))
        try await repository.deleteAll()
        let report = try await repository.load()
        XCTAssertTrue(report.sessions.isEmpty)
        XCTAssertEqual(report.unreadableCount, 0)
    }

    func testResumeContextUsesCompletedExchangesInChronologicalOrder() throws {
        let turns = [
            VisionTurn(question: "Q1", answer: "A1", phase: .finished),
            VisionTurn(question: "Q2", answer: "partial", phase: .interrupted),
            VisionTurn(question: "Q3", answer: "A3", phase: .finished),
        ]
        let prompt = ConversationContext.restoredQuestion("Q4", turns: turns, historyTokenBudget: 1000, tokenCount: { $0.count })
        XCTAssertTrue(prompt.contains("Q1"))
        XCTAssertTrue(prompt.contains("Q3"))
        XCTAssertTrue(prompt.hasSuffix("Q4"))
        XCTAssertFalse(prompt.contains("Q2"))
        XCTAssertFalse(prompt.contains("partial"))
        XCTAssertLessThan(prompt.range(of: "Q1")!.lowerBound, prompt.range(of: "Q3")!.lowerBound)
    }

    func testResumeBudgetDropsOlderExchangesWithoutChangingArchive() throws {
        let turns = [VisionTurn(question: "OLD", answer: "Older answer", phase: .finished),
                     VisionTurn(question: "NEW", answer: "Recent answer", phase: .finished)]
        let prompt = ConversationContext.restoredQuestion("NEXT", turns: turns, historyTokenBudget: 60, tokenCount: { $0.count })
        XCTAssertTrue(prompt.contains("NEW"))
        XCTAssertFalse(prompt.contains("OLD"))
        XCTAssertEqual(turns.count, 2)
        XCTAssertEqual(turns[0].answer, "Older answer")
    }

    func testEmptyOrOverBudgetContextLeavesNewQuestionIntact() throws {
        let turns = [VisionTurn(question: "Long", answer: "Answer", phase: .finished)]
        XCTAssertEqual(ConversationContext.restoredQuestion("Next", turns: turns, historyTokenBudget: 0, tokenCount: { $0.count }), "Next")
        XCTAssertEqual(ConversationContext.restoredQuestion("Next", turns: [], historyTokenBudget: 100, tokenCount: { $0.count }), "Next")
    }
}
