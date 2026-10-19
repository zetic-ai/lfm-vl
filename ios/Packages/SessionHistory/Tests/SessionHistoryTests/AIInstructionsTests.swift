import XCTest
@testable import SessionHistory

final class AIInstructionsTests: XCTestCase {
    func testInstructionSnapshotSurvivesSettingsChangesAndArchiveRoundTrip() throws {
        var session = VisionSession()
        session.appendQuestion("First", instructions: "Original instructions")
        session.appendQuestion("Follow-up", instructions: "Changed settings")
        let restored = try JSONDecoder().decode(VisionSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored.aiInstructions, "Original instructions")
        XCTAssertEqual(restored.turns.count, 2)
        var next = VisionSession()
        next.appendQuestion("New session", instructions: "Changed settings")
        XCTAssertEqual(next.aiInstructions, "Changed settings")
    }

    func testRegeneratingTheOnlyTurnRetainsItsInstructions() {
        var session = VisionSession()
        session.appendQuestion("Only turn", instructions: "Original")
        session.turns.removeLast()
        session.appendQuestion("Only turn", instructions: "Changed setting")
        XCTAssertEqual(session.aiInstructions, "Original")
    }

    func testLegacyArchiveKeepsOriginalInstructionsWhenContinued() throws {
        let legacy = VisionSession(turns: [VisionTurn(question: "Old", phase: .finished)])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        json.removeValue(forKey: "aiInstructions")
        var restored = try JSONDecoder().decode(VisionSession.self, from: JSONSerialization.data(withJSONObject: json))
        restored.appendQuestion("Continue", instructions: "New settings")
        XCTAssertEqual(AIInstructions.forSession(restored.aiInstructions), AIInstructions.defaultValue)
    }

    func testEmptyAndOversizedInstructionsAreRejected() {
        XCTAssertNil(AIInstructions.validated(" \n "))
        XCTAssertNil(AIInstructions.validated(String(repeating: "x", count: 401)))
        XCTAssertEqual(AIInstructions.validated("  Réponds en français.\n"), "Réponds en français.")
    }
}
