import SwiftUI
import SwiftData

@main
struct MoneyPaperSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var env: AppEnvironment

    init() {
        let schema = Schema([Bank.self, Account.self, StatementDocument.self, LogEntry.self])
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Lokale Datenbank konnte nicht geöffnet werden: \(error)")
        }
        let environment = AppEnvironment(container: container)
        _env = State(initialValue: environment)
        AppDelegate.keepRunningInMenuBar = { [settings = environment.settings] in
            MainActor.assumeIsolated { settings.showMenuBarIcon && settings.onboardingCompleted }
        }
    }

    var body: some Scene {
        WindowGroup("MoneyPaperSync", id: "main") {
            RootView()
                .environment(env)
                .modelContainer(env.container)
                .frame(
                    minWidth: AppLayout.minWidth,
                    idealWidth: AppLayout.idealWidth,
                    minHeight: AppLayout.minHeight,
                    idealHeight: AppLayout.idealHeight
                )
                .onAppear {
                    env.sync.start()
                    #if DEBUG
                    DebugSnapshots.runIfRequested(env: env)
                    #endif
                }
        }
        .defaultSize(width: AppLayout.idealWidth, height: AppLayout.idealHeight)
        .windowStyle(.hiddenTitleBar)
        MenuBarExtra(isInserted: Binding(
            get: { env.settings.showMenuBarIcon },
            set: { env.settings.showMenuBarIcon = $0 }
        )) {
            MenuBarContent()
                .environment(env)
                .modelContainer(env.container)
        } label: {
            MenuBarLabel()
                .modelContainer(env.container)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Einstellungen …") { env.navigate(to: .settings) }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                Button("Nach Updates suchen …") { env.updater.checkForUpdates() }
                    .disabled(!env.updater.canCheck)
            }
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Synchronisation") {
                Button("Jetzt synchronisieren") {
                    Task { await env.sync.syncNow() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!env.settings.onboardingCompleted)
                Button("Alle temporären Fehler erneut versuchen") {
                    env.sync.retryAllTransientFailures()
                }
                .disabled(!env.settings.onboardingCompleted)
            }
            CommandGroup(after: .sidebar) {
                Button(env.settings.sidebarCollapsed ? "Sidebar einblenden" : "Sidebar einklappen") {
                    env.toggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
            CommandMenu("Navigation") {
                ForEach(Array(SidebarItem.allCases.enumerated()), id: \.element) { index, item in
                    Button(item.title) { env.navigate(to: item) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }
    }
}
