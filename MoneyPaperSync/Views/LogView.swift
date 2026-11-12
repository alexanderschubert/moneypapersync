import SwiftUI
import SwiftData

struct LogView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \LogEntry.timestamp, order: .reverse) private var entries: [LogEntry]

    @State private var filter: LogFilter = .all
    @State private var search = ""
    @State private var confirmClear = false

    private var filtered: [LogEntry] {
        let term = search.trimmingCharacters(in: .whitespaces).lowercased()
        return entries
            .filter { filter.matches($0.level) }
            .filter {
                term.isEmpty || $0.message.lowercased().contains(term)
                    || ($0.documentName?.lowercased().contains(term) ?? false)
                    || $0.event.title.lowercased().contains(term)
            }
    }

    private var options: [FilterOption<LogFilter>] {
        LogFilter.allCases.map { option in
            FilterOption(value: option, title: option.title, count: entries.filter { option.matches($0.level) }.count)
        }
    }

    var body: some View {
        PageScaffold { _ in
            PageHeader("Protokoll", subtitle: "Nachvollziehbare Synchronisationsvorgänge") {
                SecondaryButton(title: "Protokoll leeren", systemImage: "trash", isDestructive: true) {
                    confirmClear = true
                }
                .disabled(entries.isEmpty)
            }

            HStack(spacing: AppSpacing.md) {
                SearchField(text: $search, prompt: "Protokoll durchsuchen").frame(maxWidth: 320)
                FilterBar(options: options, selection: $filter)
            }

            if entries.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet.rectangle",
                    title: "Protokoll ist leer",
                    message: "Sobald PDFs erkannt oder importiert werden, erscheinen hier die einzelnen Schritte. IBANs, Tokens und Dokumentinhalte werden nie protokolliert."
                )
                .flatPanel()
            } else if filtered.isEmpty {
                EmptyStateView(systemImage: "magnifyingglass", title: "Keine Einträge", message: "Für Filter und Suche gibt es keine Treffer.")
                    .flatPanel()
            } else {
                VStack(spacing: 0) {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered.prefix(500)) { entry in
                            LogRow(entry: entry)
                            Divider().overlay(AppColors.divider)
                        }
                    }
                    if filtered.count > 500 {
                        Text("Die neuesten 500 von \(filtered.count) Einträgen werden angezeigt.")
                            .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
                            .padding(AppSpacing.md)
                    }
                }
                .flatPanel()
            }
        }
        .confirmationDialog("Protokoll wirklich leeren?", isPresented: $confirmClear) {
            Button("Leeren", role: .destructive) { env.log.clear() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Protokolleinträge werden dauerhaft gelöscht.")
        }
    }
}

private struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: entry.level.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(entry.level.color)
                .frame(width: 20)
                .accessibilityLabel(entry.level.title)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.sm) {
                    Text(entry.event.title).font(AppFont.bodyMedium).foregroundStyle(AppColors.textPrimary)
                    if let name = entry.documentName {
                        Text(name)
                            .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                Text(entry.message).font(AppFont.secondary).foregroundStyle(AppColors.textSecondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: AppSpacing.md)
            Text(DateFormat.dateTime.string(from: entry.timestamp))
                .font(AppFont.caption.monospacedDigit())
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}
