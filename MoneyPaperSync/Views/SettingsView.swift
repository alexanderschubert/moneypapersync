import SwiftUI
import UserNotifications

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, moneyMoney, paperless, importing, notifications, privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Allgemein"
        case .moneyMoney: "MoneyMoney"
        case .paperless: "Paperless-ngx"
        case .importing: "Import"
        case .notifications: "Benachrichtigungen"
        case .privacy: "Datenschutz"
        }
    }

    var symbol: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .moneyMoney: "folder"
        case .paperless: "externaldrive.connected.to.line.below"
        case .importing: "square.and.arrow.down"
        case .notifications: "bell"
        case .privacy: "lock.shield"
        }
    }
}

struct SettingsView: View {
    @State private var section: SettingsSection = .general

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Einstellungen")
                    .font(AppFont.pageTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.bottom, AppSpacing.md)
                    .accessibilityAddTraits(.isHeader)
                ForEach(SettingsSection.allCases) { item in
                    Button { section = item } label: {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: item.symbol).frame(width: 18)
                            Text(item.title).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(section == item ? AppFont.bodyMedium : AppFont.body)
                        .foregroundStyle(section == item ? AppColors.textPrimary : AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.md)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                .fill(section == item ? AppColors.accent.opacity(0.18) : .clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(section == item ? .isSelected : [])
                }
                Spacer()
            }
            .padding(AppLayout.contentPadding)
            .frame(width: 264)

            Divider().overlay(AppColors.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    switch section {
                    case .general: GeneralSettings()
                    case .moneyMoney: MoneyMoneySettings()
                    case .paperless: PaperlessSettings()
                    case .importing: ImportSettings()
                    case .notifications: NotificationSettings()
                    case .privacy: PrivacySettings()
                    }
                }
                .padding(AppLayout.contentPadding)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Allgemein

private struct GeneralSettings: View {
    @Environment(AppEnvironment.self) private var env
    @State private var launchAtLogin = false

    var body: some View {
        @Bindable var settings = env.settings
        GlassPanel("Darstellung", systemImage: "paintbrush") {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                LabeledField(title: "Erscheinungsbild") {
                    Picker("Erscheinungsbild", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                LabeledField(title: "Akzentfarbe") {
                    HStack(spacing: AppSpacing.md) {
                        ForEach(AccentOption.allCases) { option in
                            Button { settings.accent = option } label: {
                                ZStack {
                                    Circle().fill(Color(hex: option.baseHex)).frame(width: 24, height: 24)
                                    if settings.accent == option {
                                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                    }
                                }
                                .overlay(Circle().strokeBorder(settings.accent == option ? AppColors.textPrimary : .clear, lineWidth: 2).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .help(option.title)
                            .accessibilityLabel("Akzentfarbe \(option.title)")
                            .accessibilityAddTraits(settings.accent == option ? .isSelected : [])
                        }
                    }
                }
            }
        }
        GlassPanel("System", systemImage: "macwindow") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Toggle("Beim Anmelden starten", isOn: Binding(
                    get: { launchAtLogin },
                    set: { value in
                        env.settings.setLaunchAtLogin(value)
                        launchAtLogin = env.settings.launchAtLogin
                    }
                ))
                Toggle("Symbol in der Menüleiste anzeigen", isOn: Binding(
                    get: { env.settings.showMenuBarIcon },
                    set: { env.settings.showMenuBarIcon = $0 }
                ))
                Text("Zeigt den Status und bleibt aktiv, auch wenn das Fenster geschlossen wird.")
                    .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
                if let error = env.settings.launchAtLoginError {
                    Text(error).font(AppFont.caption).foregroundStyle(AppColors.error)
                }
                Text("Benachrichtigungen werden im Bereich „Benachrichtigungen“ konfiguriert.")
                    .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
            }
        }
        .onAppear { launchAtLogin = env.settings.launchAtLogin }
    }
}

// MARK: - MoneyMoney

private struct MoneyMoneySettings: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var settings = env.settings
        GlassPanel("Statements-Ordner", systemImage: "folder") {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                LabeledField(title: "Aktueller Ordnerpfad") {
                    Text(settings.folderPath.isEmpty ? "Kein Ordner ausgewählt" : settings.folderPath)
                        .font(AppFont.mono)
                        .foregroundStyle(AppColors.textPrimary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                ConnectionIndicator(name: "Berechtigungsstatus", state: env.sync.moneyMoneyState)
                HStack(spacing: AppSpacing.md) {
                    PrimaryButton(title: "Ordner auswählen …", systemImage: "folder.badge.plus") {
                        FolderPicker.choose { url in
                            env.sync.setFolder(url)
                            Task { await env.sync.scanFolder(); env.sync.pump() }
                        }
                    }
                    if let count = env.sync.pdfCountInFolder {
                        Text("\(count) PDFs gefunden")
                            .font(AppFont.secondary.monospacedDigit())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                MoneyMoneyFolderFinder { url in
                    env.sync.setFolder(url)
                    Task { await env.sync.scanFolder(); env.sync.pump() }
                }
            }
        }
        GlassPanel("Überwachung", systemImage: "eye") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Toggle("Ordnerüberwachung aktivieren", isOn: Binding(
                    get: { settings.watchFolder },
                    set: { value in
                        settings.watchFolder = value
                        env.sync.configureWatcher()
                        env.sync.updateMoneyMoneyState()
                    }
                ))
                Text("Neue PDFs werden automatisch erkannt. Zusätzlich erfolgt regelmäßig ein Abgleich.")
                    .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
                HStack(spacing: AppSpacing.md) {
                    SecondaryButton(title: "Verzeichnisabgleich jetzt", systemImage: "arrow.triangle.2.circlepath", isLoading: env.sync.isScanning) {
                        Task { await env.sync.scanFolder(); env.sync.pump() }
                    }
                    .disabled(settings.folderBookmark == nil)
                    if let last = env.sync.lastScanDate {
                        Text("Zuletzt: \(DateFormat.time.string(from: last)) Uhr")
                            .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
                    }
                }
            }
        }
    }
}

// MARK: - Paperless

private struct PaperlessSettings: View {
    var body: some View {
        GlassPanel("Verbindung", systemImage: "network") {
            PaperlessConnectionForm()
        }
        GlassPanel("Standardwerte für Uploads", systemImage: "tag") {
            PaperlessDefaultsForm()
        }
    }
}

// MARK: - Import

private struct ImportSettings: View {
    @Environment(AppEnvironment.self) private var env

    private var preview: String {
        TitleTemplate.render(
            env.settings.titleTemplate,
            bank: "ING", account: "Girokonto", type: "Girokonto",
            date: Date(), period: "Oktober 2026", fileName: "Kontoauszug.pdf"
        )
    }

    var body: some View {
        @Bindable var settings = env.settings
        GlassPanel("Ablauf", systemImage: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Toggle("Automatischer Import", isOn: $settings.autoImport)
                Text(settings.autoImport
                     ? "Erkannte und zugeordnete PDFs werden automatisch hochgeladen."
                     : "PDFs werden erkannt, aber erst nach „Jetzt synchronisieren“ hochgeladen.")
                    .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
                LabeledField(title: "Maximal parallele Uploads") {
                    Stepper(value: $settings.maxParallelUploads, in: 1...3) {
                        Text("\(settings.maxParallelUploads)").font(AppFont.body.monospacedDigit())
                    }
                    .frame(maxWidth: 140, alignment: .leading)
                }
                LabeledField(title: "Retry-Intervall bei temporären Fehlern") {
                    Picker("Retry", selection: $settings.retryIntervalMinutes) {
                        ForEach([5, 15, 30, 60], id: \.self) { Text("\($0) Minuten").tag($0) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200, alignment: .leading)
                }
                Toggle("Dublettenprüfung (SHA-256)", isOn: $settings.duplicateCheck)
            }
        }
        GlassPanel("Dokumenttitel", systemImage: "textformat") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                LabeledField(title: "Vorlage") {
                    TextField(TitleTemplate.defaultTemplate, text: $settings.titleTemplate)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Platzhalter: " + TitleTemplate.placeholders.joined(separator: "  "))
                    .font(AppFont.mono).foregroundStyle(AppColors.textMuted)
                HStack {
                    Text("Vorschau:").font(AppFont.secondary).foregroundStyle(AppColors.textMuted)
                    Text(preview).font(AppFont.bodyMedium).foregroundStyle(AppColors.textPrimary)
                }
                SecondaryButton(title: "Auf Standard zurücksetzen") {
                    settings.titleTemplate = TitleTemplate.defaultTemplate
                }
            }
        }
        GlassPanel("Erstimport", systemImage: "tray.and.arrow.down") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                InitialImportPicker()
                Text("Die Auswahl gilt für neu erkannte PDFs. Bereits registrierte Dokumente bleiben unverändert und können einzeln unter „Dokumente“ erneut synchronisiert werden.")
                    .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
            }
        }
    }
}

// MARK: - Benachrichtigungen

private struct NotificationSettings: View {
    @Environment(AppEnvironment.self) private var env
    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        @Bindable var settings = env.settings
        GlassPanel("Ereignisse", systemImage: "bell.badge") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Toggle("Import erfolgreich", isOn: $settings.notifyImportSuccess)
                Toggle("Import fehlgeschlagen", isOn: $settings.notifyImportFailed)
                Toggle("Verbindung verloren", isOn: $settings.notifyConnectionLost)
                Toggle("Manuelle Prüfung erforderlich", isOn: $settings.notifyManualReview)
            }
        }
        GlassPanel("Systemberechtigung", systemImage: "checkmark.shield") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                StatusBadge(
                    text: statusText,
                    systemImage: status == .authorized || status == .provisional ? "checkmark.circle.fill" : "bell.slash",
                    color: status == .authorized || status == .provisional ? AppColors.success : AppColors.warning
                )
                if status == .notDetermined {
                    PrimaryButton(title: "Benachrichtigungen erlauben", systemImage: "bell") {
                        Task {
                            _ = await env.notifier.requestAuthorization()
                            status = await env.notifier.authorizationStatus()
                        }
                    }
                } else if status == .denied {
                    SecondaryButton(title: "Systemeinstellungen öffnen", systemImage: "gearshape") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
        .task { status = await env.notifier.authorizationStatus() }
    }

    private var statusText: String {
        switch status {
        case .authorized, .provisional, .ephemeral: "Erlaubt"
        case .denied: "In den Systemeinstellungen abgelehnt"
        default: "Noch nicht angefragt"
        }
    }
}

// MARK: - Datenschutz

private struct PrivacySettings: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var settings = env.settings
        GlassPanel("Lokale Verarbeitung", systemImage: "lock.shield") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                bullet("PDFs werden ausschließlich lokal analysiert (Bank, Konto, Zeitraum).")
                bullet("Hochgeladen wird nur an deinen eigenen Paperless-ngx-Server.")
                bullet("Der API-Token liegt ausschließlich im macOS-Schlüsselbund.")
                bullet("Vollständige IBANs werden nie gespeichert oder protokolliert.")
                bullet("Original-PDFs werden nur gelesen, niemals verändert.")
            }
        }
        GlassPanel("Daten", systemImage: "internaldrive") {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Toggle("IBANs in der Oberfläche ausblenden", isOn: $settings.hideIBANs)
                LabeledField(title: "Protokollaufbewahrung") {
                    Picker("Aufbewahrung", selection: $settings.logRetentionDays) {
                        Text("7 Tage").tag(7)
                        Text("30 Tage").tag(30)
                        Text("90 Tage").tag(90)
                        Text("1 Jahr").tag(365)
                        Text("Unbegrenzt").tag(0)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200, alignment: .leading)
                }
                LabeledField(title: "Lokale Datenbank") {
                    HStack {
                        Text("Application Support / MoneyPaperSync")
                            .font(AppFont.mono).foregroundStyle(AppColors.textSecondary)
                        SecondaryButton(title: "Im Finder zeigen", systemImage: "folder") {
                            if let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: settings.logRetentionDays) { _, days in env.log.purgeOld(retentionDays: days) }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(AppColors.success).padding(.top, 2)
            Text(text).font(AppFont.body).foregroundStyle(AppColors.textSecondary)
        }
    }
}
