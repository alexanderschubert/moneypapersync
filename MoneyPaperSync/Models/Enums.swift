import SwiftUI

// MARK: - Dokumentstatus

enum DocumentStatus: String, CaseIterable, Codable, Identifiable {
    case newDetected
    case analyzing
    case uploading
    case processing
    case imported
    case needsReview
    case failed
    case duplicate
    case ignored

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newDetected: "Neu erkannt"
        case .analyzing: "Analyse läuft"
        case .uploading: "Upload läuft"
        case .processing: "Paperless verarbeitet"
        case .imported: "Erfolgreich"
        case .needsReview: "Manuelle Prüfung"
        case .failed: "Fehler"
        case .duplicate: "Dublette"
        case .ignored: "Ignoriert"
        }
    }

    var symbol: String {
        switch self {
        case .newDetected: "sparkle"
        case .analyzing: "magnifyingglass"
        case .uploading: "arrow.up.circle"
        case .processing: "gearshape.2"
        case .imported: "checkmark.circle.fill"
        case .needsReview: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        case .duplicate: "doc.on.doc"
        case .ignored: "eye.slash"
        }
    }

    var color: Color {
        switch self {
        case .newDetected: AppColors.accent
        case .analyzing: AppColors.accentCyan
        case .uploading: AppColors.accent
        case .processing: AppColors.violet
        case .imported: AppColors.success
        case .needsReview: AppColors.warning
        case .failed: AppColors.error
        case .duplicate: AppColors.neutral
        case .ignored: AppColors.neutral
        }
    }

    /// Erscheint in der Warteschlange (noch zu verarbeiten oder Aufmerksamkeit nötig).
    var isInQueue: Bool {
        switch self {
        case .newDetected, .analyzing, .uploading, .processing, .needsReview, .failed: true
        case .imported, .duplicate, .ignored: false
        }
    }

    var isActive: Bool {
        self == .analyzing || self == .uploading || self == .processing
    }
}

/// Filter in der Dokumentenübersicht.
enum DocumentFilter: String, CaseIterable, Identifiable {
    case all, imported, waiting, failed, review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Alle Dokumente"
        case .imported: "Erfolgreich importiert"
        case .waiting: "Wartend"
        case .failed: "Fehlerhaft"
        case .review: "Manuelle Prüfung erforderlich"
        }
    }

    func matches(_ status: DocumentStatus) -> Bool {
        switch self {
        case .all: true
        case .imported: status == .imported
        case .waiting: [.newDetected, .analyzing, .uploading, .processing].contains(status)
        case .failed: status == .failed
        case .review: status == .needsReview
        }
    }
}

// MARK: - Kontotyp

enum AccountType: String, CaseIterable, Codable, Identifiable {
    case checking, creditCard, savings, savingsBook, fixedDeposit, depot, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checking: "Girokonto"
        case .creditCard: "Kreditkarte"
        case .savings: "Sparkonto"
        case .savingsBook: "Sparbuch"
        case .fixedDeposit: "Tagesgeld"
        case .depot: "Depot"
        case .other: "Sonstiges"
        }
    }

    /// Bezeichnung der Kennung, die statt (oder zusätzlich zu) einer IBAN im PDF gesucht wird.
    var referenceLabel: String? {
        switch self {
        case .creditCard: "Kartennummer"
        case .savingsBook: "Sparbuchnummer"
        default: nil
        }
    }

    /// Kreditkarten haben keine IBAN.
    var usesIBAN: Bool { self != .creditCard }

    var symbol: String {
        switch self {
        case .checking: "banknote"
        case .creditCard: "creditcard"
        case .savings: "leaf"
        case .savingsBook: "book.closed"
        case .fixedDeposit: "calendar"
        case .depot: "chart.line.uptrend.xyaxis"
        case .other: "square.grid.2x2"
        }
    }
}

// MARK: - Protokoll

enum LogLevel: String, CaseIterable, Codable, Identifiable {
    case info, success, warning, error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .info: "Info"
        case .success: "Erfolgreich"
        case .warning: "Warnung"
        case .error: "Fehler"
        }
    }

    var symbol: String {
        switch self {
        case .info: "info.circle"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info: AppColors.info
        case .success: AppColors.success
        case .warning: AppColors.warning
        case .error: AppColors.error
        }
    }
}

enum LogEvent: String, CaseIterable, Codable {
    case pdfDetected, pdfValidated, hashComputed, duplicateDetected
    case bankDetected, accountAssigned
    case uploadStarted, taskCompleted, importFailed
    case manualReview, connection, system

    var title: String {
        switch self {
        case .pdfDetected: "PDF erkannt"
        case .pdfValidated: "PDF validiert"
        case .hashComputed: "Hash berechnet"
        case .duplicateDetected: "Dublette erkannt"
        case .bankDetected: "Bank erkannt"
        case .accountAssigned: "Konto zugeordnet"
        case .uploadStarted: "Paperless-Upload gestartet"
        case .taskCompleted: "Paperless-Task abgeschlossen"
        case .importFailed: "Import fehlgeschlagen"
        case .manualReview: "Manuelle Prüfung"
        case .connection: "Verbindung"
        case .system: "System"
        }
    }
}

enum LogFilter: String, CaseIterable, Identifiable {
    case all, success, warnings, errors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Alle"
        case .success: "Erfolgreich"
        case .warnings: "Warnungen"
        case .errors: "Fehler"
        }
    }

    func matches(_ level: LogLevel) -> Bool {
        switch self {
        case .all: true
        case .success: level == .success
        case .warnings: level == .warning
        case .errors: level == .error
        }
    }
}

// MARK: - Navigation

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case dashboard, documents, queue, accounts, banks, log, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .documents: "Dokumente"
        case .queue: "Warteschlange"
        case .accounts: "Konten"
        case .banks: "Banken"
        case .log: "Protokoll"
        case .settings: "Einstellungen"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .documents: "doc.text"
        case .queue: "clock.arrow.circlepath"
        case .accounts: "person.crop.rectangle.stack"
        case .banks: "building.columns"
        case .log: "list.bullet.rectangle"
        case .settings: "gearshape"
        }
    }
}

// MARK: - Verbindungsstatus

struct ConnectionState: Equatable {
    enum Kind: Equatable { case ok, warning, error, neutral, checking }

    var kind: Kind
    var title: String
    var detail: String?

    static let checking = ConnectionState(kind: .checking, title: "Wird geprüft …", detail: nil)
    static let notConfigured = ConnectionState(kind: .neutral, title: "Nicht eingerichtet", detail: nil)

    var color: Color {
        switch kind {
        case .ok: AppColors.success
        case .warning: AppColors.warning
        case .error: AppColors.error
        case .neutral, .checking: AppColors.neutral
        }
    }

    var symbol: String {
        switch kind {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .neutral: "minus.circle"
        case .checking: "arrow.triangle.2.circlepath"
        }
    }

    var isOK: Bool { kind == .ok }
}

// MARK: - Erstimport

enum InitialImportMode: String, CaseIterable, Identifiable {
    case all, fromDate, newOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Alle vorhandenen PDFs"
        case .fromDate: "PDFs ab einem Datum"
        case .newOnly: "Nur neue PDFs"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case dark, light, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: "Dunkel"
        case .light: "Hell"
        case .system: "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}
