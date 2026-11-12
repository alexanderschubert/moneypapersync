import SwiftUI
import SwiftData

struct BanksView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Query(sort: \Bank.name) private var banks: [Bank]
    @Query private var documents: [StatementDocument]

    @State private var editorTarget: BankEditorTarget?

    private var unknownDocs: [StatementDocument] {
        documents.filter { $0.bank == nil && $0.status == .needsReview }
    }

    /// Gängige deutsche Banken als Startpunkt – nur auf ausdrücklichen Wunsch, nie automatisch.
    private static let presets: [(String, [String])] = [
        ("ING", ["ING-DiBa", "ING Bank", "ING.de"]),
        ("DKB", ["Deutsche Kreditbank", "dkb.de"]),
        ("Sparkasse", ["Sparkasse", "Finanzgruppe"]),
        ("Commerzbank", ["Commerzbank"]),
        ("Deutsche Bank", ["Deutsche Bank"]),
        ("Volksbank Raiffeisenbank", ["Volksbank", "Raiffeisenbank", "VR Bank"]),
        ("Postbank", ["Postbank"]),
        ("comdirect", ["comdirect"]),
        ("Consorsbank", ["Consorsbank"]),
        ("N26", ["N26 Bank"]),
        ("HypoVereinsbank", ["HypoVereinsbank", "UniCredit"]),
        ("Trade Republic", ["Trade Republic"])
    ]

    var body: some View {
        PageScaffold { _ in
            PageHeader("Banken", subtitle: "Erkennungsregeln für Kontoauszüge") {
                HStack(spacing: AppSpacing.md) {
                    ReassignButton()
                    SecondaryButton(title: "Standardbanken hinzufügen", systemImage: "square.and.arrow.down.on.square") {
                        addPresets()
                    }
                    PrimaryButton(title: "Neue Bank", systemImage: "plus") { editorTarget = .new }
                }
            }

            if banks.isEmpty {
                EmptyStateView(
                    systemImage: "building.columns",
                    title: "Noch keine Banken",
                    message: "Lege eine Bank mit Erkennungsmerkmalen an – oder starte mit einer Auswahl gängiger Banken. Die Erkennung nutzt den PDF-Inhalt, nicht nur den Dateinamen.",
                    actionTitle: "Neue Bank"
                ) { editorTarget = .new }
                .flatPanel()
            } else {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(banks) { bank in
                        BankRow(bank: bank) { editorTarget = .edit(bank) }
                    }
                }
            }

            if !unknownDocs.isEmpty {
                GlassPanel("Nicht erkannte Dokumente", systemImage: "questionmark.folder",
                           subtitle: "\(unknownDocs.count) PDFs ohne erkannte Bank") {
                    VStack(spacing: 0) {
                        ForEach(unknownDocs) { doc in
                            HStack {
                                Text(doc.fileName)
                                    .font(AppFont.table)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                SecondaryButton(title: "Zuordnen", systemImage: "link") { env.editingDocument = doc }
                            }
                            .frame(height: 38)
                            Divider().overlay(AppColors.divider)
                        }
                    }
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            BankEditor(target: target)
        }
    }

    private func addPresets() {
        let existing = Set(banks.map { $0.name.lowercased() })
        for preset in Self.presets where !existing.contains(preset.0.lowercased()) {
            context.insert(Bank(name: preset.0, keywords: preset.1))
        }
        try? context.save()
        env.log.add(.system, .info, "Standardbanken hinzugefügt.")
    }
}

enum BankEditorTarget: Identifiable {
    case new
    case edit(Bank)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let bank): bank.id.uuidString
        }
    }
}

private struct BankRow: View {
    @Bindable var bank: Bank
    var onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.lg) {
            BankAvatar(bank: bank, size: 40)
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(bank.name).font(AppFont.cardTitle).foregroundStyle(AppColors.textPrimary)
                if bank.keywords.isEmpty {
                    Text("Keine Erkennungsmerkmale – es wird nur der Bankname gesucht.")
                        .font(AppFont.secondary).foregroundStyle(AppColors.textMuted)
                } else {
                    FlowLayout(spacing: AppSpacing.xs) {
                        ForEach(bank.keywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(AppFont.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppColors.glassFill))
                                .overlay(Capsule().strokeBorder(AppColors.glassBorder))
                        }
                    }
                }
                Text(accountSummary)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: AppSpacing.sm) {
                Toggle("Aktiv", isOn: $bank.isActive)
                    .toggleStyle(.switch).labelsHidden().controlSize(.small)
                    .accessibilityLabel("Bank \(bank.name) aktiv")
                SecondaryButton(title: "Bearbeiten", systemImage: "pencil", action: onEdit)
            }
        }
        .padding(AppSpacing.lg)
        .flatPanel()
        .opacity(bank.isActive ? 1 : 0.65)
    }

    private var accountSummary: String {
        let names = bank.accounts.map(\.name)
        return names.isEmpty ? "Keine Konten zugeordnet" : "Konten: " + names.joined(separator: ", ")
    }
}

struct BankEditor: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    let target: BankEditorTarget

    @State private var name = ""
    @State private var keywordText = ""
    @State private var isActive = true
    @State private var assignedAccounts: Set<UUID> = []

    private var existing: Bank? {
        if case .edit(let bank) = target { return bank }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(existing == nil ? "Neue Bank" : "Bank bearbeiten")
                .font(AppFont.pageTitle).foregroundStyle(AppColors.textPrimary)

            Form {
                TextField("Name", text: $name)
                Toggle("Aktiv", isOn: $isActive)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Erkennungsmerkmale (ein Begriff pro Zeile)")
                        .font(AppFont.secondary).foregroundStyle(AppColors.textMuted)
                    TextEditor(text: $keywordText)
                        .font(AppFont.body)
                        .frame(height: 90)
                        .scrollContentBackground(.hidden)
                        .padding(AppSpacing.xs)
                        .background(RoundedRectangle(cornerRadius: AppRadius.small).fill(AppColors.glassFill))
                    Text("Gesucht wird im Text der ersten PDF-Seiten, z. B. Bankname, BIC oder Bankleitzahl.")
                        .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            if !accounts.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Konten dieser Bank").font(AppFont.secondary).foregroundStyle(AppColors.textMuted)
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            ForEach(accounts) { account in
                                Toggle(isOn: Binding(
                                    get: { assignedAccounts.contains(account.id) },
                                    set: { on in
                                        if on { assignedAccounts.insert(account.id) } else { assignedAccounts.remove(account.id) }
                                    }
                                )) {
                                    Text(account.name + (account.bank != nil && account.bank?.id != existing?.id ? " (\(account.bank!.name))" : ""))
                                        .font(AppFont.body)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
            }

            HStack {
                if let existing {
                    SecondaryButton(title: "Löschen", systemImage: "trash", isDestructive: true) {
                        context.delete(existing)
                        try? context.save()
                        dismiss()
                    }
                }
                Spacer()
                SecondaryButton(title: "Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                PrimaryButton(title: "Speichern", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(AppSpacing.xl)
        .frame(width: 520)
        .background(AppColors.surfaceElevated)
        .onAppear {
            guard let bank = existing else { return }
            name = bank.name
            keywordText = bank.keywords.joined(separator: "\n")
            isActive = bank.isActive
            assignedAccounts = Set(bank.accounts.map(\.id))
        }
    }

    private func save() {
        let keywords = keywordText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let bank = existing ?? Bank(name: name, keywords: keywords)
        if existing == nil { context.insert(bank) }
        bank.name = name.trimmingCharacters(in: .whitespaces)
        bank.keywords = keywords
        bank.isActive = isActive
        for account in accounts {
            if assignedAccounts.contains(account.id) {
                account.bank = bank
            } else if account.bank?.id == bank.id {
                account.bank = nil
            }
        }
        try? context.save()
        // Neue Merkmale sofort auf bereits geladene PDFs anwenden.
        if bank.isActive, env.settings.folderBookmark != nil {
            Task { _ = await env.sync.recheckAll(bank: bank) }
        }
        dismiss()
    }
}
