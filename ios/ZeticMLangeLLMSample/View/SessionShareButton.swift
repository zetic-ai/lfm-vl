import SwiftUI
import SessionHistory

struct SessionShareButton: View {
    let session: VisionSession
    let photo: () async throws -> Data
    var enabled = true
    @State private var preparing = false
    @State private var file: ExportFile?
    @State private var pendingURL: URL?
    @State private var failure: String?

    private struct ExportFile: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        Button {
            preparing = true
            Task {
                defer { preparing = false }
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ApercuExports", isDirectory: true)
                let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                let date = DateFormatter(); date.locale = Locale(identifier: "en_US_POSIX"); date.dateFormat = "yyyy-MM-dd-HHmm"
                let url = folder.appendingPathComponent("Apercu-\(date.string(from: session.createdAt)).pdf")
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    // Remove only expired temporary exports; never archived photos/transcripts.
                    for old in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
                        if let date = try? old.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                           date < Date().addingTimeInterval(-86400) { try? FileManager.default.removeItem(at: old) }
                    }
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let data = try await photo()
                    #if DEBUG
                    let credit = ProcessInfo.processInfo.arguments.contains("-apercu-ui-testing")
                        ? "Photo : Glen Dillon - CC BY 3.0\nhttps://commons.wikimedia.org/wiki/File:MainLineValve7.jpg\nhttps://creativecommons.org/licenses/by/3.0/" : nil
                    #else
                    let credit: String? = nil
                    #endif
                    try await Task.detached(priority: .userInitiated) {
                        try SessionPDF.write(session, photo: data, to: url, photoCredit: credit)
                    }.value
                    pendingURL = url
                    file = ExportFile(url: url)
                } catch {
                    try? FileManager.default.removeItem(at: folder)
                    failure = error.localizedDescription
                }
            }
        } label: {
            if preparing { ProgressView().frame(width: 44, height: 44) }
            else { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }
        }
        .disabled(!enabled || preparing || session.turns.isEmpty)
        .accessibilityLabel(preparing ? "Préparation du PDF" : "Partager la session en PDF")
        .sheet(item: $file, onDismiss: {
            if let pendingURL { try? FileManager.default.removeItem(at: pendingURL.deletingLastPathComponent()) }
            pendingURL = nil
        }) { item in
            ActivityShareSheet(url: item.url) { file = nil }
        }
        .alert("Export impossible", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("Fermer", role: .cancel) {}
        } message: { Text(failure ?? "") }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL
    let completed: () -> Void
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in DispatchQueue.main.async(execute: completed) }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
