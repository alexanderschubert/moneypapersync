import SwiftUI
import SwiftData
import PDFKit

struct PDFPreview: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .clear
        view.document = document
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }
}

struct DocumentDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Bindable var document: StatementDocument

    @State private var pdf: PDFDocument?
    @State private var pdfError: String?
    @State private var showEdit = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppColors.divider)
            HStack(alignment: .top, spacing: 0) {
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider().overlay(AppColors.divider)
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        info
                        actions
                    }
                    .padding(AppSpacing.xl)
                }
                .frame(width: 340)
            }
        }
        .frame(width: 940, height: 640)
        .background(AppColors.surfaceElevated)
        .task(id: document.relativePath) { loadPDF() }
        .sheet(isPresented: $showEdit) { DetectionEditSheet(document: document) }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(document.fileName)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Dokumentdetails")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
            Spacer()
            StatusBadge(status: document.status)
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.textMuted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Schließen")
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.md)
    }

    @ViewBuilder
    private var preview: some View {
        if let pdf {
            PDFPreview(document: pdf)
        } else if let pdfError {
            ErrorStateView(title: "Vorschau nicht verfügbar", message: pdfError) { loadPDF() }
        } else {
            LoadingIndicator(text: "Vorschau wird geladen …")
        }
    }

    private func loadPDF() {
        pdfError = nil
        guard let url = env.sync.fileURL(for: document) else {
            pdfError = "Der Statements-Ordner ist nicht verfügbar."
            return
        }
        if let doc = PDFDocument(url: url) {
            pdf = doc
        } else {
            pdfError = "Die Datei konnte nicht geöffnet werden. Möglicherweise wurde sie verschoben oder gelöscht."
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            row("Originaldateiname", document.fileName)
            row("Erkannte Bank", document.bank?.name ?? "Nicht erkannt")
            row("Zugeordnetes Konto", document.account?.name ?? "Nicht zugeordnet")
            row("Dokumentdatum", document.documentDate.map { DateFormat.short.string(from: $0) } ?? "–")
            row("Zeitraum", document.periodText)
            row("SHA-256", document.sha256.isEmpty ? "–" : document.sha256, mono: true)
            row("Paperless-Dokument-ID", document.paperlessDocumentID.map(String.init) ?? "–")
            row("Importstatus", document.status.title)
            if let error = document.lastError {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Letzte Meldung").font(AppFont.caption).foregroundStyle(AppColors.textMuted)
                    Text(error)
                        .font(AppFont.secondary)
                        .foregroundStyle(document.status == .failed ? AppColors.error : AppColors.warning)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func row(_ title: String, _ value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(AppFont.caption).foregroundStyle(AppColors.textMuted)
            Text(value)
                .font(mono ? AppFont.mono : AppFont.body)
                .foregroundStyle(AppColors.textPrimary)
                .textSelection(.enabled)
                .lineLimit(mono ? 3 : 2)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SecondaryButton(title: "PDF öffnen", systemImage: "doc.richtext") { env.sync.openPDF(document) }
            SecondaryButton(title: "Erkennung bearbeiten", systemImage: "pencil") { showEdit = true }
            SecondaryButton(title: "Erneut synchronisieren", systemImage: "arrow.triangle.2.circlepath") {
                env.sync.resync(document)
            }
            .disabled(document.status.isActive)
            SecondaryButton(title: "In Paperless öffnen", systemImage: "arrow.up.right.square") {
                env.sync.openInPaperless(document)
            }
            .disabled(document.paperlessDocumentID == nil)
            if document.status == .ignored {
                SecondaryButton(title: "Nicht mehr ignorieren", systemImage: "eye") { env.sync.unignore(document) }
            } else {
                SecondaryButton(title: "Dokument ignorieren", systemImage: "eye.slash", isDestructive: true) {
                    env.sync.ignore(document)
                }
            }
            Text("Das Original-PDF wird nie verändert.")
                .font(AppFont.caption)
                .foregroundStyle(AppColors.textMuted)
                .padding(.top, AppSpacing.xs)
        }
    }
}

/// Manuelle Zuordnung von Bank, Konto und Zeitraum.
struct DetectionEditSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Bank.name) private var banks: [Bank]
    @Query(sort: \Account.name) private var accounts: [Account]

    let document: StatementDocument

    @State private var bankID: UUID?
    @State private var accountID: UUID?
    @State private var useDate = false
    @State private var periodEnd = Date()

    private var accountsForBank: [Account] {
        accounts.filter { bankID != nil && $0.bank?.id == bankID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Erkennung bearbeiten")
                .font(AppFont.pageTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text(document.fileName)
                .font(AppFont.secondary)
                .foregroundStyle(AppColors.textMuted)
                .lineLimit(1)
                .truncationMode(.middle)

            Form {
                Picker("Bank", selection: $bankID) {
                    Text("Keine").tag(UUID?.none)
                    ForEach(banks) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Picker("Konto", selection: $accountID) {
                    Text("Keines").tag(UUID?.none)
                    ForEach(accountsForBank) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                .disabled(bankID == nil)
                Toggle("Zeitraumende überschreiben", isOn: $useDate)
                if useDate {
                    DatePicker("Zeitraumende", selection: $periodEnd, displayedComponents: .date)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            if banks.isEmpty {
                Text("Es ist noch keine Bank angelegt. Lege zuerst unter „Banken“ eine Bank an.")
                    .font(AppFont.secondary)
                    .foregroundStyle(AppColors.warning)
            }

            HStack {
                Spacer()
                SecondaryButton(title: "Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                PrimaryButton(title: "Speichern und synchronisieren") {
                    let bank = banks.first { $0.id == bankID }
                    let account = accounts.first { $0.id == accountID }
                    env.sync.assign(document, bank: bank, account: account, periodEnd: useDate ? periodEnd : nil)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppSpacing.xl)
        .frame(width: 480)
        .background(AppColors.surfaceElevated)
        .onAppear {
            bankID = document.bank?.id
            accountID = document.account?.id
            if let end = document.periodEnd ?? document.documentDate { periodEnd = end }
        }
        .onChange(of: bankID) { _, newValue in
            if let account = accounts.first(where: { $0.id == accountID }), account.bank?.id != newValue {
                accountID = nil
            }
        }
    }
}
