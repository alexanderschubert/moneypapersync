import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var detailAccount: Account?
    @State private var editorTarget: AccountEditorTarget?

    var body: some View {
        PageScaffold { layout in
            PageHeader("Konten", subtitle: "\(accounts.count) Konten · \(accounts.filter(\.isActive).count) aktiv") {
                HStack(spacing: AppSpacing.md) {
                    ReassignButton()
                    PrimaryButton(title: "Konto hinzufügen", systemImage: "plus") {
                        editorTarget = .new
                    }
                }
            }

            if accounts.isEmpty {
                EmptyStateView(
                    systemImage: "person.crop.rectangle.stack",
                    title: "Noch keine Konten",
                    message: "Konten werden beim Import automatisch erkannt, sobald eine Bank und eine IBAN im PDF gefunden werden. Du kannst sie auch manuell anlegen.",
                    actionTitle: "Konto hinzufügen"
                ) { editorTarget = .new }
                .flatPanel()
            } else {
                let columns = Array(
                    repeating: GridItem(.flexible(), spacing: AppSpacing.lg, alignment: .top),
                    count: layout == .large ? 3 : (layout == .medium ? 2 : 1)
                )
                LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
                    ForEach(accounts) { account in
                        AccountCard(account: account) { detailAccount = account }
                    }
                }
            }
        }
        .sheet(item: $detailAccount) { account in
            AccountDetailView(account: account) {
                detailAccount = nil
                editorTarget = .edit(account)
            }
        }
        .sheet(item: $editorTarget) { target in
            AccountEditor(target: target)
        }
    }
}

enum AccountEditorTarget: Identifiable {
    case new
    case edit(Account)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let account): account.id.uuidString
        }
    }
}

// MARK: - Detail

struct AccountDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let account: Account
    var onEdit: () -> Void

    private var history: [StatementDocument] {
        account.documents.sorted { ($0.referenceDate ?? $0.detectedAt) > ($1.referenceDate ?? $1.detectedAt) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.md) {
                BankAvatar(bank: account.bank, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name).font(AppFont.pageTitle).foregroundStyle(AppColors.textPrimary)
                    Text(account.bank?.name ?? "Keine Bank").font(AppFont.secondary).foregroundStyle(AppColors.textMuted)
                }
                Spacer()
                SecondaryButton(title: "Bearbeiten", systemImage: "pencil", action: onEdit)
                SecondaryButton(title: "Schließen") { dismiss() }.keyboardShortcut(.cancelAction)
            }

            GlassPanel("Kontoinformationen", systemImage: "info.circle") {
                Grid(alignment: .leading, horizontalSpacing: AppSpacing.xl, verticalSpacing: AppSpacing.sm) {
                    infoRow("Kontoart", account.type.title)
                    if account.type.usesIBAN, !env.settings.hideIBANs { infoRow("IBAN", account.ibanMasked.isEmpty ? "–" : account.ibanMasked) }
                    if let label = account.type.referenceLabel { infoRow(label, account.referenceMasked.isEmpty ? "–" : account.referenceMasked) }
                    infoRow("Importierte Dokumente", "\(account.importedCount)")
                    infoRow("Paperless-Korrespondent", account.paperlessCorrespondentName ?? "–")
                    infoRow("Zugeordnete Tags", account.tagNames.isEmpty ? "–" : account.tagNames.joined(separator: ", "))
                    infoRow("Dokumenttitel-Vorlage", account.titleTemplate.isEmpty ? "Standard (\(env.settings.titleTemplate))" : account.titleTemplate)
                    infoRow("Status", account.isActive ? "Aktiv" : "Deaktiviert")
                }
            }

            GlassPanel("Importhistorie", systemImage: "clock.arrow.circlepath") {
                if history.isEmpty {
                    EmptyStateView(systemImage: "tray", title: "Noch keine Dokumente", message: "Diesem Konto wurden noch keine PDFs zugeordnet.", compact: true)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(history) { doc in
                                HStack(spacing: AppSpacing.md) {
                                    StatusGlyph(status: doc.status)
                                    Text(doc.fileName).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Text(doc.periodText).font(AppFont.tableNumber).foregroundStyle(AppColors.textMuted)
                                }
                                .font(AppFont.table)
                                .foregroundStyle(AppColors.textPrimary)
                                .frame(height: 32)
                                Divider().overlay(AppColors.divider)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
        .padding(AppSpacing.xl)
        .frame(width: 640)
        .background(AppColors.surfaceElevated)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).font(AppFont.secondary).foregroundStyle(AppColors.textMuted)
            Text(value).font(AppFont.body).foregroundStyle(AppColors.textPrimary).textSelection(.enabled)
        }
    }
}

// MARK: - Editor

struct AccountEditor: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Bank.name) private var banks: [Bank]

    let target: AccountEditorTarget

    @State private var name = ""
    @State private var bankID: UUID?
    @State private var type: AccountType = .checking
    @State private var ibanInput = ""
    @State private var referenceInput = ""
    @State private var isActive = true
    @State private var correspondentID: Int?
    @State private var tagIDs: Set<Int> = []
    @State private var titleTemplate = ""
    @State private var ibanError: String?
    @State private var referenceError: String?

    private var existing: Account? {
        if case .edit(let account) = target { return account }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(existing == nil ? "Konto hinzufügen" : "Konto bearbeiten")
                .font(AppFont.pageTitle).foregroundStyle(AppColors.textPrimary)

            Form {
                TextField("Kontoname", text: $name)
                Picker("Bank", selection: $bankID) {
                    Text("Keine").tag(UUID?.none)
                    ForEach(banks) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Picker("Kontoart", selection: $type) {
                    ForEach(AccountType.allCases) { Text($0.title).tag($0) }
                }
                if let label = type.referenceLabel {
                    VStack(alignment: .leading, spacing: 2) {
                        TextField(label, text: $referenceInput, prompt: Text(existing?.referenceMasked.isEmpty == false ? "Gespeichert: \(existing!.referenceMasked)" : (type == .creditCard ? "z. B. 3782 822463 10005" : "z. B. 1234567")))
                        Text("Wird nur mit den letzten vier Stellen gespeichert und sucht diese Kennung im PDF, um Auszüge diesem Konto zuzuordnen.")
                            .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
                        if let referenceError { Text(referenceError).font(AppFont.caption).foregroundStyle(AppColors.error) }
                    }
                }
                if type.usesIBAN {
                VStack(alignment: .leading, spacing: 2) {
                    TextField("IBAN", text: $ibanInput, prompt: Text(existing?.ibanMasked.isEmpty == false ? "Gespeichert: \(existing!.ibanMasked)" : "DE00 0000 0000 0000 0000 00"))
                    Text("Die IBAN wird nur maskiert gespeichert und zur Kontozuordnung verwendet.")
                        .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
                    if let ibanError { Text(ibanError).font(AppFont.caption).foregroundStyle(AppColors.error) }
                }
                }
                Picker("Paperless-Korrespondent", selection: $correspondentID) {
                    Text("Standard / keiner").tag(Int?.none)
                    ForEach(env.sync.metadata.correspondents) { Text($0.name).tag(Int?.some($0.id)) }
                }
                TextField("Dokumenttitel-Vorlage", text: $titleTemplate, prompt: Text(env.settings.titleTemplate))
                Toggle("Konto aktiv", isOn: $isActive)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            if !env.sync.metadata.tags.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Tags").font(AppFont.secondary).foregroundStyle(AppColors.textMuted)
                    TagSelector(tags: env.sync.metadata.tags, selection: $tagIDs)
                }
            }
            if env.sync.metadata.isEmpty {
                HStack {
                    Text(env.sync.metadataError ?? "Korrespondenten und Tags werden von Paperless-ngx geladen.")
                        .font(AppFont.caption).foregroundStyle(AppColors.textMuted)
                    Spacer()
                    SecondaryButton(title: "Neu laden", systemImage: "arrow.clockwise", isLoading: env.sync.isLoadingMetadata) {
                        Task { await env.sync.refreshMetadata() }
                    }
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
                PrimaryButton(title: "Speichern") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(AppSpacing.xl)
        .frame(width: 540)
        .background(AppColors.surfaceElevated)
        .task {
            if env.sync.metadata.isEmpty { await env.sync.refreshMetadata() }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let account = existing else { return }
        name = account.name
        bankID = account.bank?.id
        type = account.type
        isActive = account.isActive
        correspondentID = account.paperlessCorrespondentID
        tagIDs = Set(account.tagIDs)
        titleTemplate = account.titleTemplate
    }

    private func save() {
        var masked: String?
        var referenceMasked: String?
        let referenceText = referenceInput.trimmingCharacters(in: .whitespaces)
        if type.referenceLabel != nil, !referenceText.isEmpty {
            let valid = type == .creditCard ? ReferenceTools.isValidCardNumber(referenceText) : ReferenceTools.digits(referenceText).count >= 4
            guard valid else {
                referenceError = type == .creditCard ? "Ungültige Kartennummer (Prüfziffer stimmt nicht)." : "Mindestens vier Ziffern eingeben."
                return
            }
            referenceMasked = ReferenceTools.mask(referenceText)
        }
        let trimmed = type.usesIBAN ? ibanInput.trimmingCharacters(in: .whitespaces) : ""
        if !trimmed.isEmpty {
            guard IBANTools.isValid(trimmed) else {
                ibanError = "Ungültige IBAN (Prüfsumme stimmt nicht)."
                return
            }
            masked = IBANTools.mask(trimmed)
        }
        let bank = banks.first { $0.id == bankID }
        let correspondent = env.sync.metadata.correspondents.first { $0.id == correspondentID }
        let tags = env.sync.metadata.tags.filter { tagIDs.contains($0.id) }

        let account = existing ?? Account(name: name, type: type)
        if existing == nil { context.insert(account) }
        account.name = name.trimmingCharacters(in: .whitespaces)
        account.bank = bank
        account.type = type
        account.isActive = isActive
        if let masked { account.ibanMasked = masked }
        if let referenceMasked { account.referenceMasked = referenceMasked }
        account.paperlessCorrespondentID = correspondentID
        account.paperlessCorrespondentName = correspondent?.name ?? (correspondentID == nil ? nil : account.paperlessCorrespondentName)
        account.tagIDs = tags.isEmpty && !tagIDs.isEmpty ? Array(tagIDs) : tags.map(\.id)
        account.tagNames = tags.map(\.name)
        account.titleTemplate = titleTemplate.trimmingCharacters(in: .whitespaces)
        try? context.save()
        // Bereits erkannte, aber nicht zugeordnete PDFs mit der neuen Kennung erneut prüfen.
        Task { await env.sync.reassignUnassigned() }
        dismiss()
    }
}

/// Prüft PDFs ohne Bank/Konto anhand von Bank-Merkmalen und Kontokennungen erneut.
struct ReassignButton: View {
    @Environment(AppEnvironment.self) private var env
    @State private var isRunning = false
    @State private var result: String?

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if let result {
                Text(result).font(AppFont.caption).foregroundStyle(AppColors.textMuted)
            }
            SecondaryButton(title: "PDFs neu zuordnen", systemImage: "arrow.triangle.branch", isLoading: isRunning) {
                isRunning = true
                Task {
                    let count = await env.sync.reassignUnassigned()
                    result = count == 0 ? "Nichts zu ändern" : "\(count) PDFs geprüft"
                    isRunning = false
                }
            }
            .disabled(env.settings.folderBookmark == nil)
            .help("Liest PDFs ohne Bank oder Konto erneut und ordnet sie über Bankmerkmale, IBAN, Karten- und Sparbuchnummern zu.")
        }
    }
}

/// Mehrfachauswahl für Paperless-Tags.
struct TagSelector: View {
    let tags: [PaperlessItem]
    @Binding var selection: Set<Int>

    var body: some View {
        ScrollView {
            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(tags) { tag in
                    let selected = selection.contains(tag.id)
                    Button {
                        if selected { selection.remove(tag.id) } else { selection.insert(tag.id) }
                    } label: {
                        HStack(spacing: 4) {
                            if selected { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)) }
                            Text(tag.name)
                        }
                        .font(AppFont.secondary)
                        .foregroundStyle(selected ? AppColors.textPrimary : AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.md)
                        .frame(height: 26)
                        .background(Capsule().fill(selected ? AppColors.accent.opacity(0.22) : AppColors.glassFill))
                        .overlay(Capsule().strokeBorder(selected ? AppColors.accent.opacity(0.5) : AppColors.glassBorder))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .frame(maxHeight: 96)
    }
}

/// Einfaches Umbruch-Layout für Chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
