import SwiftUI

struct SessionHistoryView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var chat: VisionChatViewModel
    let openSession: (UUID) -> Void
    let newSession: () -> Void
    @State private var confirmClear = false

    private var days: [Date] {
        Set(store.sessions.map { Calendar.current.startOfDay(for: $0.updatedAt) }).sorted(by: >)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Historique").font(LfmPalette.title())
                Text("Vos photos, vos conversations.").foregroundStyle(LfmPalette.secondary)
                if !store.isLoaded {
                    ProgressView("Ouverture de l’historique…").padding(.vertical, 32)
                    Button("Réessayer") { Task { await store.load() } }.buttonStyle(ApercuActionStyle(primary: false))
                } else if store.sessions.isEmpty && store.unreadableCount == 0 {
                    ContentUnavailableView {
                        Label("Votre historique commence ici.", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("Choisissez une photo et posez votre première question.")
                    } actions: {
                        Button("Nouvelle session", action: newSession).buttonStyle(ApercuActionStyle())
                            .disabled(!chat.canLeaveSession)
                    }
                } else {
                    ForEach(days, id: \.self) { day in
                        Text(dayTitle(day)).font(LfmPalette.medium(12)).foregroundStyle(LfmPalette.secondary)
                            .padding(.top, 8)
                        LazyVStack(spacing: 0) {
                            ForEach(store.sessions.filter { Calendar.current.isDate($0.updatedAt, inSameDayAs: day) }) { session in
                                Button { openSession(session.id) } label: {
                                    SessionHistoryRow(session: session, store: store)
                                }.buttonStyle(.plain)
                                Divider().overlay(LfmPalette.divider)
                            }
                        }
                    }
                }
                if store.unreadableCount > 0 {
                    Label("Certaines sessions ne peuvent pas être lues. Leurs fichiers ont été conservés.", systemImage: "exclamationmark.triangle")
                        .font(LfmPalette.body(13)).foregroundStyle(LfmPalette.error)
                }
                LocalSessionNote().padding(.top, 24)
                if !store.sessions.isEmpty || store.unreadableCount > 0 {
                    Button(role: .destructive) { confirmClear = true } label: {
                        Label("Effacer l’historique", systemImage: "trash").frame(minHeight: 44)
                    }.font(LfmPalette.body(13)).disabled(!chat.canLeaveSession)
                }
            }.padding(LfmLayout.screen).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(LfmPalette.background)
        .confirmationDialog("Effacer l’historique ?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Tout supprimer", role: .destructive) {
                Task {
                    guard chat.canLeaveSession else { return }
                    await store.deleteAll()
                    if let id = chat.session?.id, !store.sessions.contains(where: { $0.id == id }) {
                        chat.forgetDeletedSession(id)
                    }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: { Text("Les photos et les conversations enregistrées seront supprimées de cet iPhone.") }
    }

    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Aujourd’hui" }
        if Calendar.current.isDateInYesterday(date) { return "Hier" }
        return date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "fr_FR")))
    }
}

private struct SessionHistoryRow: View {
    let session: VisionSession
    @ObservedObject var store: SessionStore
    @State private var image: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image { Image(uiImage: image).resizable().scaledToFill() }
                else { Image(systemName: "photo").frame(maxWidth: .infinity, maxHeight: .infinity).background(LfmPalette.surfaceSubtle) }
            }.frame(width: 64, height: 64).clipped().clipShape(RoundedRectangle(cornerRadius: LfmLayout.controlRadius))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title).font(LfmPalette.medium(14)).lineLimit(2)
                Text("\(session.updatedAt.formatted(.dateTime.hour().minute().locale(Locale(identifier: "fr_FR")))) · \(session.turns.count) question\(session.turns.count > 1 ? "s" : "")")
                    .font(LfmPalette.body(11)).foregroundStyle(LfmPalette.secondary)
                if let last = session.turns.last {
                    Text(last.phase == .interrupted ? "Réponse interrompue" : last.answer)
                        .font(LfmPalette.body(12)).foregroundStyle(LfmPalette.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(LfmPalette.secondary)
        }
        .padding(.vertical, 12).contentShape(Rectangle()).foregroundStyle(LfmPalette.ink)
        .task(id: session.id) { image = try? await store.image(for: session.id, thumbnail: true) }
    }
}

struct SessionReviewView: View {
    let id: UUID
    @ObservedObject var store: SessionStore
    @ObservedObject var chat: VisionChatViewModel
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var photo: UIImage?
    @State private var showPhoto = false
    @State private var confirmDelete = false

    private var session: VisionSession? { store.sessions.first { $0.id == id } }
    private var canModify: Bool { chat.session?.id != id || chat.canLeaveSession }

    var body: some View {
        Group {
            if let session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(session.createdAt.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(Locale(identifier: "fr_FR"))))
                            .font(LfmPalette.body(12)).foregroundStyle(LfmPalette.secondary)
                        if let photo {
                            Button { showPhoto = true } label: {
                                Image(uiImage: photo).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 240)
                                    .background(LfmPalette.surfaceSubtle).clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .padding(12).background(LfmPalette.surface, in: RoundedRectangle(cornerRadius: LfmLayout.controlRadius)).padding(8)
                                    }
                            }.buttonStyle(.plain).accessibilityLabel("Agrandir la photo")
                            #if DEBUG
                            if ProcessInfo.processInfo.arguments.contains("-apercu-ui-testing") {
                                HStack(spacing: 4) {
                                    Link("Photo : Glen Dillon", destination: URL(string: "https://commons.wikimedia.org/wiki/File:MainLineValve7.jpg")!)
                                    Text("·")
                                    Link("CC BY 3.0", destination: URL(string: "https://creativecommons.org/licenses/by/3.0/")!)
                                }.font(LfmPalette.body(10)).foregroundStyle(LfmPalette.secondary)
                            }
                            #endif
                        } else {
                            Label("Photo indisponible", systemImage: "photo").foregroundStyle(LfmPalette.secondary)
                        }
                        ForEach(session.turns) { turn in
                            AnswerBubble(turn: turn, isLast: false, onRegenerate: {})
                        }
                    }.padding(LfmLayout.screen).frame(maxWidth: 640).frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView("Session indisponible", systemImage: "clock.arrow.circlepath")
            }
        }
        .background(LfmPalette.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if session != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Conversation enregistrée", systemImage: "book")
                        .font(LfmPalette.body(12)).foregroundStyle(LfmPalette.secondary)
                    Button("Continuer la conversation", systemImage: "bubble.left", action: onContinue)
                        .buttonStyle(ApercuActionStyle()).disabled(photo == nil || !chat.canLeaveSession)
                    if !chat.canLeaveSession {
                        Text("Terminez ou arrêtez la réponse en cours, puis enregistrez-la avant de continuer une autre session.")
                            .font(LfmPalette.body(12)).foregroundStyle(LfmPalette.secondary)
                    }
                }.padding(.horizontal, LfmLayout.screen).padding(.vertical, 12).background(LfmPalette.surface)
            }
        }
        .toolbar {
            if let session {
                ToolbarItem(placement: .topBarTrailing) {
                    SessionShareButton(session: session, photo: { try await store.repository.photo(for: id) }, enabled: canModify)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Supprimer cette session", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    .disabled(!canModify)
            }
        }
        .task(id: id) {
            do { photo = try await store.image(for: id) }
            catch { store.failure = error.localizedDescription }
        }
        .fullScreenCover(isPresented: $showPhoto) {
            if let photo { ZoomableImageView(image: photo) }
        }
        .confirmationDialog("Supprimer cette session ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                Task {
                    guard canModify else { return }
                    if await store.delete(id) { chat.forgetDeletedSession(id); dismiss() }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: { Text("Cette photo et sa conversation seront supprimées de cet iPhone.") }
    }
}
