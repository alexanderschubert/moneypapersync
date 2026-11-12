import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let container: ModelContainer
    let settings: AppSettings
    let log: LogService
    let notifier: NotificationService
    let sync: SyncEngine

    var selection: SidebarItem = .dashboard
    var detailDocument: StatementDocument?
    var editingDocument: StatementDocument?

    init(container: ModelContainer) {
        self.container = container
        let context = container.mainContext
        let settings = AppSettings()
        let log = LogService(context: context)
        let notifier = NotificationService(settings: settings)
        self.settings = settings
        self.log = log
        self.notifier = notifier
        self.sync = SyncEngine(context: context, settings: settings, log: log, notifier: notifier)
    }

    func navigate(to item: SidebarItem) {
        selection = item
    }

    func open(_ document: StatementDocument) {
        detailDocument = document
    }

    func toggleSidebar() {
        settings.sidebarCollapsed.toggle()
    }

    /// Wird nach Abschluss des Onboardings aufgerufen.
    func finishOnboarding() {
        if settings.initialImportMode == .newOnly { settings.importBaselineDate = Date() }
        settings.onboardingCompleted = true
        sync.restart()
    }
}
