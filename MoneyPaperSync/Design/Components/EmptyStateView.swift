import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var compact = false

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: compact ? 24 : 34, weight: .light))
                .foregroundStyle(AppColors.textMuted)
                .accessibilityHidden(true)
            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(compact ? AppFont.bodyMedium : AppFont.cardTitle)
                    .foregroundStyle(AppColors.textPrimary)
                Text(message)
                    .font(AppFont.secondary)
                    .foregroundStyle(AppColors.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? AppSpacing.lg : AppSpacing.xxl)
        .accessibilityElement(children: .combine)
    }
}

struct ErrorStateView: View {
    let title: String
    let message: String
    var retryTitle = "Erneut versuchen"
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(AppColors.warning)
                .accessibilityHidden(true)
            Text(title)
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text(message)
                .font(AppFont.secondary)
                .foregroundStyle(AppColors.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            if let retry {
                SecondaryButton(title: retryTitle, systemImage: "arrow.clockwise", action: retry)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xxl)
    }
}

struct LoadingIndicator: View {
    var text: String = "Wird geladen …"

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ProgressView().controlSize(.small)
            Text(text)
                .font(AppFont.secondary)
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
