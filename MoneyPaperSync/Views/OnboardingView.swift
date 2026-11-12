import SwiftUI

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var step = 0
    @State private var folderCount: Int?
    @State private var isCheckingFolder = false

    private let titles = ["Willkommen", "MoneyMoney", "Paperless-ngx", "Zuordnung", "Erstimport", "Fertig"]
    private var lastStep: Int { titles.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
                .padding(.top, 44)
            Spacer(minLength: AppSpacing.lg)
            GlassCard(padding: AppSpacing.xxl) {
                ScrollView {
                    stepContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.never)
            }
            .frame(width: 640, height: 440)
            .id(step)
            .transition(.opacity)
            .appAnimation(AppMotion.navigation, value: step)
            Spacer(minLength: AppSpacing.lg)
            footer
                .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Kopf

    private var progressHeader: some View {
        VStack(spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.md) {
                LogoMark(size: 40)
                Wordmark().font(AppFont.pageTitle)
            }
            HStack(spacing: AppSpacing.sm) {
                ForEach(titles.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? AppColors.accent : AppColors.glassBorder)
                        .frame(width: index == step ? 28 : 14, height: 5)
                }
            }
            .appAnimation(value: step)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Schritt \(step + 1) von \(titles.count): \(titles[step])")
        }
    }

    // MARK: Schritte

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcome
        case 1: moneyMoneyStep
        case 2: paperlessStep
        case 3: mappingStep
        case 4: importStep
        default: summaryStep
        }
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title).font(AppFont.pageTitle).foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(AppFont.body).foregroundStyle(AppColors.textMuted)
        }
        .padding(.bottom, AppSpacing.lg)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            heading("Willkommen bei MoneyPaperSync", "Kontoauszüge aus MoneyMoney automatisch in Paperless-ngx archivieren.")
            feature("folder", "Ordner überwachen", "Neue PDF-Kontoauszüge werden automatisch erkannt.")
            feature("magnifyingglass", "Lokal analysieren", "Bank, Konto und Zeitraum werden auf deinem Mac erkannt.")
            feature("arrow.up.doc", "Sicher archivieren", "Upload an deinen Paperless-ngx-Server – Originale bleiben unverändert.")
        }
    }

    private func feature(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: AppRadius.small).fill(AppColors.accent.opacity(0.14)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.bodyMedium).foregroundStyle(AppColors.textPrimary)
                Text(text).font(AppFont.secondary).foregroundStyle(AppColors.textMuted)
            }
        }
    }

    private var moneyMoneyStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            heading("MoneyMoney-Ordner", "Wähle den Ordner, in dem MoneyMoney die Kontoauszüge als PDF ablegt.")
            Text(env.settings.folderPath.isEmpty ? "Kein Ordner ausgewählt" : env.settings.folderPath)
                .font(AppFont.mono)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .flatPanel(radius: AppRadius.small)
            HStack(spacing: AppSpacing.md) {
                PrimaryButton(title: "Ordner auswählen …", systemImage: "folder.badge.plus") {
                    FolderPicker.choose { url in
                        env.sync.setFolder(url)
                        Task { await checkFolder() }
                    }
                }
                if isCheckingFolder {
                    ProgressView().controlSize(.small)
                }
            }
            MoneyMoneyFolderFinder { url in
                env.sync.setFolder(url)
                Task { await checkFolder() }
            }
            if env.settings.folderBookmark != nil {
                ConnectionIndicator(name: "Zugriff", state: env.sync.moneyMoneyState)
                if let folderCount {
                    Label("\(folderCount) PDFs gefunden", systemImage: "doc.on.doc")
                        .font(AppFont.body.monospacedDigit())
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .task { if env.settings.folderBookmark != nil { await checkFolder() } }
    }

    private func checkFolder() async {
        isCheckingFolder = true
        defer { isCheckingFolder = false }
        env.sync.updateMoneyMoneyState()
        folderCount = await env.sync.countPDFs(mode: .all, since: .distantPast)
    }

    private var paperlessStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            heading("Paperless-ngx", "Server-URL und API-Token eintragen. Den Token findest du in Paperless unter „Mein Profil“.")
            PaperlessConnectionForm()
        }
    }

    private var mappingStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            heading("Dokumentenzuordnung", "Standardwerte für alle hochgeladenen Kontoauszüge. Pro Konto kannst du sie später überschreiben.")
            if env.settings.hasPaperlessCredentials && env.sync.paperlessState.isOK {
                PaperlessDefaultsForm()
            } else {
                EmptyStateView(
                    systemImage: "network.slash",
                    title: "Keine Verbindung",
                    message: "Verbinde zuerst Paperless-ngx im vorherigen Schritt, um Dokumenttypen, Korrespondenten und Tags auszuwählen. Du kannst diesen Schritt auch überspringen.",
                    compact: true
                )
            }
        }
    }

    private var importStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            heading("Erstimport", "Welche vorhandenen Kontoauszüge sollen übernommen werden?")
            InitialImportPicker()
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            heading("Alles bereit", "Zusammenfassung deiner Einrichtung.")
            summaryRow("MoneyMoney-Ordner", env.settings.folderPath.isEmpty ? "Nicht gewählt" : env.settings.folderPath, ok: env.settings.folderBookmark != nil)
            summaryRow("Paperless-ngx", env.sync.paperlessState.isOK ? "Verbunden" : env.sync.paperlessState.title, ok: env.sync.paperlessState.isOK)
            summaryRow("Dokumenttyp", env.settings.defaultDocumentTypeName ?? "Keiner", ok: nil)
            summaryRow("Korrespondent", env.settings.defaultCorrespondentName ?? "Keiner", ok: nil)
            summaryRow("Tags", env.settings.defaultTagNames.isEmpty ? "Keine" : env.settings.defaultTagNames.joined(separator: ", "), ok: nil)
            summaryRow("Erstimport", env.settings.initialImportMode.title, ok: nil)
            if env.settings.folderBookmark == nil || !env.sync.paperlessState.isOK {
                Label("Die Synchronisation startet erst, wenn Ordner und Paperless-ngx verbunden sind. Du kannst beides später in den Einstellungen nachholen.", systemImage: "info.circle")
                    .font(AppFont.caption).foregroundStyle(AppColors.warning)
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String, ok: Bool?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(AppFont.secondary).foregroundStyle(AppColors.textMuted).frame(width: 150, alignment: .leading)
            Text(value).font(AppFont.body).foregroundStyle(AppColors.textPrimary).lineLimit(2).truncationMode(.middle)
            Spacer()
            if let ok {
                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(ok ? AppColors.success : AppColors.warning)
                    .accessibilityLabel(ok ? "In Ordnung" : "Prüfen")
            }
        }
    }

    // MARK: Fuß

    private var footer: some View {
        HStack(spacing: AppSpacing.md) {
            if step > 0 {
                SecondaryButton(title: "Zurück", systemImage: "chevron.left") { step -= 1 }
                    .keyboardShortcut(.cancelAction)
            }
            if step == 3 || step == 2 {
                SecondaryButton(title: "Überspringen") { step += 1 }
            }
            if step < lastStep {
                PrimaryButton(title: "Weiter") { step += 1 }
                    .keyboardShortcut(.defaultAction)
                    .disabled(step == 1 && env.settings.folderBookmark == nil)
            } else {
                PrimaryButton(title: "Synchronisation starten", systemImage: "play.fill") {
                    env.finishOnboarding()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
