import SwiftUI

/// Spaltenbreiten der Dokumenttabelle (Header und Zeilen teilen sich diese Werte).
enum DocumentColumns {
    static let status: CGFloat = 36
    static let bank: CGFloat = 130
    static let account: CGFloat = 150
    static let period: CGFloat = 130
    static let minTableWidth: CGFloat = 820
}

struct DocumentTableHeader: View {
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text("Status").frame(width: DocumentColumns.status, alignment: .leading)
            Text("Dokument").frame(maxWidth: .infinity, alignment: .leading)
            Text("Bank").frame(width: DocumentColumns.bank, alignment: .leading)
            Text("Konto").frame(width: DocumentColumns.account, alignment: .leading)
            Text("Zeitraum").frame(width: DocumentColumns.period, alignment: .leading)
        }
        .font(AppFont.sectionLabel)
        .foregroundStyle(AppColors.textMuted)
        .textCase(.uppercase)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .accessibilityHidden(true)
    }
}

struct DocumentRow: View {
    let document: StatementDocument
    var onSelect: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppSpacing.md) {
                StatusGlyph(status: document.status)
                    .frame(width: DocumentColumns.status, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text(document.fileName)
                        .font(AppFont.table)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if document.status == .failed || document.status == .needsReview,
                       let error = document.lastError {
                        Text(error)
                            .font(AppFont.caption)
                            .foregroundStyle(document.status.color)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(document.bank?.name ?? "–")
                    .frame(width: DocumentColumns.bank, alignment: .leading)
                Text(document.account?.name ?? "–")
                    .frame(width: DocumentColumns.account, alignment: .leading)
                Text(document.periodText)
                    .font(AppFont.tableNumber)
                    .frame(width: DocumentColumns.period, alignment: .leading)
            }
            .font(AppFont.table)
            .foregroundStyle(AppColors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, AppSpacing.lg)
            .frame(height: 40)
            .background(hovering ? AppColors.glassFill : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .appAnimation(AppMotion.hover, value: hovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Öffnet die Dokumentdetails")
    }

    private var accessibilitySummary: String {
        [
            document.fileName,
            document.status.title,
            document.bank?.name,
            document.account?.name,
            document.periodText
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}
