import Foundation
import CoreGraphics
import CoreText
import ImageIO

/// Draws the complete archive as searchable text; pagination never screenshots or truncates the chat.
public enum SessionPDF {
    public enum ExportError: LocalizedError {
        case missingPhoto, emptyConversation, cannotWrite, cannotLayOut
        public var errorDescription: String? {
            switch self {
            case .missingPhoto: "La photo de cette conversation est indisponible."
            case .emptyConversation: "Posez une question avant d’exporter cette conversation."
            case .cannotWrite: "Le PDF n’a pas pu être créé. Vérifiez l’espace disponible et réessayez."
            case .cannotLayOut: "Le texte de cette conversation n’a pas pu être exporté."
            }
        }
    }

    public static func write(_ session: VisionSession, photo: Data, to url: URL, photoCredit: String? = nil) throws {
        guard !session.turns.isEmpty else { throw ExportError.emptyConversation }
        guard let source = CGImageSourceCreateWithData(photo as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw ExportError.missingPhoto }
        var page = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        guard let pdf = CGContext(url as CFURL, mediaBox: &page, [kCGPDFContextTitle: "Aperçu - Conversation", kCGPDFContextCreator: "Aperçu"] as CFDictionary) else {
            throw ExportError.cannotWrite
        }
        var closed = false
        var succeeded = false
        defer {
            if !closed { pdf.closePDF() }
            if !succeeded { try? FileManager.default.removeItem(at: url) }
        }
        let text = content(session, photoCredit: photoCredit)
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        var offset = 0
        var number = 0
        repeat {
            number += 1
            pdf.beginPDFPage(nil)
            pdf.setFillColor(CGColor(gray: 1, alpha: 1)); pdf.fill(page)
            line("Aperçu", size: 22, color: navy, at: CGPoint(x: 40, y: 795), in: pdf)
            line("Conversation", size: 10, color: grey, at: CGPoint(x: 447, y: 799), in: pdf)
            pdf.setStrokeColor(navy); pdf.setLineWidth(1)
            pdf.move(to: CGPoint(x: 40, y: 782)); pdf.addLine(to: CGPoint(x: 555, y: 782)); pdf.strokePath()
            var top: CGFloat = 764
            if number == 1 {
                let ratio = min(515 / CGFloat(image.width), 210 / CGFloat(image.height))
                let size = CGSize(width: CGFloat(image.width) * ratio, height: CGFloat(image.height) * ratio)
                pdf.draw(image, in: CGRect(x: 40 + (515 - size.width) / 2, y: top - size.height, width: size.width, height: size.height))
                top -= size.height + 18
            }
            let rectangle = CGRect(x: 40, y: 52, width: 515, height: top - 52)
            var frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), CGPath(rect: rectangle, transform: nil), nil)
            var visible = CTFrameGetVisibleStringRange(frame)
            let lines = CTFrameGetLines(frame) as! [CTLine]
            if offset + visible.length < text.length, lines.count > 1, let last = lines.last {
                let range = CTLineGetStringRange(last)
                if range.location > offset, text.attribute(NSAttributedString.Key("apercu.heading"), at: range.location, effectiveRange: nil) != nil {
                    visible.length = range.location - offset
                    frame = CTFramesetterCreateFrame(framesetter, visible, CGPath(rect: rectangle, transform: nil), nil)
                }
            }
            guard visible.length > 0 else { pdf.endPDFPage(); throw ExportError.cannotLayOut }
            pdf.textMatrix = .identity
            CTFrameDraw(frame, pdf)
            offset += visible.length
            line("Aperçu · \(number)", size: 9, color: grey, at: CGPoint(x: 40, y: 26), in: pdf)
            pdf.endPDFPage()
        } while offset < text.length
        pdf.closePDF(); closed = true
        guard let document = CGPDFDocument(url as CFURL), document.numberOfPages == number else { throw ExportError.cannotWrite }
        succeeded = true
    }

    private static let navy = CGColor(red: 0.145, green: 0.275, blue: 0.373, alpha: 1)
    private static let grey = CGColor(gray: 0.38, alpha: 1)

    private static func content(_ session: VisionSession, photoCredit: String?) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        func append(_ value: String, size: CGFloat = 11, bold: Bool = false, color: CGColor = navy) {
            var spacing: CGFloat = 10
            let paragraph = withUnsafePointer(to: &spacing) { pointer in
                var setting = CTParagraphStyleSetting(spec: .paragraphSpacing, valueSize: MemoryLayout<CGFloat>.size, value: pointer)
                return CTParagraphStyleCreate(&setting, 1)
            }
            var attrs: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
                NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
            ]
            if bold { attrs[NSAttributedString.Key("apercu.heading")] = true }
            result.append(NSAttributedString(string: value + "\n", attributes: attrs))
        }
        let date = DateFormatter(); date.locale = Locale(identifier: "fr_FR"); date.dateStyle = .long; date.timeStyle = .short
        if let photoCredit { append(photoCredit, size: 8, color: grey) }
        append(String(session.title.prefix(160)) + (session.title.count > 160 ? "…" : ""), size: 17, bold: true)
        append("Créée le \(date.string(from: session.createdAt)) · \(session.turns.count) question\(session.turns.count > 1 ? "s" : "")", size: 10, color: grey)
        append("Instructions de l’IA", size: 12, bold: true)
        append(AIInstructions.forSession(session.aiInstructions), size: 10, color: grey)
        for (index, turn) in session.turns.enumerated() {
            append("Question \(index + 1)", size: 12, bold: true)
            append(turn.question)
            let status: String
            switch turn.phase {
            case .finished: status = ""
            case .failed: status = " · échec"
            case .interrupted: status = " · interrompue"
            case .readingImage, .answering: status = " · en cours (copie partielle)"
            }
            append("Réponse \(index + 1)\(status)", size: 12, bold: true)
            append(turn.answer.isEmpty ? "Aucune réponse enregistrée." : turn.answer)
            if let failure = turn.failure { append(failure, size: 10, color: grey) }
        }
        return result
    }

    private static func line(_ text: String, size: CGFloat, color: CGColor, at point: CGPoint, in context: CGContext) {
        let text = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, size, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ])
        context.textMatrix = .identity; context.textPosition = point
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
    }
}
