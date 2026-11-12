import SwiftUI
import SwiftData
import AppKit

/// Hält die App im Hintergrund am Laufen, solange das Menüleisten-Symbol aktiv ist.
final class AppDelegate: NSObject, NSApplicationDelegate {
    nonisolated(unsafe) static var keepRunningInMenuBar: () -> Bool = { false }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !Self.keepRunningInMenuBar()
    }
}

/// Symbol in der Menüleiste; zeigt die Zahl der Dokumente, die Aufmerksamkeit brauchen.
struct MenuBarLabel: View {
    @Query private var documents: [StatementDocument]

    private var attention: Int {
        documents.filter { $0.status == .failed || $0.status == .needsReview }.count
    }

    /// Feste Größe wie bei Standard-Symbolen der Menüleiste (die Leiste ignoriert `frame` bei Bildern).
    private static let icon: NSImage = {
        let image = (NSImage(named: "LogoMono") ?? NSImage()).copy() as! NSImage
        image.size = NSSize(width: 14, height: 14)
        image.isTemplate = true
        return image
    }()

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: Self.icon)
            if attention > 0 {
                Text("\(attention)").monospacedDigit()
            }
        }
        .accessibilityLabel(attention > 0 ? "MoneyPaperSync, \(attention) Dokumente brauchen Aufmerksamkeit" : "MoneyPaperSync")
    }
}

/// Inhalt des Menüleisten-Menüs.
struct MenuBarContent: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openWindow) private var openWindow
    @Query private var documents: [StatementDocument]

    private var waiting: Int { documents.filter { DocumentFilter.waiting.matches($0.status) }.count }
    private var failed: Int { documents.filter { $0.status == .failed }.count }
    private var review: Int { documents.filter { $0.status == .needsReview }.count }
    private var lastImport: Date? { documents.compactMap(\.importedAt).max() }

    var body: some View {
        Text(env.sync.summary.text)
        if let lastImport {
            Text("Letzter Import: \(DateFormat.dateTime.string(from: lastImport))")
        }
        Divider()
        Text("Wartend: \(waiting.formatted())")
        if failed > 0 { Text("Fehler: \(failed.formatted())") }
        if review > 0 { Text("Manuelle Prüfung: \(review.formatted())") }
        Divider()
        Button("Jetzt synchronisieren") {
            Task { await env.sync.syncNow() }
        }
        .disabled(!env.settings.onboardingCompleted || env.sync.isScanning)
        Button("MoneyPaperSync öffnen") { showMainWindow() }
        Button("Nach Updates suchen …") { env.updater.checkForUpdates() }
            .disabled(!env.updater.canCheck)
        Button("Einstellungen …") {
            env.navigate(to: .settings)
            showMainWindow()
        }
        .disabled(!env.settings.onboardingCompleted)
        Divider()
        Button("MoneyPaperSync beenden") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.styleMask.contains(.titled) && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}
