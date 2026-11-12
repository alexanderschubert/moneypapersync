import SwiftUI
import AppKit

enum FolderPicker {
    @MainActor
    static func choose(
        message: String = "Wähle den Ordner, in den MoneyMoney die Kontoauszüge exportiert.",
        startingAt: URL? = nil,
        showsHiddenFiles: Bool = false,
        completion: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.directoryURL = startingAt
        panel.showsHiddenFiles = showsHiddenFiles
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Auswählen"
        panel.message = message
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in completion(url) }
            }
        }
    }
}

/// Erkennt MoneyMoney, durchsucht dessen Datenordner nach PDF-Ordnern und lässt den Nutzer einen davon übernehmen.
struct MoneyMoneyFolderFinder: View {
    @Environment(AppEnvironment.self) private var env
    var onSelected: (URL) -> Void

    @State private var candidates: [MoneyMoneyLocator.Candidate] = []
    @State private var selection: URL?
    @State private var searchRoot: URL?
    @State private var isSearching = false
    @State private var showResults = false
    @State private var noResult = false

    private var version: String { MoneyMoneyLocator.version.map { " (Version \($0))" } ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if MoneyMoneyLocator.isInstalled {
                Label("MoneyMoney ist installiert\(version).", systemImage: "checkmark.circle.fill")
                    .font(AppFont.secondary)
                    .foregroundStyle(AppColors.success)
            } else {
                Label("MoneyMoney wurde nicht gefunden. Wähle den Ordner manuell aus.", systemImage: "exclamationmark.triangle.fill")
                    .font(AppFont.secondary)
                    .foregroundStyle(AppColors.warning)
            }
            HStack(spacing: AppSpacing.md) {
                SecondaryButton(title: "MoneyMoney-Ordner suchen …", systemImage: "magnifyingglass", isLoading: isSearching) {
                    startSearch()
                }
                .disabled(!MoneyMoneyLocator.isInstalled)
                .help("Öffnet den Datenordner von MoneyMoney. Bestätige ihn einmal, danach wird er nur lesend durchsucht.")
            }
            if noResult {
                Text("In diesem Ordner wurden keine PDFs gefunden. Wähle den Ordner mit „Ordner auswählen …“ manuell.")
                    .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
            }
        }
        .sheet(isPresented: $showResults) { resultsSheet }
    }

    private func startSearch() {
        noResult = false
        FolderPicker.choose(
            message: "Bestätige den Statements-Ordner von MoneyMoney. Er wird nur lesend nach PDFs durchsucht.",
            startingAt: MoneyMoneyLocator.dataFolderHint,
            showsHiddenFiles: true
        ) { root in
            searchRoot = root
            isSearching = true
            Task {
                let found = await Task.detached(priority: .userInitiated) {
                    MoneyMoneyLocator.findCandidates(under: root)
                }.value
                candidates = found
                selection = found.first?.url
                isSearching = false
                if found.isEmpty { noResult = true } else { showResults = true }
            }
        }
    }

    private func display(_ url: URL) -> String {
        guard let root = searchRoot else { return url.path }
        let relative = url.path.replacingOccurrences(of: root.path, with: "")
        return relative.isEmpty ? root.lastPathComponent : "…" + relative
    }

    private var resultsSheet: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Ordner mit PDFs gefunden").font(AppFont.cardTitle).foregroundStyle(AppColors.textPrimary)
                Text("Wähle den Ordner mit deinen Kontoauszügen.")
                    .font(AppFont.secondary).foregroundStyle(AppColors.textMuted)
            }
            ScrollView {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(candidates) { candidate in
                        Button { selection = candidate.url } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: selection == candidate.url ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selection == candidate.url ? AppColors.accent : AppColors.textMuted)
                                Text(display(candidate.url))
                                    .font(AppFont.mono)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .lineLimit(1).truncationMode(.middle)
                                Spacer(minLength: AppSpacing.sm)
                                Text("\(candidate.pdfCount) PDFs")
                                    .font(AppFont.secondary.monospacedDigit())
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .frame(height: 34)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(display(candidate.url)), \(candidate.pdfCount) PDFs")
                        .accessibilityAddTraits(selection == candidate.url ? .isSelected : [])
                    }
                }
            }
            .frame(maxHeight: 220)
            HStack(spacing: AppSpacing.md) {
                Spacer()
                SecondaryButton(title: "Abbrechen") { showResults = false }
                    .keyboardShortcut(.cancelAction)
                PrimaryButton(title: "Diesen Ordner verwenden") {
                    if let selection { onSelected(selection) }
                    showResults = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
        }
        .padding(AppSpacing.xl)
        .frame(width: 560)
        .background(AppColors.surfaceElevated)
    }
}

/// Server-URL, API-Token, TLS und Verbindungstest. Der Token wird nur im Schlüsselbund gespeichert.
struct PaperlessConnectionForm: View {
    @Environment(AppEnvironment.self) private var env

    @State private var url = ""
    @State private var token = ""
    @State private var isTesting = false
    @State private var result: ConnectionState?
    @State private var loaded = false

    var body: some View {
        @Bindable var settings = env.settings
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            LabeledField(title: "Server-URL") {
                TextField("https://paperless.example.com", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            LabeledField(title: "API-Token") {
                SecureField(KeychainService.hasToken ? "Token im Schlüsselbund gespeichert – zum Ändern neu eingeben" : "Token aus Paperless-ngx (Profil → API-Auth-Token)", text: $token)
                    .textFieldStyle(.roundedBorder)
            }
            Toggle("TLS-Zertifikat prüfen (empfohlen)", isOn: $settings.verifyTLS)
            if !settings.verifyTLS {
                Label("Ohne Zertifikatsprüfung ist die Verbindung nicht gegen Manipulation geschützt. Nur für vertrauenswürdige lokale Server verwenden.", systemImage: "exclamationmark.triangle.fill")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.warning)
            }

            HStack(spacing: AppSpacing.md) {
                PrimaryButton(title: "Speichern und Verbindung testen", systemImage: "bolt.horizontal", isLoading: isTesting) {
                    Task { await test() }
                }
                .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty || (token.isEmpty && !KeychainService.hasToken))
                ConnectionIndicator(name: "Paperless-ngx", state: result ?? env.sync.paperlessState, showsDetail: false)
                    .frame(maxWidth: 260)
            }
            if let detail = (result ?? env.sync.paperlessState).detail {
                Text(detail).font(AppFont.caption).foregroundStyle(AppColors.textMuted)
            }
        }
        .onAppear {
            guard !loaded else { return }
            url = env.settings.paperlessURL
            loaded = true
        }
    }

    private func test() async {
        isTesting = true
        defer { isTesting = false }
        let usedToken = token.isEmpty ? (KeychainService.readToken() ?? "") : token
        do {
            let client = try env.settings.makeClient(tokenOverride: usedToken, urlOverride: url)
            let info = try await client.testConnection()
            try KeychainService.saveToken(usedToken)
            env.settings.paperlessURL = client.baseURL.absoluteString
            url = env.settings.paperlessURL
            token = ""
            let version = info.version.map { " · Version \($0)" } ?? ""
            result = ConnectionState(kind: .ok, title: "Verbunden", detail: "\(info.documentCount) Dokumente\(version)")
            await env.sync.checkPaperless()
            await env.sync.refreshMetadata()
            env.log.add(.connection, .success, "Verbindung zu Paperless-ngx eingerichtet.")
        } catch let error as PaperlessError {
            switch error {
            case .authFailed:
                result = ConnectionState(kind: .error, title: "Authentifizierung fehlgeschlagen", detail: "Bitte API-Token prüfen.")
            case .unreachable(let message):
                result = ConnectionState(kind: .error, title: "Nicht erreichbar", detail: message)
            default:
                result = ConnectionState(kind: .error, title: "Fehler", detail: error.localizedDescription)
            }
        } catch {
            result = ConnectionState(kind: .error, title: "Fehler", detail: error.localizedDescription)
        }
    }
}

/// Standard-Dokumenttyp, -Korrespondent und -Tags (aus Paperless geladen).
struct PaperlessDefaultsForm: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var settings = env.settings
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if env.sync.isLoadingMetadata {
                LoadingIndicator(text: "Daten werden von Paperless-ngx geladen …")
            } else if let error = env.sync.metadataError, env.sync.metadata.isEmpty {
                ErrorStateView(title: "Daten konnten nicht geladen werden", message: error) {
                    Task { await env.sync.refreshMetadata() }
                }
            } else {
                LabeledField(title: "Standard-Dokumenttyp") {
                    Picker("Dokumenttyp", selection: Binding(
                        get: { settings.defaultDocumentTypeID },
                        set: { id in
                            settings.defaultDocumentTypeID = id
                            settings.defaultDocumentTypeName = env.sync.metadata.documentTypes.first { $0.id == id }?.name
                        }
                    )) {
                        Text("Keiner").tag(Int?.none)
                        ForEach(env.sync.metadata.documentTypes) { Text($0.name).tag(Int?.some($0.id)) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 300, alignment: .leading)
                }
                LabeledField(title: "Standard-Korrespondent") {
                    Picker("Korrespondent", selection: Binding(
                        get: { settings.defaultCorrespondentID },
                        set: { id in
                            settings.defaultCorrespondentID = id
                            settings.defaultCorrespondentName = env.sync.metadata.correspondents.first { $0.id == id }?.name
                        }
                    )) {
                        Text("Keiner").tag(Int?.none)
                        ForEach(env.sync.metadata.correspondents) { Text($0.name).tag(Int?.some($0.id)) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 300, alignment: .leading)
                }
                LabeledField(title: "Standard-Tags") {
                    if env.sync.metadata.tags.isEmpty {
                        Text("In Paperless-ngx sind keine Tags vorhanden.")
                            .font(AppFont.secondary).foregroundStyle(AppColors.textMuted)
                    } else {
                        TagSelector(tags: env.sync.metadata.tags, selection: Binding(
                            get: { Set(settings.defaultTagIDs) },
                            set: { ids in
                                settings.defaultTagIDs = ids.sorted()
                                settings.defaultTagNames = env.sync.metadata.tags.filter { ids.contains($0.id) }.map(\.name)
                            }
                        ))
                    }
                }
                SecondaryButton(title: "Von Paperless neu laden", systemImage: "arrow.clockwise") {
                    Task { await env.sync.refreshMetadata() }
                }
            }
        }
        .task {
            if env.sync.metadata.isEmpty, env.settings.hasPaperlessCredentials { await env.sync.refreshMetadata() }
        }
    }
}

struct LabeledField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title).font(AppFont.secondary).foregroundStyle(AppColors.textMuted)
            content
        }
    }
}

/// Erstimport-Auswahl inkl. Anzahl betroffener Dateien.
struct InitialImportPicker: View {
    @Environment(AppEnvironment.self) private var env
    @State private var count: Int?
    @State private var isCounting = false

    var body: some View {
        @Bindable var settings = env.settings
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Picker("Erstimport", selection: Binding(
                get: { settings.initialImportMode },
                set: { settings.initialImportMode = $0 }
            )) {
                ForEach(InitialImportMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            if settings.initialImportMode == .fromDate {
                DatePicker("Ab Datum", selection: $settings.initialImportDate, displayedComponents: .date)
                    .frame(maxWidth: 280)
            }

            HStack(spacing: AppSpacing.sm) {
                if isCounting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "doc.on.doc").foregroundStyle(AppColors.textMuted)
                }
                Text(countText)
                    .font(AppFont.secondary.monospacedDigit())
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .task(id: "\(settings.initialImportModeRaw)-\(settings.initialImportDate)-\(settings.folderPath)") {
            await recount()
        }
    }

    private var countText: String {
        guard let count else { return env.settings.folderBookmark == nil ? "Noch kein Ordner gewählt." : "Anzahl wird ermittelt …" }
        switch env.settings.initialImportMode {
        case .newOnly: return "Vorhandene PDFs werden übersprungen, nur neue werden importiert."
        default: return "\(count) PDFs werden importiert."
        }
    }

    private func recount() async {
        isCounting = true
        defer { isCounting = false }
        count = await env.sync.countPDFs(mode: env.settings.initialImportMode, since: env.settings.initialImportDate)
    }
}
