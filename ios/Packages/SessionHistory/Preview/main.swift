import Foundation
import SessionHistory

let arguments = CommandLine.arguments
precondition(arguments.count == 3, "Usage: ExportPreview OUTPUT_DIRECTORY PHOTO_JPEG")
let directory = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let image = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
let credit = "Photo : Glen Dillon - CC BY 3.0\nhttps://commons.wikimedia.org/wiki/File:MainLineValve7.jpg\nhttps://creativecommons.org/licenses/by/3.0/\nDialogue illustratif de test, sans inférence du modèle."
let turns = [
    VisionTurn(question: "Que voit-on sur cette photo ?", answer: "Une installation de gaz avec une canalisation jaune et une vanne à brides.", phase: .finished),
    VisionTurn(question: "Quels détails sont visibles autour de la vanne ?", answer: "La photo montre les raccords à brides, les boulons et les supports de la canalisation. Elle ne permet pas de confirmer l’état de fonctionnement de l’installation.", phase: .finished),
]
let example = VisionSession(turns: turns, aiInstructions: "Décris les équipements visibles en français, puis indique ce que la photo ne permet pas de vérifier.")
try SessionPDF.write(example, photo: image, to: directory.appendingPathComponent("apercu-session-example.pdf"), photoCredit: credit)
var long = example
long.turns = (1...20).map { VisionTurn(question: "Point de contrôle \($0) : que peut-on observer ?", answer: String(repeating: "Observer les raccords, les supports et la surface visible. Vérifier les informations sur place avant toute décision. ", count: 15), phase: .finished) }
long.turns[19].answer += "Fin de la conversation - 한글 - 日本語."
long.turns[19].phase = .interrupted
try SessionPDF.write(long, photo: image, to: directory.appendingPathComponent("apercu-long-session-example.pdf"), photoCredit: credit)
print("Created short and long native PDF previews.")
