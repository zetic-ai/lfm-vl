import SwiftUI
import SessionHistory

struct AISettingsView: View {
    @ObservedObject var instructions: AIInstructionStore
    @State private var draft = ""
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Instructions de l’IA").font(LfmPalette.title())
                Text("Précisez le rôle de l’assistant, le niveau de détail ou le format des réponses.")
                    .foregroundStyle(LfmPalette.secondary)
                Text("Vos instructions").font(LfmPalette.medium(13))
                TextEditor(text: $draft)
                    .font(LfmPalette.body()).scrollContentBackground(.hidden)
                    .frame(minHeight: 192).padding(12).background(LfmPalette.surface)
                    .overlay(RoundedRectangle(cornerRadius: LfmLayout.controlRadius).stroke(LfmPalette.divider))
                    .accessibilityLabel("Vos instructions")
                    .onChange(of: draft) { _, _ in saved = false }
                Text("\(draft.count) / \(AIInstructions.maximumCharacters) caractères")
                    .font(LfmPalette.body(12))
                    .foregroundStyle(draft.count > AIInstructions.maximumCharacters ? LfmPalette.error : LfmPalette.secondary)
                Text("Les modifications s’appliquent aux nouvelles conversations. Les conversations déjà commencées conservent leurs instructions.")
                    .font(LfmPalette.body(13)).foregroundStyle(LfmPalette.secondary)
                Button("Enregistrer les instructions") { saved = instructions.save(draft) }
                    .buttonStyle(ApercuActionStyle())
                    .disabled(AIInstructions.validated(draft) == nil || draft == instructions.value)
                Button("Rétablir les instructions par défaut") { draft = AIInstructions.defaultValue }
                    .buttonStyle(ApercuActionStyle(primary: false))
                if saved {
                    Label("Instructions enregistrées", systemImage: "checkmark.circle")
                        .font(LfmPalette.body(13)).accessibilityAddTraits(.updatesFrequently)
                }
            }.padding(LfmLayout.screen).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }.background(LfmPalette.background).navigationTitle("Paramètres")
            .onAppear { draft = instructions.value }
    }
}
