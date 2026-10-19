import PhotosUI
import SwiftUI

struct ContentView: View {
    private enum Route: Hashable { case menu, history, session(UUID), model }
    @StateObject private var store: SessionStore
    @StateObject private var chat: VisionChatViewModel
    @StateObject private var download = VisionModelDownloadCoordinator()
    @StateObject private var network = NetworkPathObserver()
    @State private var path: [Route] = []
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var chooseSource = false
    @State private var librarySelection: PhotosPickerItem?
    @State private var showPhoto = false
    @State private var confirmRemoveModel = false
    @State private var message: String?
    @FocusState private var questionFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        let root = ProcessInfo.processInfo.arguments.contains("-apercu-ui-testing")
            ? URL.applicationSupportDirectory.appendingPathComponent("ApercuUITestSessions") : nil
        #else
        let root: URL? = nil
        #endif
        let store = SessionStore(root: root)
        _store = StateObject(wrappedValue: store)
        _chat = StateObject(wrappedValue: VisionChatViewModel(store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack(path: $path) {
                home
                    .navigationTitle("Aperçu")
                    .apercuNavigation()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Menu", systemImage: "line.3.horizontal") { path.append(.menu) }
                        }
                    }
                    .navigationDestination(for: Route.self) { route in
                        destination(route).apercuNavigation()
                    }
            }
            ZeticFooter()
        }
        .tint(LfmPalette.accent)
        .font(LfmPalette.body())
        .foregroundStyle(LfmPalette.ink)
        .task {
            await store.load()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-apercu-ui-testing") {
                await UITestFixtures.seed(store)
                path = [.menu, .history]
                return
            }
            #endif
            download.resumeIfConsented()
            await loadInstalledModel()
        }
        .onChange(of: download.phase) { _, phase in
            if phase == .installed { Task { await loadInstalledModel() } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { _ = await chat.persistCurrent() } }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in _ = chat.select(image) }.ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showPhoto) {
            if let image = chat.image { ZoomableImageView(image: image) }
        }
        .photosPicker(isPresented: $showLibrary, selection: $librarySelection, matching: .images)
        .onChange(of: librarySelection) { _, item in
            guard let item else { return }
            guard chat.beginPhotoSelection() else { librarySelection = nil; return }
            Task {
                defer { chat.finishPhotoSelection(nil); librarySelection = nil }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                        message = "Cette photo ne peut pas être ouverte."
                        return
                    }
                    chat.finishPhotoSelection(image)
                } catch { message = "Impossible d’ouvrir cette photo. \(error.localizedDescription)" }
            }
        }
        .confirmationDialog("Choisir une photo", isPresented: $chooseSource, titleVisibility: .visible) {
            Button("Prendre une photo") { showCamera = true }.disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            Button("Ouvrir la galerie") { showLibrary = true }
            Button("Annuler", role: .cancel) {}
        } message: { Text("Une nouvelle photo ouvre une nouvelle session. La conversation actuelle reste dans l’historique.") }
        .confirmationDialog("Supprimer le modèle téléchargé ?", isPresented: $confirmRemoveModel, titleVisibility: .visible) {
            Button("Supprimer le modèle", role: .destructive) { Task { await removeModel() } }
            Button("Annuler", role: .cancel) {}
        } message: { Text("Vos photos et conversations restent dans l’historique. Le modèle devra être téléchargé à nouveau pour poser une question.") }
        .alert("Historique", isPresented: Binding(get: { store.failure != nil }, set: { if !$0 { store.failure = nil } })) {
            Button("Réessayer") {
                Task {
                    if chat.hasUnsavedChanges { _ = await chat.persistCurrent() }
                    else { await store.load() }
                }
            }
            Button("Fermer", role: .cancel) {}
        } message: { Text(store.failure ?? "") }
        .alert("Aperçu", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Fermer", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    @ViewBuilder private var home: some View {
        if download.canUseDownloadedModel && chat.isModelReady { chatScreen }
        else { modelScreen }
    }

    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case .menu:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Menu").font(LfmPalette.title())
                    Text("Retrouvez vos conversations.").foregroundStyle(LfmPalette.secondary)
                    VStack(spacing: 0) {
                        ApercuMenuRow(title: "Nouvelle session", subtitle: "Choisir une autre photo", symbol: "photo.badge.plus", action: newSession)
                            .disabled(!chat.canLeaveSession)
                        ApercuMenuRow(title: "Historique", subtitle: "Photos et conversations", symbol: "clock.arrow.circlepath") { path.append(.history) }
                        ApercuMenuRow(title: "Modèle", subtitle: "Gérer le modèle téléchargé", symbol: "slider.horizontal.3") { path.append(.model) }
                    }
                    LocalSessionNote().padding(.top, 24)
                }.padding(20).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }.navigationTitle("Menu")
        case .history:
            SessionHistoryView(store: store, chat: chat, openSession: { path.append(.session($0)) }, newSession: newSession)
                .navigationTitle("Historique")
        case let .session(id):
            SessionReviewView(id: id, store: store, chat: chat) {
                Task {
                    guard let saved = store.sessions.first(where: { $0.id == id }) else { return }
                    if await chat.resume(saved) { path = [] }
                }
            }.navigationTitle("Conversation")
        case .model:
            modelScreen.navigationTitle("Modèle")
        }
    }

    private var chatScreen: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if chat.hasUnsavedChanges && !chat.isGenerating {
                        Label("Cette session n’est pas encore enregistrée.", systemImage: "exclamationmark.triangle")
                            .font(LfmPalette.body(13)).foregroundStyle(LfmPalette.error)
                        Button("Réessayer l’enregistrement") { Task { _ = await chat.persistCurrent() } }
                            .buttonStyle(ApercuActionStyle(primary: false))
                    }
                    if let image = chat.image {
                        photoArea(image)
                        if chat.turns.isEmpty {
                            HStack(spacing: 8) {
                                Button("Décrire", systemImage: "viewfinder") { chat.ask("Que voit-on sur cette photo ?") }
                                Button("Lire le texte", systemImage: "text.viewfinder") { chat.ask("Pouvez-vous lire le texte ?") }
                            }.buttonStyle(ApercuActionStyle(primary: false)).disabled(!chat.isModelReady || chat.isRestoring)
                            Text("Que souhaitez-vous savoir sur cette photo ?").foregroundStyle(LfmPalette.secondary)
                        }
                        ForEach(chat.turns) { turn in
                            AnswerBubble(turn: turn, isLast: turn.id == chat.turns.last?.id) { chat.regenerateLast() }
                                .id(turn.id)
                        }
                    } else {
                        Text("Une photo.\nDes réponses.").font(LfmPalette.title())
                        Text("Choisissez une photo, puis posez votre question.").foregroundStyle(LfmPalette.secondary)
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus").font(.system(size: 32)).accessibilityHidden(true)
                            Text("Un objet, un document, une scène.").font(LfmPalette.body(13))
                        }
                        .foregroundStyle(LfmPalette.secondary).frame(maxWidth: .infinity, minHeight: 144)
                        .background(LfmPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                        VStack(spacing: 8) {
                            Button("Prendre une photo", systemImage: "camera") { showCamera = true }
                                .buttonStyle(ApercuActionStyle()).disabled(chat.isRestoring || !UIImagePickerController.isSourceTypeAvailable(.camera))
                            Button("Choisir une photo", systemImage: "photo.on.rectangle") { showLibrary = true }
                                .buttonStyle(ApercuActionStyle(primary: false)).disabled(chat.isRestoring)
                        }
                        LocalSessionNote().padding(.top, 32)
                    }
                }.padding(20).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }
            .onChange(of: chat.turns.count) { _, _ in
                if let id = chat.turns.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
        .background(LfmPalette.background)
        .safeAreaInset(edge: .bottom, spacing: 0) { if chat.image != nil { composer } }
    }

    private func photoArea(_ image: UIImage) -> some View {
        Button { showPhoto = true } label: {
            Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 240)
                .background(LfmPalette.surfaceSubtle).clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).accessibilityLabel("Agrandir la photo")
        .overlay(alignment: .topTrailing) {
            Button("Changer", systemImage: "arrow.triangle.2.circlepath") { chooseSource = true }
                .font(LfmPalette.body(12)).padding(8).frame(minHeight: 44)
                .background(LfmPalette.surface, in: RoundedRectangle(cornerRadius: 8)).padding(8)
                .disabled(!chat.canLeaveSession)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Votre question").font(LfmPalette.medium(12))
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Que voulez-vous savoir ?", text: $chat.question, axis: .vertical)
                    .font(LfmPalette.body(16)).lineLimit(1...4).padding(10)
                    .background(LfmPalette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(LfmPalette.divider, lineWidth: 1))
                    .focused($questionFocused).submitLabel(.send)
                    .onSubmit { questionFocused = false; chat.ask() }
                    .accessibilityLabel("Votre question")
                Button {
                    questionFocused = false
                    if chat.isGenerating { chat.cancelGeneration() } else { chat.ask() }
                } label: {
                    Image(systemName: chat.isGenerating ? "stop.fill" : "arrow.up")
                        .frame(width: 44, height: 44).background(LfmPalette.accent).foregroundStyle(LfmPalette.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(!chat.isGenerating && !chat.canAsk)
                .opacity(!chat.isGenerating && !chat.canAsk ? 0.5 : 1)
                .accessibilityLabel(chat.isGenerating ? "Arrêter la réponse" : "Envoyer la question")
            }
        }.padding(.horizontal, 20).padding(.vertical, 12).background(LfmPalette.surface)
    }

    private var modelScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(download.canUseDownloadedModel ? "Votre assistant,\nsur cet iPhone." : "Première utilisation")
                    .font(LfmPalette.title())
                if download.canUseDownloadedModel && chat.isModelReady {
                    Text("Le modèle est prêt pour analyser vos photos.").foregroundStyle(LfmPalette.secondary)
                    Button("Nouvelle session", action: newSession).buttonStyle(ApercuActionStyle()).disabled(!chat.canLeaveSession)
                } else if download.failureMessage != nil || chat.loadFailure != nil {
                    Label("Le modèle n’est pas disponible.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(LfmPalette.error)
                    Text("Vérifiez votre connexion et l’espace disponible, puis réessayez.")
                        .font(LfmPalette.body(13)).foregroundStyle(LfmPalette.secondary)
                    Button("Réessayer") {
                        if download.canUseDownloadedModel { chat.retryLoad() } else { download.retry() }
                    }.buttonStyle(ApercuActionStyle())
                } else if download.isBackgroundDownloadInProgress || download.canUseDownloadedModel {
                    Text(download.isBackgroundDownloadInProgress ? "Téléchargement du modèle" : "Préparation du modèle…")
                        .font(LfmPalette.medium())
                    if case let .downloading(progress?) = download.phase {
                        ProgressView(value: progress)
                        Text("\(Int((progress * 100).rounded())) %").font(LfmPalette.body(13)).monospacedDigit()
                    } else { ProgressView().frame(maxWidth: .infinity) }
                    Text("Vous pouvez quitter l’application pendant le téléchargement.")
                        .font(LfmPalette.body(13)).foregroundStyle(LfmPalette.secondary)
                } else {
                    Text("Téléchargez le modèle pour commencer à utiliser Aperçu.").foregroundStyle(LfmPalette.secondary)
                    VStack(alignment: .leading, spacing: 20) {
                        Label("1–2 Go de données et de stockage", systemImage: "internaldrive")
                        Label("Téléchargement en arrière-plan", systemImage: "iphone")
                    }.font(LfmPalette.body(14)).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(LfmPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                    if network.isExpensive || network.isConstrained {
                        Label("Ce téléchargement est volumineux. Privilégiez une connexion Wi-Fi.", systemImage: "wifi.exclamationmark")
                            .font(LfmPalette.body(13)).foregroundStyle(LfmPalette.secondary)
                    }
                    Button("Télécharger le modèle", systemImage: "arrow.down.circle") { download.recordConsent() }
                        .buttonStyle(ApercuActionStyle())
                    Button("Plus tard") { path = [.menu] }
                        .font(LfmPalette.body(14)).frame(maxWidth: .infinity, minHeight: 44)
                }
                Button("Consulter l’historique", systemImage: "clock.arrow.circlepath") { path.append(.history) }
                    .buttonStyle(ApercuActionStyle(primary: false))
                if download.canRemoveDownloadedModel {
                    Button("Supprimer le modèle téléchargé", role: .destructive) { confirmRemoveModel = true }
                        .font(LfmPalette.body(13)).frame(minHeight: 44)
                        .disabled(download.isRemoving || !chat.canRemoveDownloadedModel)
                }
                LocalSessionNote().padding(.top, 24)
            }.padding(20).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }.background(LfmPalette.background)
    }

    private func newSession() {
        if chat.newSession() { path = [] }
    }

    private func loadInstalledModel() async {
        guard download.canUseDownloadedModel else { return }
        await chat.loadModel()
    }

    private func removeModel() async {
        guard chat.canRemoveDownloadedModel, await chat.closeModelForRemoval() else { return }
        switch await download.removeDownloadedModel() {
        case .removed: message = "Le modèle a été supprimé. Vos sessions restent dans l’historique."
        case .inUse: message = "Le modèle est encore utilisé. Réessayez après la réponse en cours."
        case let .failed(reason): message = reason
        }
    }
}

private extension View {
    func apercuNavigation() -> some View {
        self.font(LfmPalette.body()).foregroundStyle(LfmPalette.ink)
            .background(LfmPalette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(LfmPalette.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .principal) { ApercuWordmark() } }
    }
}
