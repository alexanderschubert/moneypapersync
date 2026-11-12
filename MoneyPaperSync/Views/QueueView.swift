import SwiftUI
import SwiftData

struct QueueView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \StatementDocument.detectedAt, order: .reverse) private var documents: [StatementDocument]

    private var items: [StatementDocument] {
        documents.filter { $0.status.isInQueue }.sorted {
            if $0.status.isActive != $1.status.isActive { return $0.status.isActive }
            return $0.detectedAt > $1.detectedAt
        }
    }

    private var transientFailures: Int {
        documents.filter { $0.status == .failed && $0.isTransientError }.count
    }

    var body: some View {
        PageScaffold { _ in
            PageHeader("Warteschlange", subtitle: subtitle) {
                HStack(spacing: AppSpacing.md) {
                    SecondaryButton(title: "Temporäre Fehler erneut versuchen", systemImage: "arrow.clockwise") {
                        env.sync.retryAllTransientFailures()
                    }
                    .disabled(transientFailures == 0)
                    PrimaryButton(title: "Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath", isLoading: env.sync.isScanning) {
                        Task { await env.sync.syncNow() }
                    }
                }
            }

            if !env.settings.autoImport, items.contains(where: { $0.status == .newDetected }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "pause.circle").foregroundStyle(AppColors.warning)
                    Text("Der automatische Import ist deaktiviert. Wartende Dokumente werden erst mit „Jetzt synchronisieren“ hochgeladen.")
                        .font(AppFont.secondary)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .flatPanel()
            }

            if items.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.circle",
                    title: "Warteschlange ist leer",
                    message: "Alle erkannten Dokumente sind verarbeitet. Neue PDFs erscheinen hier automatisch."
                )
                .flatPanel()
            } else {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(items) { doc in
                        QueueRow(document: doc)
                    }
                }
            }
        }
    }

    private var subtitle: String {
        items.isEmpty ? "Keine offenen Dokumente" : "\(items.count) offene Dokumente"
    }
}

private struct QueueRow: View {
    @Environment(AppEnvironment.self) private var env
    let document: StatementDocument

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.lg) {
            Image(systemName: document.status.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(document.status.color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(document.status.color.opacity(0.14)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.sm) {
                    Text(document.fileName)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    StatusBadge(status: document.status)
                }
                Text(meta)
                    .font(AppFont.secondary)
                    .foregroundStyle(AppColors.textMuted)
                    .lineLimit(1)

                if document.status.isActive || document.status == .newDetected {
                    ProgressView(value: document.progress)
                        .progressViewStyle(.linear)
                        .tint(document.status.color)
                        .frame(maxWidth: 360)
                        .accessibilityLabel("Fortschritt")
                        .accessibilityValue("\(Int(document.progress * 100)) Prozent")
                }
                if let error = document.lastError,
                   document.status == .failed || document.status == .needsReview {
                    Text(error)
                        .font(AppFont.secondary)
                        .foregroundStyle(document.status.color)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: AppSpacing.md)

            VStack(alignment: .trailing, spacing: AppSpacing.sm) {
                Text(DateFormat.dateTime.string(from: document.detectedAt))
                    .font(AppFont.caption.monospacedDigit())
                    .foregroundStyle(AppColors.textMuted)
                HStack(spacing: AppSpacing.sm) {
                    if document.status == .failed || document.status == .newDetected {
                        SecondaryButton(title: document.status == .failed ? "Erneut versuchen" : "Jetzt hochladen", systemImage: "arrow.clockwise") {
                            env.sync.retry(document)
                        }
                    }
                    if document.status == .needsReview || document.status == .failed {
                        SecondaryButton(title: "Zuordnen", systemImage: "link") {
                            env.editingDocument = document
                        }
                    }
                    SecondaryButton(title: "Öffnen", systemImage: "doc.richtext") {
                        env.sync.openPDF(document)
                    }
                    Button {
                        env.open(document)
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(AppColors.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Details")
                    .accessibilityLabel("Details anzeigen")
                }
            }
        }
        .padding(AppSpacing.lg)
        .flatPanel()
        .appAnimation(value: document.statusRaw)
        .accessibilityElement(children: .contain)
    }

    private var meta: String {
        [document.bank?.name ?? "Bank unbekannt", document.account?.name ?? "Konto offen"].joined(separator: " · ")
    }
}
