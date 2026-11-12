import AppKit
import Foundation

/// Erkennt eine installierte MoneyMoney-App und sucht in ihrem Datenordner nach Ordnern mit PDFs.
/// Die Sandbox erlaubt keinen Zugriff auf fremde Container: Der Nutzer bestätigt den Datenordner einmal
/// im Öffnen-Dialog, danach wird nur lesend gesucht.
enum MoneyMoneyLocator {
    struct Candidate: Identifiable, Hashable {
        let url: URL
        let pdfCount: Int
        var id: URL { url }
    }

    private static let bundleIdentifiers = ["com.moneymoney-app.retail", "com.moneymoney-app.mac"]
    /// Namen des Sandbox-Containers (MoneyMoney nutzt „MoneyMoney“, nicht die Bundle-ID).
    private static let containerNames = ["MoneyMoney"] + bundleIdentifiers
    private static let statementsPath = "Data/Library/Application Support/MoneyMoney/Statements"

    static var appURL: URL? {
        bundleIdentifiers.lazy.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.first
    }

    static var isInstalled: Bool { appURL != nil }

    static var version: String? {
        guard let appURL else { return nil }
        return Bundle(url: appURL)?.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// Echtes Home-Verzeichnis (in der Sandbox zeigt `NSHomeDirectory()` auf den App-Container).
    private static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return URL(fileURLWithPath: "/Users/\(NSUserName())", isDirectory: true)
    }

    /// Ordner, in dem MoneyMoney die Kontoauszüge ablegt; sonst der Datenordner, sonst der erwartete Pfad.
    static var dataFolderHint: URL {
        let containers = realHome.appendingPathComponent("Library/Containers", isDirectory: true)
        let fm = FileManager.default
        for name in containerNames {
            let statements = containers.appendingPathComponent("\(name)/\(statementsPath)", isDirectory: true)
            if fm.fileExists(atPath: statements.path) { return statements }
        }
        for name in containerNames {
            let data = containers.appendingPathComponent("\(name)/Data", isDirectory: true)
            if fm.fileExists(atPath: data.path) { return data }
        }
        return containers.appendingPathComponent("MoneyMoney/\(statementsPath)", isDirectory: true)
    }

    /// Sucht unterhalb von `root` alle Ordner, die PDFs enthalten, absteigend nach Anzahl sortiert.
    static func findCandidates(under root: URL, maxDepth: Int = 8, maxEntries: Int = 100_000) -> [Candidate] {
        let rootDepth = root.standardizedFileURL.pathComponents.count
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var counts: [URL: Int] = [:]
        var visited = 0
        for case let url as URL in enumerator {
            visited += 1
            if visited > maxEntries { break }
            if url.standardizedFileURL.pathComponents.count - rootDepth > maxDepth {
                enumerator.skipDescendants()
                continue
            }
            if url.pathExtension.lowercased() == "pdf" {
                counts[url.deletingLastPathComponent(), default: 0] += 1
            }
        }
        let folders = counts
            .map { Candidate(url: $0.key, pdfCount: $0.value) }
            .sorted { $0.pdfCount != $1.pdfCount ? $0.pdfCount > $1.pdfCount : $0.url.path < $1.url.path }
        // Der gewählte Ordner selbst (alle PDFs darunter) steht oben, wenn er mehr als einen Unterordner umfasst.
        let total = counts.values.reduce(0, +)
        guard total > 0, !(folders.count == 1 && folders[0].url.standardizedFileURL == root.standardizedFileURL) else { return folders }
        return [Candidate(url: root, pdfCount: total)] + folders.filter { $0.url.standardizedFileURL != root.standardizedFileURL }
    }
}
