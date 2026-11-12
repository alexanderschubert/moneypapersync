import Foundation
import PDFKit
import CryptoKit

struct BankRule: Sendable {
    let id: UUID
    let name: String
    let keywords: [String]
}

struct PDFAnalysis: Sendable {
    var sha256: String = ""
    var pageCount: Int = 0
    var isValid = false
    var isLocked = false
    var errorMessage: String?
    /// Nur maskierte IBANs verlassen den Analyzer.
    var maskedIBANs: [String] = []
    /// Letzte vier Stellen gefundener Karten-/Sparbuchnummern (mehr verlässt den Analyzer nicht).
    var referenceLast4: [String] = []
    var bankID: UUID?
    var bankMatchedByContent = false
    var bankMatchedByFileName = false
    var periodStart: Date?
    var periodEnd: Date?
    var documentDate: Date?
}

enum PDFAnalyzer {
    /// Läuft außerhalb des Main-Threads. Das Original wird nur gelesen.
    static func analyze(url: URL, fileName: String, fileModified: Date?, banks: [BankRule]) -> PDFAnalysis {
        var result = PDFAnalysis()

        do {
            result.sha256 = try sha256(of: url)
        } catch {
            result.errorMessage = "Datei nicht lesbar"
            return result
        }

        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            result.errorMessage = "Keine gültige PDF-Datei"
            return result
        }
        result.pageCount = document.pageCount
        if document.isLocked {
            result.isLocked = true
            result.errorMessage = "PDF ist passwortgeschützt"
            return result
        }
        result.isValid = true

        var text = ""
        for index in 0..<min(document.pageCount, 3) {
            text += (document.page(at: index)?.string ?? "") + "\n"
        }

        result.maskedIBANs = findIBANs(in: text)
        result.referenceLast4 = findReferences(in: text)

        let match = detectBank(text: text, fileName: fileName, banks: banks)
        result.bankID = match.id
        result.bankMatchedByContent = match.byContent
        result.bankMatchedByFileName = match.byFileName

        let dates = DateExtractor.extract(text: text, fileName: fileName, fileModified: fileModified)
        result.periodStart = dates.start
        result.periodEnd = dates.end
        result.documentDate = dates.documentDate
        return result
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1_048_576) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static let ibanRegex = try! NSRegularExpression(
        pattern: #"\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]{4}){2,7}(?:[ ]?[A-Z0-9]{1,4})?\b"#
    )

    private static func findIBANs(in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        var seen: [String] = []
        for match in ibanRegex.matches(in: text, range: range) {
            guard let r = Range(match.range, in: text) else { continue }
            let candidate = String(text[r])
            if IBANTools.isValid(candidate) {
                let masked = IBANTools.mask(candidate)
                if !seen.contains(masked) { seen.append(masked) }
            }
        }
        return seen
    }

    private static let cardRegex = try! NSRegularExpression(pattern: #"(?<![\d])(?:\d[ -]?){12,18}\d(?![\d])"#)
    /// Teilweise verdeckte Nummern wie „3782 ****** 10005“ oder „XXXX XXXXXX 10005“.
    private static let maskedCardRegex = try! NSRegularExpression(pattern: #"(?:[Xx*•#.]{2,}[ -]*)+(\d{4,5})(?!\d)"#)
    /// Nummer hinter Stichwörtern wie „Sparbuch-Nr.“ oder „Kontonummer“.
    private static let labeledRegex = try! NSRegularExpression(
        pattern: #"(?i)(?:sparbuch(?:[- ]?(?:nummer|nr\.?))?|kontonummer|konto-?nr\.?|karten(?:nummer|-?nr\.?))\D{0,15}?(\d[\d ./-]{2,18}\d)"#
    )

    private static func findReferences(in text: String) -> [String] {
        // IBANs vorher entfernen, damit ihre Ziffernblöcke nicht als Kartennummer gelten.
        var cleaned = text
        let full = NSRange(cleaned.startIndex..., in: cleaned)
        cleaned = ibanRegex.stringByReplacingMatches(in: cleaned, range: full, withTemplate: " ")

        var found: [String] = []
        func add(_ digits: String) {
            guard digits.count >= 4 else { return }
            let last4 = String(digits.suffix(4))
            if !found.contains(last4) { found.append(last4) }
        }
        let range = { NSRange(cleaned.startIndex..., in: cleaned) }
        for match in cardRegex.matches(in: cleaned, range: range()) {
            guard let r = Range(match.range, in: cleaned) else { continue }
            let candidate = String(cleaned[r])
            if ReferenceTools.isValidCardNumber(candidate) { add(ReferenceTools.digits(candidate)) }
        }
        for regex in [maskedCardRegex, labeledRegex] {
            for match in regex.matches(in: cleaned, range: range()) {
                guard match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: cleaned) else { continue }
                add(ReferenceTools.digits(String(cleaned[r])))
            }
        }
        return found
    }

    private static func detectBank(text: String, fileName: String, banks: [BankRule]) -> (id: UUID?, byContent: Bool, byFileName: Bool) {
        let haystack = text.lowercased()
        let name = fileName.lowercased()
        var bestID: UUID?
        var bestScore = 0
        var content = false
        var file = false

        for bank in banks {
            let terms = (bank.keywords + [bank.name])
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
            var contentHits = 0
            var fileHits = 0
            for term in Set(terms) {
                contentHits += haystack.components(separatedBy: term).count - 1
                if name.contains(term) { fileHits += 1 }
            }
            let score = min(contentHits, 10) * 2 + fileHits
            if score > bestScore {
                bestScore = score
                bestID = bank.id
                content = contentHits > 0
                file = fileHits > 0
            }
        }
        return (bestID, content, file)
    }
}

// MARK: - Datumserkennung

enum DateExtractor {
    private static let germanDate = try! NSRegularExpression(pattern: #"\b(\d{1,2})\.(\d{1,2})\.(\d{4})\b"#)
    private static let isoDate = try! NSRegularExpression(pattern: #"(20\d{2})[-_.](0[1-9]|1[0-2])(?:[-_.](0[1-9]|[12]\d|3[01]))?"#)

    static func extract(text: String, fileName: String, fileModified: Date?) -> (start: Date?, end: Date?, documentDate: Date?) {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let lower = cal.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .distantPast
        let upper = cal.date(byAdding: .year, value: 1, to: now) ?? now

        var dates: [Date] = []
        let range = NSRange(text.startIndex..., in: text)
        for match in germanDate.matches(in: text, range: range) {
            guard match.numberOfRanges == 4,
                  let d = Range(match.range(at: 1), in: text).flatMap({ Int(text[$0]) }),
                  let m = Range(match.range(at: 2), in: text).flatMap({ Int(text[$0]) }),
                  let y = Range(match.range(at: 3), in: text).flatMap({ Int(text[$0]) }),
                  (1...31).contains(d), (1...12).contains(m),
                  let date = cal.date(from: DateComponents(year: y, month: m, day: d)),
                  date >= lower, date <= upper else { continue }
            dates.append(date)
        }

        if let minDate = dates.min(), let maxDate = dates.max() {
            let span = cal.dateComponents([.day], from: minDate, to: maxDate).day ?? 0
            if span <= 100 {
                return (minDate, maxDate, maxDate)
            }
            // Zu weit gestreut: letztes Datum als Dokumentdatum, Monat als Zeitraum.
            return (nil, nil, maxDate)
        }

        // Fallback: Dateiname (YYYY-MM[-DD])
        let nameRange = NSRange(fileName.startIndex..., in: fileName)
        if let match = isoDate.firstMatch(in: fileName, range: nameRange),
           let y = Range(match.range(at: 1), in: fileName).flatMap({ Int(fileName[$0]) }),
           let m = Range(match.range(at: 2), in: fileName).flatMap({ Int(fileName[$0]) }) {
            let day = Range(match.range(at: 3), in: fileName).flatMap { Int(fileName[$0]) }
            if let date = cal.date(from: DateComponents(year: y, month: m, day: day ?? 1)) {
                return (nil, nil, date)
            }
        }
        return (nil, nil, fileModified)
    }
}

// MARK: - Ordner-Scan

struct ScannedFile: Sendable {
    let relativePath: String
    let name: String
    let size: Int64
    let modified: Date?
}

enum FolderScanner {
    static func listPDFs(root: URL) -> [ScannedFile] {
        let fm = FileManager.default
        let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [ScannedFile] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "pdf" else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
            guard values?.isRegularFile == true else { continue }
            let full = url.standardizedFileURL.resolvingSymlinksInPath().path
            var relative = full
            if full.hasPrefix(rootPath) { relative = String(full.dropFirst(rootPath.count)) }
            while relative.hasPrefix("/") { relative.removeFirst() }
            files.append(ScannedFile(
                relativePath: relative,
                name: url.lastPathComponent,
                size: Int64(values?.fileSize ?? 0),
                modified: values?.contentModificationDate
            ))
        }
        return files
    }
}
