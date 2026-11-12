import Foundation
import SwiftData

// MARK: - Bank

@Model
final class Bank {
    var id: UUID = UUID()
    var name: String = ""
    /// Erkennungsmerkmale, die im PDF-Text gesucht werden (Groß-/Kleinschreibung egal).
    var keywords: [String] = []
    var isActive: Bool = true
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Account.bank)
    var accounts: [Account] = []

    @Relationship(deleteRule: .nullify, inverse: \StatementDocument.bank)
    var documents: [StatementDocument] = []

    init(name: String, keywords: [String], isActive: Bool = true) {
        self.name = name
        self.keywords = keywords
        self.isActive = isActive
    }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

// MARK: - Konto

@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    /// Maskierte IBAN (z. B. "DE•• •••• •••• 1234"). Vollständige IBANs werden nie gespeichert.
    var ibanMasked: String = ""
    /// Maskierte Karten- bzw. Sparbuchnummer (nur die letzten vier Stellen bleiben lesbar).
    var referenceMasked: String = ""
    var typeRaw: String = AccountType.checking.rawValue
    var isActive: Bool = true
    var paperlessCorrespondentID: Int?
    var paperlessCorrespondentName: String?
    var tagIDs: [Int] = []
    var tagNames: [String] = []
    /// Leer = globale Vorlage aus den Einstellungen.
    var titleTemplate: String = ""
    var createdAt: Date = Date()

    var bank: Bank?

    @Relationship(deleteRule: .nullify, inverse: \StatementDocument.account)
    var documents: [StatementDocument] = []

    init(name: String, ibanMasked: String = "", type: AccountType = .checking, bank: Bank? = nil) {
        self.name = name
        self.ibanMasked = ibanMasked
        self.typeRaw = type.rawValue
        self.bank = bank
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var ibanLast4: String? {
        let digits = ibanMasked.filter { $0.isLetter || $0.isNumber }
        guard digits.count >= 4 else { return nil }
        return String(digits.suffix(4))
    }

    var referenceLast4: String? {
        let digits = referenceMasked.filter(\.isNumber)
        guard digits.count >= 4 else { return nil }
        return String(digits.suffix(4))
    }

    /// Letzte vier Stellen aller Kennungen, anhand derer PDFs diesem Konto zugeordnet werden.
    var matchKeys: Set<String> {
        Set([ibanLast4, referenceLast4].compactMap { $0 })
    }

    var importedCount: Int {
        documents.filter { $0.status == .imported }.count
    }
}

// MARK: - Dokument

@Model
final class StatementDocument {
    var id: UUID = UUID()
    var fileName: String = ""
    /// Pfad relativ zum gewählten Statements-Ordner.
    var relativePath: String = ""
    var sha256: String = ""
    var statusRaw: String = DocumentStatus.newDetected.rawValue
    var progress: Double = 0

    var documentDate: Date?
    var periodStart: Date?
    var periodEnd: Date?

    var paperlessDocumentID: Int?
    var paperlessTaskID: String?

    var lastError: String?
    var isTransientError: Bool = false
    var attempts: Int = 0
    var analysisDone: Bool = false
    /// Vom Nutzer manuell freigegeben (Import auch bei deaktiviertem Auto-Import).
    var userApproved: Bool = false

    var fileSize: Int64 = 0
    var fileModifiedAt: Date?
    var detectedAt: Date = Date()
    var updatedAt: Date = Date()
    var importedAt: Date?

    var bank: Bank?
    var account: Account?

    init(fileName: String, relativePath: String, fileSize: Int64, fileModifiedAt: Date?) {
        self.fileName = fileName
        self.relativePath = relativePath
        self.fileSize = fileSize
        self.fileModifiedAt = fileModifiedAt
    }

    var status: DocumentStatus {
        get { DocumentStatus(rawValue: statusRaw) ?? .newDetected }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var periodText: String {
        if let start = periodStart, let end = periodEnd {
            let cal = Calendar.current
            if cal.isDate(start, equalTo: end, toGranularity: .month) {
                return DateFormat.monthYear.string(from: end)
            }
            return "\(DateFormat.short.string(from: start)) – \(DateFormat.short.string(from: end))"
        }
        if let date = documentDate { return DateFormat.monthYear.string(from: date) }
        return "–"
    }

    /// Referenzdatum für Titel, Filter und Statistik.
    var referenceDate: Date? { periodEnd ?? documentDate }
}

// MARK: - Protokoll

@Model
final class LogEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var eventRaw: String = LogEvent.system.rawValue
    var levelRaw: String = LogLevel.info.rawValue
    var message: String = ""
    var documentName: String?

    init(event: LogEvent, level: LogLevel, message: String, documentName: String?) {
        self.eventRaw = event.rawValue
        self.levelRaw = level.rawValue
        self.message = message
        self.documentName = documentName
    }

    var event: LogEvent { LogEvent(rawValue: eventRaw) ?? .system }
    var level: LogLevel { LogLevel(rawValue: levelRaw) ?? .info }
}

// MARK: - Datumsformate

enum DateFormat {
    static let monthYear: DateFormatter = make("LLLL yyyy")
    static let monthShortYear: DateFormatter = make("LLL yyyy")
    static let short: DateFormatter = make("dd.MM.yyyy")
    static let dateTime: DateFormatter = make("dd.MM.yyyy HH:mm")
    static let time: DateFormatter = make("HH:mm")
    static let monthOnly: DateFormatter = make("LLLL")
    static let yearOnly: DateFormatter = make("yyyy")
    static let iso: DateFormatter = {
        let f = make("yyyy-MM-dd")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = format
        return f
    }
}

// Explizite Identifiable-Konformität (id ist eine UUID-Eigenschaft der Modelle).
extension Bank: Identifiable {}
extension Account: Identifiable {}
extension StatementDocument: Identifiable {}
extension LogEntry: Identifiable {}
