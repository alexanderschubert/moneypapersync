import SwiftUI
import SwiftData

struct DocumentsView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \StatementDocument.detectedAt, order: .reverse) private var documents: [StatementDocument]
    @Query(sort: \Bank.name) private var banks: [Bank]
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var search = ""
    @State private var filter: DocumentFilter = .all
    @State private var bankID: UUID?
    @State private var accountID: UUID?
    @State private var year: Int?
    @State private var month: Int?

    private func refDate(_ doc: StatementDocument) -> Date { doc.referenceDate ?? doc.detectedAt }

    private var years: [Int] {
        Set(documents.map { Calendar.current.component(.year, from: refDate($0)) }).sorted(by: >)
    }

    private var filtered: [StatementDocument] {
        let cal = Calendar.current
        let term = search.trimmingCharacters(in: .whitespaces).lowercased()
        return documents
            .filter { filter.matches($0.status) }
            .filter { bankID == nil || $0.bank?.id == bankID }
            .filter { accountID == nil || $0.account?.id == accountID }
            .filter { year == nil || cal.component(.year, from: refDate($0)) == year }
            .filter { month == nil || cal.component(.month, from: refDate($0)) == month }
            .filter {
                term.isEmpty
                    || $0.fileName.lowercased().contains(term)
                    || ($0.bank?.name.lowercased().contains(term) ?? false)
                    || ($0.account?.name.lowercased().contains(term) ?? false)
            }
            .sorted { refDate($0) > refDate($1) }
    }

    private var filterOptions: [FilterOption<DocumentFilter>] {
        DocumentFilter.allCases.map { option in
            FilterOption(value: option, title: option.title, count: documents.filter { option.matches($0.status) }.count)
        }
    }

    private var hasActiveFilters: Bool {
        filter != .all || bankID != nil || accountID != nil || year != nil || month != nil || !search.isEmpty
    }

    var body: some View {
        PageScaffold { _ in
            PageHeader("Dokumente", subtitle: "\(documents.count.formatted()) Dokumente insgesamt") {
                HStack(spacing: AppSpacing.md) {
                    RecheckBanksMenu(banks: banks.filter(\.isActive))
                    PrimaryButton(title: "Manueller Import", systemImage: "square.and.arrow.down", isLoading: env.sync.isScanning) {
                        Task { await env.sync.syncNow() }
                    }
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    SearchField(text: $search, prompt: "Dokument, Bank oder Konto suchen")
                        .frame(maxWidth: 360)
                    Spacer(minLength: 0)
                    if hasActiveFilters {
                        SecondaryButton(title: "Filter zurücksetzen", systemImage: "xmark.circle") { resetFilters() }
                    }
                }
                FilterBar(options: filterOptions, selection: $filter)
                HStack(spacing: AppSpacing.md) {
                    pickerMenu("Bank", selection: $bankID, items: banks.map { ($0.id, $0.name) })
                    pickerMenu("Konto", selection: $accountID, items: accounts.map { ($0.id, $0.name) })
                    pickerMenu("Jahr", selection: $year, items: years.map { ($0, String($0)) })
                    pickerMenu("Monat", selection: $month, items: (1...12).map { ($0, DateFormat.monthOnly.monthSymbols[$0 - 1]) })
                    Spacer(minLength: 0)
                }
            }

            tableSection
        }
    }

    private func resetFilters() {
        search = ""
        filter = .all
        bankID = nil
        accountID = nil
        year = nil
        month = nil
    }

    private func pickerMenu<V: Hashable>(_ title: String, selection: Binding<V?>, items: [(V, String)]) -> some View {
        Picker(title, selection: selection) {
            Text("\(title): alle").tag(V?.none)
            ForEach(items, id: \.0) { item in
                Text(item.1).tag(V?.some(item.0))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 150)
        .accessibilityLabel("Filter \(title)")
    }

    @ViewBuilder
    private var tableSection: some View {
        if documents.isEmpty {
            if env.sync.isScanning {
                LoadingIndicator(text: "Ordner wird durchsucht …").flatPanel()
            } else {
                EmptyStateView(
                    systemImage: "doc.text.magnifyingglass",
                    title: "Noch keine Dokumente",
                    message: env.settings.folderBookmark == nil
                        ? "Wähle in den Einstellungen den Statements-Ordner von MoneyMoney aus."
                        : "Im gewählten Ordner wurden bisher keine PDFs gefunden.",
                    actionTitle: env.settings.folderBookmark == nil ? "Einstellungen öffnen" : "Ordner abgleichen"
                ) {
                    if env.settings.folderBookmark == nil {
                        env.navigate(to: .settings)
                    } else {
                        Task { await env.sync.scanFolder() }
                    }
                }
                .flatPanel()
            }
        } else if filtered.isEmpty {
            EmptyStateView(
                systemImage: "line.3.horizontal.decrease.circle",
                title: "Keine Treffer",
                message: "Für die aktuelle Auswahl gibt es keine Dokumente.",
                actionTitle: "Filter zurücksetzen",
                action: resetFilters
            )
            .flatPanel()
        } else {
            ViewThatFits(in: .horizontal) {
                table.frame(minWidth: DocumentColumns.minTableWidth)
                ScrollView(.horizontal) {
                    table.frame(width: DocumentColumns.minTableWidth)
                }
            }
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            DocumentTableHeader()
            Divider().overlay(AppColors.divider)
            LazyVStack(spacing: 0) {
                ForEach(filtered) { doc in
                    DocumentRow(document: doc) { env.open(doc) }
                    if doc.id != filtered.last?.id { Divider().overlay(AppColors.divider).padding(.leading, AppSpacing.lg) }
                }
            }
        }
        .flatPanel()
    }
}

/// Prüft alle PDFs erneut und weist die passende Bank zu – für alle Banken oder nur für eine gewählte.
struct RecheckBanksMenu: View {
    @Environment(AppEnvironment.self) private var env
    let banks: [Bank]
    @State private var result: String?

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if let result {
                Text(result).font(AppFont.caption).foregroundStyle(AppColors.textMuted)
            }
            Menu {
                Button("Alle Banken prüfen") { run(nil) }
                if !banks.isEmpty {
                    Divider()
                    ForEach(banks) { bank in
                        Button("Nur \(bank.name) zuweisen") { run(bank) }
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if env.sync.isRechecking {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.triangle.branch")
                    }
                    Text("Banken zuordnen")
                }
            }
            .menuStyle(.button)
            .fixedSize()
            .disabled(env.settings.folderBookmark == nil || env.sync.isRechecking)
            .help("Liest alle PDFs erneut und weist die passende Bank zu. Es wird nichts erneut hochgeladen.")
            .accessibilityLabel("Banken zuordnen")
        }
    }

    private func run(_ bank: Bank?) {
        result = nil
        Task {
            let count = await env.sync.recheckAll(bank: bank)
            result = count == 0 ? "Keine Änderungen" : "\(count) PDFs zugeordnet"
        }
    }
}
