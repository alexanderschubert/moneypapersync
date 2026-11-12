import Foundation
import SwiftData
import Observation
import AppKit

// MARK: - Titelvorlage

enum TitleTemplate {
    static let defaultTemplate = "{bank} {account} {month} {year}"
    static let placeholders = ["{bank}", "{account}", "{type}", "{month}", "{year}", "{period}", "{filename}"]

    static func render(_ template: String, bank: String?, account: String?, type: String?, date: Date?, period: String, fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        var text = template.isEmpty ? TitleTemplate.defaultTemplate : template
        let replacements: [String: String] = [
            "{bank}": bank ?? "",
            "{account}": account ?? "",
            "{type}": type ?? "",
            "{month}": date.map { DateFormat.monthOnly.string(from: $0) } ?? "",
            "{year}": date.map { DateFormat.yearOnly.string(from: $0) } ?? "",
            "{period}": period,
            "{filename}": base
        ]
        for (key, value) in replacements { text = text.replacingOccurrences(of: key, with: value) }
        let collapsed = text.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        return collapsed.isEmpty ? base : collapsed
    }
}

// MARK: - Engine

@MainActor
@Observable
final class SyncEngine {
    // Beobachtbarer Zustand
    var paperlessState: ConnectionState = .checking
    var moneyMoneyState: ConnectionState = .checking
    var isScanning = false
    var isRechecking = false
    var lastScanDate: Date?
    var pdfCountInFolder: Int?
    var metadata: PaperlessMetadata = .empty
    var isLoadingMetadata = false
    var metadataError: String?
    private(set) var activeCount = 0

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let log: LogService
    @ObservationIgnored private let notifier: NotificationService
    @ObservationIgnored private let watcher = FolderWatcher()

    @ObservationIgnored private var rootURL: URL?
    @ObservationIgnored private var accessActive = false
    @ObservationIgnored private var activeIDs: Set<UUID> = []
    @ObservationIgnored private var pumping = false
    @ObservationIgnored private var pumpAgain = false
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var scanDebounce: Task<Void, Never>?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var lastPaperlessKind: ConnectionState.Kind?
    @ObservationIgnored private var lastMoneyMoneyKind: ConnectionState.Kind?

    init(context: ModelContext, settings: AppSettings, log: LogService, notifier: NotificationService) {
        self.context = context
        self.settings = settings
        self.log = log
        self.notifier = notifier
    }

    /// Verständliche Gesamtzusammenfassung für die Sidebar.
    var summary: (text: String, color: ConnectionState.Kind, pulsing: Bool) {
        if !settings.onboardingCompleted { return ("Nicht eingerichtet", .neutral, false) }
        if !moneyMoneyState.isOK || !paperlessState.isOK {
            if moneyMoneyState.kind == .checking || paperlessState.kind == .checking {
                return ("Verbindung wird geprüft", .checking, false)
            }
            return ("Verbindung eingeschränkt", .warning, false)
        }
        if activeCount > 0 || isScanning { return ("Synchronisiert …", .ok, true) }
        if !settings.watchFolder { return ("Überwachung pausiert", .neutral, false) }
        return ("Synchronisation aktiv", .ok, false)
    }

    // MARK: Lebenszyklus

    func start() {
        guard !started, settings.onboardingCompleted else { return }
        started = true
        log.purgeOld(retentionDays: settings.logRetentionDays)
        recoverInterruptedWork()
        updateMoneyMoneyState() // öffnet den Ordnerzugriff, bevor der Watcher startet
        configureWatcher()
        Task {
            await refreshConnections()
            await scanFolder()
            pump()
        }
        timerTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self, !Task.isCancelled else { return }
                tick += 1
                await self.refreshConnections()
                self.requeueTransientFailures()
                if tick % 5 == 0, self.settings.watchFolder {
                    await self.scanFolder()
                }
                self.pump()
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        watcher.stop()
        endFolderAccess()
        started = false
    }

    /// Nach dem Onboarding oder Änderungen in den Einstellungen aufrufen.
    func restart() {
        stop()
        start()
    }

    func configureWatcher() {
        watcher.stop()
        guard settings.watchFolder, let root = rootURL else { return }
        watcher.start(path: root.path) { [weak self] in
            self?.scheduleScan()
        }
    }

    private func scheduleScan() {
        scanDebounce?.cancel()
        scanDebounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.scanFolder()
            self?.pump()
        }
    }

    private func recoverInterruptedWork() {
        for doc in allDocuments() where !activeIDs.contains(doc.id) {
            switch doc.status {
            case .analyzing:
                doc.status = .newDetected
                doc.analysisDone = false
            case .uploading:
                doc.status = .newDetected
            default: break
            }
        }
        try? context.save()
    }

    private func requeueTransientFailures() {
        let interval = TimeInterval(max(settings.retryIntervalMinutes, 1) * 60)
        var changed = false
        for doc in allDocuments() where doc.status == .failed && doc.isTransientError && doc.attempts < 5 {
            if Date().timeIntervalSince(doc.updatedAt) >= interval {
                doc.status = .newDetected
                doc.progress = 0.3
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    // MARK: Ordnerzugriff (MoneyMoney)

    static func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Setzt den Statements-Ordner (nach NSOpenPanel).
    func setFolder(_ url: URL) {
        endFolderAccess()
        do {
            settings.folderBookmark = try Self.makeBookmark(for: url)
            settings.folderPath = url.path
            log.add(.system, .info, "Statements-Ordner geändert.")
        } catch {
            log.add(.system, .error, "Ordner konnte nicht gespeichert werden: \(error.localizedDescription)")
        }
        _ = beginFolderAccess()
        configureWatcher()
        updateMoneyMoneyState()
    }

    @discardableResult
    private func beginFolderAccess() -> Bool {
        if accessActive, rootURL != nil { return true }
        guard let bookmark = settings.folderBookmark else { return false }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return false
        }
        guard url.startAccessingSecurityScopedResource() else { return false }
        accessActive = true
        rootURL = url
        if stale, let fresh = try? Self.makeBookmark(for: url) { settings.folderBookmark = fresh }
        settings.folderPath = url.path
        return true
    }

    private func endFolderAccess() {
        if accessActive { rootURL?.stopAccessingSecurityScopedResource() }
        accessActive = false
        rootURL = nil
    }

    func fileURL(for doc: StatementDocument) -> URL? {
        if rootURL == nil { beginFolderAccess() }
        return rootURL?.appendingPathComponent(doc.relativePath)
    }

    func updateMoneyMoneyState() {
        let state: ConnectionState
        if settings.folderBookmark == nil {
            state = .notConfigured
        } else if !beginFolderAccess() {
            state = ConnectionState(kind: .error, title: "Berechtigung fehlt", detail: "Ordner bitte neu auswählen.")
        } else if let root = rootURL,
                  (try? FileManager.default.contentsOfDirectory(atPath: root.path)) == nil {
            state = ConnectionState(kind: .error, title: "Ordner nicht erreichbar", detail: root.path)
        } else {
            state = ConnectionState(
                kind: .ok,
                title: settings.watchFolder ? "Verbunden · Überwachung aktiv" : "Verbunden",
                detail: rootURL?.path
            )
        }
        if let previous = lastMoneyMoneyKind, previous == .ok, state.kind == .error {
            notifier.connectionLost("Der MoneyMoney-Ordner")
            log.add(.connection, .error, "MoneyMoney-Ordner nicht mehr erreichbar.")
        }
        lastMoneyMoneyKind = state.kind
        moneyMoneyState = state
    }

    // MARK: Paperless-Verbindung

    func refreshConnections() async {
        updateMoneyMoneyState()
        await checkPaperless()
    }

    func checkPaperless() async {
        guard settings.hasPaperlessCredentials else {
            paperlessState = .notConfigured
            lastPaperlessKind = .neutral
            return
        }
        let state: ConnectionState
        do {
            let client = try settings.makeClient()
            let info = try await client.testConnection()
            let version = info.version.map { " · Version \($0)" } ?? ""
            state = ConnectionState(kind: .ok, title: "Verbunden", detail: "\(info.documentCount) Dokumente\(version)")
        } catch let error as PaperlessError {
            switch error {
            case .authFailed:
                state = ConnectionState(kind: .error, title: "Authentifizierung fehlgeschlagen", detail: "API-Token prüfen.")
            case .unreachable(let message):
                state = ConnectionState(kind: .error, title: "Nicht erreichbar", detail: message)
            case .notConfigured:
                state = .notConfigured
            default:
                state = ConnectionState(kind: .error, title: "Fehler", detail: error.localizedDescription)
            }
        } catch {
            state = ConnectionState(kind: .error, title: "Fehler", detail: error.localizedDescription)
        }
        if lastPaperlessKind == .ok, state.kind == .error {
            notifier.connectionLost("Paperless-ngx")
            log.add(.connection, .error, "Paperless-ngx nicht mehr erreichbar: \(state.title)")
        } else if lastPaperlessKind == .error, state.kind == .ok {
            log.add(.connection, .success, "Verbindung zu Paperless-ngx wiederhergestellt.")
        }
        lastPaperlessKind = state.kind
        paperlessState = state
    }

    func refreshMetadata() async {
        guard settings.hasPaperlessCredentials else {
            metadataError = "Paperless-ngx ist nicht eingerichtet."
            return
        }
        isLoadingMetadata = true
        metadataError = nil
        defer { isLoadingMetadata = false }
        do {
            metadata = try await settings.makeClient().fetchMetadata()
        } catch {
            metadataError = error.localizedDescription
        }
    }

    // MARK: Scan

    private func allDocuments() -> [StatementDocument] {
        (try? context.fetch(FetchDescriptor<StatementDocument>())) ?? []
    }

    /// Zählt PDFs im Ordner, die der Erstimport-Auswahl entsprechen (für Onboarding/Einstellungen).
    func countPDFs(mode: InitialImportMode, since: Date) async -> Int? {
        guard beginFolderAccess(), let root = rootURL else { return nil }
        let files = await Task.detached(priority: .utility) { FolderScanner.listPDFs(root: root) }.value
        switch mode {
        case .all, .newOnly: return mode == .all ? files.count : 0
        case .fromDate: return files.filter { ($0.modified ?? .distantPast) >= since }.count
        }
    }

    func scanFolder() async {
        guard !isScanning else { return }
        guard beginFolderAccess(), let root = rootURL else {
            updateMoneyMoneyState()
            return
        }
        isScanning = true
        defer {
            isScanning = false
            lastScanDate = Date()
        }

        let files = await Task.detached(priority: .utility) { FolderScanner.listPDFs(root: root) }.value
        pdfCountInFolder = files.count
        updateMoneyMoneyState()

        let known = Set(allDocuments().map(\.relativePath))
        var created = 0
        for file in files where !known.contains(file.relativePath) {
            let doc = StatementDocument(
                fileName: file.name,
                relativePath: file.relativePath,
                fileSize: file.size,
                fileModifiedAt: file.modified
            )
            context.insert(doc)
            log.add(.pdfDetected, .info, "Neue PDF erkannt.", document: doc)
            created += 1
        }
        if created > 0 { try? context.save() }
    }

    /// Manueller Abgleich/Import: Scan + Freigabe aller wartenden Dokumente.
    func syncNow() async {
        await refreshConnections()
        await scanFolder()
        for doc in allDocuments() where doc.status == .newDetected { doc.userApproved = true }
        try? context.save()
        pump()
    }

    // MARK: Pipeline

    func pump() {
        if pumping {
            pumpAgain = true
            return
        }
        pumping = true
        Task {
            repeat {
                pumpAgain = false
                await analyzePending()
                startUploads()
            } while pumpAgain
            pumping = false
        }
    }

    private func analyzePending() async {
        let pending = allDocuments()
            .filter { $0.status == .newDetected && !$0.analysisDone }
            .sorted { $0.detectedAt < $1.detectedAt }
        guard !pending.isEmpty else { return }
        activeCount += 1
        defer { activeCount -= 1 }
        for doc in pending {
            await analyze(doc)
        }
    }

    private func bankRules() -> [BankRule] {
        let banks = (try? context.fetch(FetchDescriptor<Bank>())) ?? []
        return banks.filter(\.isActive).map { BankRule(id: $0.id, name: $0.name, keywords: $0.keywords) }
    }

    func analyze(_ doc: StatementDocument) async {
        guard let url = fileURL(for: doc) else {
            fail(doc, "Statements-Ordner nicht verfügbar.", transient: true)
            return
        }
        doc.status = .analyzing
        doc.progress = 0.15
        let rules = bankRules()
        let name = doc.fileName
        let modified = doc.fileModifiedAt

        let analysis = await Task.detached(priority: .utility) {
            PDFAnalyzer.analyze(url: url, fileName: name, fileModified: modified, banks: rules)
        }.value

        guard analysis.isValid else {
            fail(doc, analysis.errorMessage ?? "Ungültige PDF-Datei.", transient: false)
            return
        }
        log.add(.pdfValidated, .info, "PDF validiert (\(analysis.pageCount) Seiten).", document: doc)
        doc.sha256 = analysis.sha256
        log.add(.hashComputed, .info, "SHA-256 berechnet.", document: doc)
        doc.periodStart = analysis.periodStart
        doc.periodEnd = analysis.periodEnd
        doc.documentDate = analysis.documentDate

        // Erstimport-Regeln
        if let reason = excludedByInitialImport(doc) {
            doc.status = .ignored
            doc.lastError = reason
            doc.analysisDone = true
            try? context.save()
            return
        }

        // Dublettenprüfung
        if settings.duplicateCheck,
           let original = allDocuments().first(where: {
               $0.id != doc.id && $0.sha256 == analysis.sha256
                   && ($0.status == .imported || $0.status == .processing || $0.status == .uploading || $0.analysisDone)
                   && $0.status != .duplicate && $0.status != .ignored
           }) {
            doc.status = .duplicate
            doc.lastError = "Identisch mit \(original.fileName)"
            doc.analysisDone = true
            log.add(.duplicateDetected, .warning, "Dublette von \(original.fileName).", document: doc)
            try? context.save()
            return
        }

        // Bank / Konto
        let banks = (try? context.fetch(FetchDescriptor<Bank>())) ?? []
        var bankMatchedByContent = analysis.bankMatchedByContent
        var detectedBank = analysis.bankID.flatMap { id in banks.first(where: { $0.id == id }) }
        // Keine Bank im Text gefunden: Karten-/Sparbuch-/IBAN-Kennung eines bekannten Kontos verrät sie.
        if detectedBank == nil || !bankMatchedByContent,
           let account = uniqueAccount(ibans: analysis.maskedIBANs, references: analysis.referenceLast4),
           let bank = account.bank {
            detectedBank = bank
            bankMatchedByContent = true
        }
        if let bank = detectedBank {
            doc.bank = bank
            log.add(.bankDetected, .info, "Bank erkannt: \(bank.name).", document: doc)

            if !bankMatchedByContent {
                doc.analysisDone = true
                review(doc, "Bank nur anhand des Dateinamens erkannt – bitte bestätigen.")
                return
            }

            if let account = matchAccount(bank: bank, ibans: analysis.maskedIBANs, references: analysis.referenceLast4) {
                doc.account = account
                log.add(.accountAssigned, .info, "Konto zugeordnet: \(account.name).", document: doc)
            } else if let masked = analysis.maskedIBANs.first {
                let account = Account(name: "Konto \(masked.suffix(4))", ibanMasked: masked, type: .checking, bank: bank)
                context.insert(account)
                doc.account = account
                log.add(.accountAssigned, .info, "Neues Konto aus Erkennung angelegt: \(account.name).", document: doc)
            }
        }

        doc.analysisDone = true
        if doc.bank == nil {
            review(doc, "Bank nicht erkannt. Bitte Bank zuordnen oder Erkennungsmerkmale ergänzen.")
        } else if doc.account == nil {
            review(doc, "Konto nicht eindeutig. Bitte manuell zuordnen.")
        } else if doc.account?.isActive == false {
            doc.status = .ignored
            doc.lastError = "Konto ist deaktiviert."
            try? context.save()
        } else {
            doc.status = .newDetected
            doc.lastError = nil
            doc.progress = 0.3
            try? context.save()
        }
    }

    private func matchAccount(bank: Bank, ibans: [String], references: [String]) -> Account? {
        let accounts = bank.accounts.filter(\.isActive)
        let found = Set(ibans.map { String($0.suffix(4)) } + references)
        // Mehrere Konten mit gleicher Kennung (z. B. mehrere Sparbücher): nur eindeutige Treffer zählen.
        let hits = accounts.filter { !$0.matchKeys.isDisjoint(with: found) }
        if hits.count == 1 { return hits[0] }
        if hits.isEmpty, found.isEmpty, accounts.count == 1 { return accounts[0] }
        return nil
    }

    /// Das einzige aktive Konto (über alle Banken), dessen Kennung im PDF vorkommt.
    private func uniqueAccount(ibans: [String], references: [String]) -> Account? {
        let found = Set(ibans.map { String($0.suffix(4)) } + references)
        guard !found.isEmpty else { return nil }
        let accounts = ((try? context.fetch(FetchDescriptor<Account>())) ?? []).filter { $0.isActive && $0.bank != nil }
        let hits = accounts.filter { !$0.matchKeys.isDisjoint(with: found) }
        return hits.count == 1 ? hits[0] : nil
    }

    /// Prüft noch nicht zugeordnete PDFs erneut: Dokumente zur manuellen Prüfung werden neu analysiert,
    /// bereits importierte ohne Bank/Konto nur lokal neu zugeordnet (kein erneuter Upload).
    @discardableResult
    func reassignUnassigned() async -> Int {
        var changed = 0
        for doc in allDocuments() {
            switch doc.status {
            case .needsReview, .ignored where doc.lastError?.hasPrefix("Konto ist deaktiviert") == true:
                doc.analysisDone = false
                doc.status = .newDetected
                doc.lastError = nil
                changed += 1
            case .imported where doc.bank == nil || doc.account == nil:
                if await relinkLocally(doc) { changed += 1 }
            default:
                break
            }
        }
        try? context.save()
        if changed > 0 { log.add(.system, .info, "\(changed) PDFs neu zugeordnet.") }
        pump()
        return changed
    }

    /// Liest alle PDFs erneut und weist die passende Bank (und das Konto) zu – nur lokal, ohne erneuten Upload.
    /// Mit `bank` werden nur PDFs berücksichtigt, die zu dieser Bank passen; sonst wird jedem PDF seine Bank zugewiesen.
    func recheckAll(bank filter: Bank? = nil) async -> Int {
        guard !isRechecking else { return 0 }
        isRechecking = true
        defer { isRechecking = false }
        var changed = 0
        let busy: Set<DocumentStatus> = [.analyzing, .uploading, .processing]
        for doc in allDocuments() where !busy.contains(doc.status) && doc.status != .duplicate {
            if await relinkLocally(doc, only: filter) { changed += 1 }
        }
        try? context.save()
        if changed > 0 { log.add(.system, .info, "Bank-Zuordnung geprüft: \(changed) PDFs aktualisiert.") }
        pump()
        return changed
    }

    private func relinkLocally(_ doc: StatementDocument, only filter: Bank? = nil) async -> Bool {
        guard let url = fileURL(for: doc) else { return false }
        let rules = bankRules()
        let name = doc.fileName
        let modified = doc.fileModifiedAt
        let analysis = await Task.detached(priority: .utility) {
            PDFAnalyzer.analyze(url: url, fileName: name, fileModified: modified, banks: rules)
        }.value
        guard analysis.isValid else { return false }
        let banks = (try? context.fetch(FetchDescriptor<Bank>())) ?? []
        var bank = analysis.bankMatchedByContent ? analysis.bankID.flatMap { id in banks.first { $0.id == id } } : nil
        if bank == nil, let account = uniqueAccount(ibans: analysis.maskedIBANs, references: analysis.referenceLast4) {
            bank = account.bank
        }
        guard let bank, filter == nil || filter?.id == bank.id else { return false }

        let before = (doc.bank?.id, doc.account?.id)
        doc.bank = bank
        if doc.account?.bank?.id != bank.id {
            doc.account = matchAccount(bank: bank, ibans: analysis.maskedIBANs, references: analysis.referenceLast4)
        }
        let changed = before != (doc.bank?.id, doc.account?.id)
        if changed {
            log.add(.bankDetected, .info, "Bank neu zugeordnet: \(bank.name).", document: doc)
            if doc.status == .needsReview, doc.account != nil, doc.account?.isActive == true {
                doc.analysisDone = true
                doc.status = .newDetected
                doc.lastError = nil
                doc.progress = 0.3
            }
        }
        return changed
    }

    private func excludedByInitialImport(_ doc: StatementDocument) -> String? {
        switch settings.initialImportMode {
        case .all:
            return nil
        case .fromDate:
            let date = doc.referenceDate ?? doc.fileModifiedAt ?? doc.detectedAt
            return date < settings.initialImportDate ? "Vor dem gewählten Startdatum." : nil
        case .newOnly:
            guard let baseline = settings.importBaselineDate else { return nil }
            let date = doc.fileModifiedAt ?? doc.detectedAt
            return date < baseline ? "Vor der Einrichtung vorhanden." : nil
        }
    }

    private func review(_ doc: StatementDocument, _ reason: String) {
        doc.status = .needsReview
        doc.lastError = reason
        doc.progress = 0
        log.add(.manualReview, .warning, reason, document: doc)
        notifier.reviewNeeded(doc.fileName)
        try? context.save()
    }

    private func fail(_ doc: StatementDocument, _ message: String, transient: Bool) {
        doc.status = .failed
        doc.lastError = Redactor.sanitize(message)
        doc.isTransientError = transient
        doc.progress = 0
        doc.attempts += 1
        log.add(.importFailed, .error, message, document: doc)
        notifier.documentFailed(doc.fileName)
        try? context.save()
    }

    // MARK: Upload

    private func startUploads() {
        let limit = min(max(settings.maxParallelUploads, 1), 3)
        guard activeIDs.count < limit else { return }
        guard paperlessState.kind != .neutral || settings.hasPaperlessCredentials else { return }

        let candidates = allDocuments()
            .filter { doc in
                guard !activeIDs.contains(doc.id) else { return false }
                if doc.status == .processing, doc.paperlessTaskID != nil { return true }
                return doc.status == .newDetected && doc.analysisDone && (settings.autoImport || doc.userApproved)
            }
            .sorted { $0.detectedAt < $1.detectedAt }

        for doc in candidates.prefix(limit - activeIDs.count) {
            activeIDs.insert(doc.id)
            activeCount += 1
            Task { [weak self] in
                guard let self else { return }
                await self.upload(doc)
                self.activeIDs.remove(doc.id)
                self.activeCount -= 1
                self.pump()
            }
        }
    }

    private func upload(_ doc: StatementDocument) async {
        let client: PaperlessClient
        do {
            client = try settings.makeClient()
        } catch {
            fail(doc, error.localizedDescription, transient: false)
            return
        }

        do {
            var taskID = doc.paperlessTaskID
            if doc.status != .processing || taskID == nil {
                guard let url = fileURL(for: doc) else {
                    fail(doc, "Statements-Ordner nicht verfügbar.", transient: true)
                    return
                }
                doc.status = .uploading
                doc.progress = 0.5
                log.add(.uploadStarted, .info, "Upload zu Paperless-ngx gestartet.", document: doc)

                let data: Data
                do {
                    data = try await Task.detached(priority: .utility) { try Data(contentsOf: url, options: .mappedIfSafe) }.value
                } catch {
                    fail(doc, "Datei nicht lesbar.", transient: true)
                    return
                }

                let request = buildUploadRequest(for: doc, data: data)
                taskID = try await client.upload(request)
                doc.paperlessTaskID = taskID
                doc.status = .processing
                doc.progress = 0.75
                try? context.save()
            }

            guard let taskID else { return }
            try await pollTask(taskID, doc: doc, client: client)
        } catch let error as PaperlessError {
            if case .authFailed = error { await checkPaperless() }
            fail(doc, error.localizedDescription, transient: error.isTransient)
        } catch {
            fail(doc, error.localizedDescription, transient: true)
        }
    }

    private func pollTask(_ taskID: String, doc: StatementDocument, client: PaperlessClient) async throws {
        for attempt in 0..<60 {
            try? await Task.sleep(for: .seconds(attempt < 5 ? 1.5 : 3))
            guard let task = try await client.taskStatus(taskID: taskID) else { continue }
            switch task.status.uppercased() {
            case "SUCCESS":
                doc.paperlessDocumentID = task.relatedDocument
                doc.status = .imported
                doc.progress = 1
                doc.importedAt = Date()
                doc.lastError = nil
                doc.isTransientError = false
                log.add(.taskCompleted, .success, "In Paperless-ngx archiviert.", document: doc)
                notifier.documentImported(doc.fileName)
                try? context.save()
                return
            case "FAILURE", "REVOKED":
                let message = task.result ?? "Paperless-Verarbeitung fehlgeschlagen."
                doc.paperlessTaskID = nil
                if message.lowercased().contains("duplicate") {
                    doc.status = .duplicate
                    doc.lastError = "Bereits in Paperless-ngx vorhanden."
                    log.add(.duplicateDetected, .warning, "Paperless meldet eine Dublette.", document: doc)
                    try? context.save()
                } else {
                    fail(doc, message, transient: false)
                }
                return
            default:
                doc.progress = min(0.95, 0.75 + Double(attempt) * 0.01)
            }
        }
        // Zeitüberschreitung: Task bleibt bestehen, wird beim nächsten Durchlauf weiter abgefragt.
        doc.lastError = "Paperless verarbeitet noch – wird später erneut geprüft."
        try? context.save()
    }

    func buildUploadRequest(for doc: StatementDocument, data: Data) -> PaperlessUploadRequest {
        let template = doc.account?.titleTemplate.isEmpty == false ? doc.account!.titleTemplate : settings.titleTemplate
        let title = TitleTemplate.render(
            template,
            bank: doc.bank?.name,
            account: doc.account?.name,
            type: doc.account?.type.title,
            date: doc.referenceDate,
            period: doc.periodText,
            fileName: doc.fileName
        )
        var tags = Set(settings.defaultTagIDs)
        doc.account?.tagIDs.forEach { tags.insert($0) }
        return PaperlessUploadRequest(
            fileName: doc.fileName,
            data: data,
            title: title,
            created: doc.referenceDate,
            correspondentID: doc.account?.paperlessCorrespondentID ?? settings.defaultCorrespondentID,
            documentTypeID: settings.defaultDocumentTypeID,
            tagIDs: tags.sorted()
        )
    }

    // MARK: Aktionen aus der Oberfläche

    func retry(_ doc: StatementDocument) {
        // Wurde der Upload schon angenommen, nur den Verarbeitungsstatus erneut abfragen (kein zweiter Upload).
        let resume = doc.paperlessTaskID != nil
        doc.status = resume ? .processing : .newDetected
        doc.lastError = nil
        doc.attempts = 0
        doc.userApproved = true
        doc.progress = resume ? 0.75 : (doc.analysisDone ? 0.3 : 0)
        try? context.save()
        pump()
    }

    func retryAllTransientFailures() {
        for doc in allDocuments() where doc.status == .failed && doc.isTransientError {
            let resume = doc.paperlessTaskID != nil
            doc.status = resume ? .processing : .newDetected
            doc.lastError = nil
            doc.attempts = 0
            doc.userApproved = true
            doc.progress = resume ? 0.75 : (doc.analysisDone ? 0.3 : 0)
        }
        try? context.save()
        pump()
    }

    /// Erneute Analyse + Synchronisation (z. B. nach manueller Zuordnung).
    func resync(_ doc: StatementDocument, reanalyze: Bool = false) {
        doc.userApproved = true
        doc.lastError = nil
        doc.attempts = 0
        doc.paperlessTaskID = nil
        doc.paperlessDocumentID = nil
        doc.importedAt = nil
        doc.progress = 0
        doc.analysisDone = !reanalyze
        doc.status = .newDetected
        try? context.save()
        pump()
    }

    func ignore(_ doc: StatementDocument) {
        doc.status = .ignored
        doc.lastError = "Manuell ignoriert."
        try? context.save()
    }

    func unignore(_ doc: StatementDocument) {
        doc.lastError = nil
        doc.userApproved = true
        doc.analysisDone = false
        doc.status = .newDetected
        try? context.save()
        pump()
    }

    /// Manuelle Zuordnung: setzt Bank/Konto und gibt das Dokument frei.
    func assign(_ doc: StatementDocument, bank: Bank?, account: Account?, periodEnd: Date?) {
        doc.bank = bank
        doc.account = account
        if let periodEnd {
            doc.periodEnd = periodEnd
            doc.documentDate = periodEnd
        }
        log.add(.accountAssigned, .info, "Zuordnung manuell geändert.", document: doc)
        if bank != nil, account != nil, doc.status == .needsReview || doc.status == .failed {
            doc.analysisDone = true
            doc.status = .newDetected
            doc.lastError = nil
            doc.userApproved = true
            doc.progress = 0.3
        }
        try? context.save()
        pump()
    }

    func openPDF(_ doc: StatementDocument) {
        if let url = fileURL(for: doc) { NSWorkspace.shared.open(url) }
    }

    func openInPaperless(_ doc: StatementDocument) {
        guard let id = doc.paperlessDocumentID, let client = try? settings.makeClient() else { return }
        NSWorkspace.shared.open(client.documentURL(id: id))
    }
}
