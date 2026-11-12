import SwiftUI

/// Initialen-Platzhalter für Banken (kein Fremdlogo).
struct BankAvatar: View {
    let bank: Bank?
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(AppColors.accent.opacity(0.16))
            Text(bank?.initials ?? "?")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(AppColors.accentLight)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct AccountCard: View {
    @Environment(AppEnvironment.self) private var env
    @Bindable var account: Account
    var onOpen: () -> Void

    var body: some View {
        GlassCard(hoverHighlight: true) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    BankAvatar(bank: account.bank)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(account.bank?.name ?? "Keine Bank")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.textMuted)
                        Text(account.name)
                            .font(AppFont.cardTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Toggle("Aktiv", isOn: $account.isActive)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                        .accessibilityLabel("Konto \(account.name) aktiv")
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    infoRow("creditcard", account.type.title)
                    if account.type.usesIBAN, !env.settings.hideIBANs, !account.ibanMasked.isEmpty {
                        infoRow("number", account.ibanMasked, mono: true)
                    }
                    if account.type.referenceLabel != nil, !account.referenceMasked.isEmpty {
                        infoRow("number", account.referenceMasked, mono: true)
                    }
                    infoRow("person.text.rectangle", account.paperlessCorrespondentName ?? "Kein Korrespondent")
                }

                Divider().overlay(AppColors.divider)

                HStack {
                    Label("\(account.importedCount) Dokumente", systemImage: "doc.text")
                        .font(AppFont.secondary.monospacedDigit())
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    if !account.isActive {
                        StatusBadge(text: "Deaktiviert", systemImage: "pause.circle", color: AppColors.neutral)
                    }
                    Button(action: onOpen) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.textMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Kontodetails öffnen")
                }
            }
        }
        .opacity(account.isActive ? 1 : 0.7)
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
    }

    private func infoRow(_ symbol: String, _ text: String, mono: Bool = false) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textMuted)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(text)
                .font(mono ? AppFont.mono : AppFont.secondary)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
    }
}
