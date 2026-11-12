import Foundation
import Observation
import ServiceManagement

/// Alle Einstellungen, persistiert in UserDefaults. Der API-Token liegt ausschließlich im Schlüsselbund.
@MainActor
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    // Allgemein
    var appearance: AppearanceMode { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    var accent: AccentOption {
        didSet {
            defaults.set(accent.rawValue, forKey: "accent")
            AccentTheme.shared.option = accent
        }
    }
    var onboardingCompleted: Bool { didSet { defaults.set(onboardingCompleted, forKey: "onboardingCompleted") } }
    var sidebarCollapsed: Bool { didSet { defaults.set(sidebarCollapsed, forKey: "sidebarCollapsed") } }
    var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon") } }

    // MoneyMoney
    var folderBookmark: Data? { didSet { defaults.set(folderBookmark, forKey: "folderBookmark") } }
    var folderPath: String { didSet { defaults.set(folderPath, forKey: "folderPath") } }
    var watchFolder: Bool { didSet { defaults.set(watchFolder, forKey: "watchFolder") } }

    // Paperless
    var paperlessURL: String { didSet { defaults.set(paperlessURL, forKey: "paperlessURL") } }
    var verifyTLS: Bool { didSet { defaults.set(verifyTLS, forKey: "verifyTLS") } }
    var defaultDocumentTypeID: Int? { didSet { defaults.set(defaultDocumentTypeID, forKey: "defaultDocumentTypeID") } }
    var defaultDocumentTypeName: String? { didSet { defaults.set(defaultDocumentTypeName, forKey: "defaultDocumentTypeName") } }
    var defaultCorrespondentID: Int? { didSet { defaults.set(defaultCorrespondentID, forKey: "defaultCorrespondentID") } }
    var defaultCorrespondentName: String? { didSet { defaults.set(defaultCorrespondentName, forKey: "defaultCorrespondentName") } }
    var defaultTagIDs: [Int] { didSet { defaults.set(defaultTagIDs, forKey: "defaultTagIDs") } }
    var defaultTagNames: [String] { didSet { defaults.set(defaultTagNames, forKey: "defaultTagNames") } }

    // Import
    var autoImport: Bool { didSet { defaults.set(autoImport, forKey: "autoImport") } }
    var maxParallelUploads: Int { didSet { defaults.set(maxParallelUploads, forKey: "maxParallelUploads") } }
    var retryIntervalMinutes: Int { didSet { defaults.set(retryIntervalMinutes, forKey: "retryIntervalMinutes") } }
    var titleTemplate: String { didSet { defaults.set(titleTemplate, forKey: "titleTemplate") } }
    var duplicateCheck: Bool { didSet { defaults.set(duplicateCheck, forKey: "duplicateCheck") } }
    var initialImportModeRaw: String { didSet { defaults.set(initialImportModeRaw, forKey: "initialImportMode") } }
    var initialImportDate: Date { didSet { defaults.set(initialImportDate, forKey: "initialImportDate") } }
    /// Zeitpunkt der Einrichtung (für „Nur neue PDFs“).
    var importBaselineDate: Date? { didSet { defaults.set(importBaselineDate, forKey: "importBaselineDate") } }

    // Benachrichtigungen
    var notifyImportSuccess: Bool { didSet { defaults.set(notifyImportSuccess, forKey: "notifyImportSuccess") } }
    var notifyImportFailed: Bool { didSet { defaults.set(notifyImportFailed, forKey: "notifyImportFailed") } }
    var notifyConnectionLost: Bool { didSet { defaults.set(notifyConnectionLost, forKey: "notifyConnectionLost") } }
    var notifyManualReview: Bool { didSet { defaults.set(notifyManualReview, forKey: "notifyManualReview") } }

    // Datenschutz
    var logRetentionDays: Int { didSet { defaults.set(logRetentionDays, forKey: "logRetentionDays") } }
    var hideIBANs: Bool { didSet { defaults.set(hideIBANs, forKey: "hideIBANs") } }

    // Login-Item
    private(set) var launchAtLoginError: String?


    init() {
        let d = UserDefaults.standard
        appearance = AppearanceMode(rawValue: d.string(forKey: "appearance") ?? "") ?? .dark
        accent = AccentOption(rawValue: d.string(forKey: "accent") ?? "") ?? .blue
        onboardingCompleted = d.bool(forKey: "onboardingCompleted")
        sidebarCollapsed = d.bool(forKey: "sidebarCollapsed")
        showMenuBarIcon = d.object(forKey: "showMenuBarIcon") as? Bool ?? true
        folderBookmark = d.data(forKey: "folderBookmark")
        folderPath = d.string(forKey: "folderPath") ?? ""
        watchFolder = d.object(forKey: "watchFolder") as? Bool ?? true
        paperlessURL = d.string(forKey: "paperlessURL") ?? ""
        verifyTLS = d.object(forKey: "verifyTLS") as? Bool ?? true
        defaultDocumentTypeID = d.object(forKey: "defaultDocumentTypeID") as? Int
        defaultDocumentTypeName = d.string(forKey: "defaultDocumentTypeName")
        defaultCorrespondentID = d.object(forKey: "defaultCorrespondentID") as? Int
        defaultCorrespondentName = d.string(forKey: "defaultCorrespondentName")
        defaultTagIDs = d.array(forKey: "defaultTagIDs") as? [Int] ?? []
        defaultTagNames = d.array(forKey: "defaultTagNames") as? [String] ?? []
        autoImport = d.object(forKey: "autoImport") as? Bool ?? true
        maxParallelUploads = min(max(d.object(forKey: "maxParallelUploads") as? Int ?? 1, 1), 3)
        retryIntervalMinutes = d.object(forKey: "retryIntervalMinutes") as? Int ?? 15
        titleTemplate = d.string(forKey: "titleTemplate") ?? TitleTemplate.defaultTemplate
        duplicateCheck = d.object(forKey: "duplicateCheck") as? Bool ?? true
        initialImportModeRaw = d.string(forKey: "initialImportMode") ?? InitialImportMode.all.rawValue
        initialImportDate = d.object(forKey: "initialImportDate") as? Date
            ?? Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        importBaselineDate = d.object(forKey: "importBaselineDate") as? Date
        notifyImportSuccess = d.object(forKey: "notifyImportSuccess") as? Bool ?? true
        notifyImportFailed = d.object(forKey: "notifyImportFailed") as? Bool ?? true
        notifyConnectionLost = d.object(forKey: "notifyConnectionLost") as? Bool ?? true
        notifyManualReview = d.object(forKey: "notifyManualReview") as? Bool ?? true
        logRetentionDays = d.object(forKey: "logRetentionDays") as? Int ?? 90
        hideIBANs = d.bool(forKey: "hideIBANs")
        AccentTheme.shared.option = accent
    }

    var initialImportMode: InitialImportMode {
        get { InitialImportMode(rawValue: initialImportModeRaw) ?? .all }
        set { initialImportModeRaw = newValue.rawValue }
    }

    var hasPaperlessCredentials: Bool {
        !paperlessURL.trimmingCharacters(in: .whitespaces).isEmpty && KeychainService.hasToken
    }

    /// Erzeugt einen Paperless-Client mit den aktuellen Einstellungen.
    func makeClient(tokenOverride: String? = nil, urlOverride: String? = nil) throws -> PaperlessClient {
        let url = (urlOverride ?? paperlessURL)
        let token = tokenOverride ?? KeychainService.readToken() ?? ""
        return try PaperlessClient(baseURLString: url, token: token, verifyTLS: verifyTLS)
    }

    // MARK: Beim Login starten

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
    }
}
