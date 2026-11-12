import Foundation
import SwiftData
import UserNotifications

/// Schreibt Protokolleinträge. Meldungen werden vor dem Speichern bereinigt (keine IBANs/Tokens).
@MainActor
final class LogService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ event: LogEvent, _ level: LogLevel = .info, _ message: String, document: StatementDocument? = nil) {
        let entry = LogEntry(
            event: event,
            level: level,
            message: Redactor.sanitize(message),
            documentName: document?.fileName
        )
        context.insert(entry)
        try? context.save()
    }

    func purgeOld(retentionDays: Int) {
        guard retentionDays > 0,
              let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else { return }
        try? context.delete(model: LogEntry.self, where: #Predicate<LogEntry> { $0.timestamp < cutoff })
        try? context.save()
    }

    func clear() {
        try? context.delete(model: LogEntry.self)
        try? context.save()
    }
}

/// Lokale Benachrichtigungen mit Bündelung (verhindert Flut beim Erstimport).
@MainActor
final class NotificationService {
    enum Kind { case success, failure, review, connection }

    private let settings: AppSettings
    private var pendingSuccess: [String] = []
    private var pendingFailure: [String] = []
    private var pendingReview: [String] = []
    private var flushTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = ForegroundNotificationDelegate.shared
        }
    }

    var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        guard isAvailable else { return .notDetermined }
        return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func documentImported(_ name: String) {
        guard settings.notifyImportSuccess else { return }
        pendingSuccess.append(name)
        scheduleFlush()
    }

    func documentFailed(_ name: String) {
        guard settings.notifyImportFailed else { return }
        pendingFailure.append(name)
        scheduleFlush()
    }

    func reviewNeeded(_ name: String) {
        guard settings.notifyManualReview else { return }
        pendingReview.append(name)
        scheduleFlush()
    }

    func connectionLost(_ service: String) {
        guard settings.notifyConnectionLost else { return }
        deliver(title: "Verbindung verloren", body: "\(service) ist nicht mehr erreichbar.")
    }

    private func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    private func flush() {
        if !pendingSuccess.isEmpty {
            let n = pendingSuccess.count
            deliver(
                title: n == 1 ? "Import erfolgreich" : "\(n) Dokumente importiert",
                body: n == 1 ? pendingSuccess[0] : "Die Kontoauszüge wurden in Paperless-ngx archiviert."
            )
            pendingSuccess = []
        }
        if !pendingFailure.isEmpty {
            let n = pendingFailure.count
            deliver(
                title: n == 1 ? "Import fehlgeschlagen" : "\(n) Importe fehlgeschlagen",
                body: n == 1 ? pendingFailure[0] : "Details findest du im Protokoll."
            )
            pendingFailure = []
        }
        if !pendingReview.isEmpty {
            let n = pendingReview.count
            deliver(
                title: "Manuelle Prüfung erforderlich",
                body: n == 1 ? pendingReview[0] : "\(n) Dokumente benötigen eine Zuordnung."
            )
            pendingReview = []
        }
    }

    private func deliver(title: String, body: String) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Zeigt Benachrichtigungen auch an, wenn die App im Vordergrund ist.
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = ForegroundNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
