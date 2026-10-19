import XCTest
import PDFKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import SessionHistory

final class SessionPDFTests: XCTestCase {
    private func photo() throws -> Data {
        let image = try XCTUnwrap(CGContext(data: nil, width: 32, height: 16, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        image.setFillColor(CGColor(red: 1, green: 0.8, blue: 0, alpha: 1)); image.fill(CGRect(x: 0, y: 0, width: 32, height: 16))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    func testLongTranscriptKeepsFirstLastAndUnicodeTextAcrossPages() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        var turns = (1...18).map { VisionTurn(question: "Question originale \($0)", answer: String(repeating: "Réponse détaillée : tuyauterie, état visible et points à vérifier. ", count: 50), phase: .finished) }
        turns[17].answer += " FIN-DU-DOCUMENT - 한글 - 日本語"
        turns[17].phase = .interrupted
        let session = VisionSession(turns: turns, aiInstructions: "INSTRUCTIONS-SAUVEGARDÉES")
        try SessionPDF.write(session, photo: photo(), to: url)
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(pdf.pageCount, 2)
        let text = try XCTUnwrap(pdf.string)
        XCTAssertTrue(text.contains("Question originale 1"))
        XCTAssertTrue(text.contains("Question originale 18"))
        XCTAssertTrue(text.contains("FIN-DU-DOCUMENT"))
        XCTAssertTrue(text.contains("INSTRUCTIONS-SAUVEGARDÉES"))
        XCTAssertTrue(text.contains("interrompue"))
        XCTAssertTrue(text.contains("한글"))
        XCTAssertTrue(text.contains("日本語"))
    }

    func testUnavailablePhotoDoesNotProduceAMisleadingPartialReport() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try SessionPDF.write(VisionSession(turns: [VisionTurn(question: "Test")]), photo: Data(), to: url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
