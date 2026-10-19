import Foundation

public struct VisionTurn: Identifiable, Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable {
        case readingImage, answering, finished, failed, interrupted
    }

    public let id: UUID
    public let question: String
    public var answer: String
    public var failure: String?
    public var phase: Phase
    public var firstTokenMs: Int?
    public var durationMs: Int?

    public init(id: UUID = UUID(), question: String, answer: String = "", phase: Phase = .readingImage) {
        self.id = id
        self.question = question
        self.answer = answer
        self.phase = phase
    }

    public var isStreaming: Bool { phase == .readingImage || phase == .answering }

    public var approximateTokensPerSecond: Double? {
        guard let durationMs, let firstTokenMs, durationMs > firstTokenMs, !answer.isEmpty else { return nil }
        return (Double(answer.count) / 4) / (Double(durationMs - firstTokenMs) / 1_000)
    }
}

public struct VisionSession: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public var updatedAt: Date
    public var revision: Int
    public var turns: [VisionTurn]
    public var aiInstructions: String?

    public init(id: UUID = UUID(), createdAt: Date = Date(), turns: [VisionTurn] = [], aiInstructions: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.revision = 0
        self.turns = turns
        self.aiInstructions = aiInstructions
    }

    @discardableResult
    public mutating func appendQuestion(_ question: String, instructions: String) -> VisionTurn {
        if turns.isEmpty && aiInstructions == nil { aiInstructions = instructions }
        let turn = VisionTurn(question: question)
        turns.append(turn)
        didChange()
        return turn
    }

    public var title: String { turns.first?.question ?? "Nouvelle session" }

    public mutating func didChange(at date: Date = Date()) {
        updatedAt = date
        revision += 1
    }

    @discardableResult
    public mutating func recoverInterruptedTurns() -> Bool {
        var changed = false
        for index in turns.indices where turns[index].isStreaming {
            turns[index].phase = .interrupted
            changed = true
        }
        if changed { revision += 1 }
        return changed
    }
}

public struct SessionPhoto: Sendable {
    public let image: Data
    public let thumbnail: Data

    public init(image: Data, thumbnail: Data) {
        self.image = image
        self.thumbnail = thumbnail
    }
}

public struct SessionLoadResult: Sendable {
    public let sessions: [VisionSession]
    public let unreadableCount: Int
}
