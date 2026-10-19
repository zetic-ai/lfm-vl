import SwiftUI

struct AnswerBubble: View {
    let turn: VisionTurn
    let isLast: Bool
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(turn.question).font(LfmPalette.body(14))
                .padding(12).background(LfmPalette.surfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity, alignment: .trailing)
            if !turn.answer.isEmpty {
                Text(turn.answer).font(LfmPalette.body()).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if turn.isStreaming {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(turn.phase == .readingImage ? "Analyse de la photo…" : "Réponse en cours…")
                        .font(LfmPalette.body(12)).foregroundStyle(LfmPalette.secondary)
                }.accessibilityElement(children: .combine)
            }
            if turn.phase == .interrupted {
                Label("Réponse interrompue", systemImage: "pause.circle")
                    .font(LfmPalette.body(12)).foregroundStyle(LfmPalette.secondary)
            }
            if let failure = turn.failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(LfmPalette.body(13)).foregroundStyle(LfmPalette.error)
            }
            if !turn.isStreaming {
                HStack(spacing: 8) {
                    if !turn.answer.isEmpty {
                        Button { UIPasteboard.general.string = turn.answer } label: { Label("Copier", systemImage: "doc.on.doc") }
                            .font(LfmPalette.body(12)).frame(minHeight: 44)
                        Spacer()
                        ShareLink(item: turn.answer) { Image(systemName: "square.and.arrow.up") }
                            .buttonStyle(ApercuIconStyle()).accessibilityLabel("Partager la réponse")
                    }
                    if isLast {
                        Button(action: onRegenerate) { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(ApercuIconStyle()).accessibilityLabel("Générer à nouveau")
                    }
                }.foregroundStyle(LfmPalette.secondary)
            }
        }.foregroundStyle(LfmPalette.ink).padding(.vertical, 4)
    }
}
