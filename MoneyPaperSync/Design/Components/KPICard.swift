import SwiftUI

struct KPICard: View {
    let title: String
    let value: String
    let systemImage: String
    var color: Color = AppColors.accent
    var subtitle: String?
    var trend: String?

    var body: some View {
        GlassCard(hoverHighlight: true) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                            .fill(color.opacity(0.16))
                            .frame(width: 32, height: 32)
                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(color)
                    }
                    .accessibilityHidden(true)
                    Spacer()
                    if let trend {
                        Text(trend)
                            .font(AppFont.captionMedium)
                            .foregroundStyle(AppColors.textMuted)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.glassFill))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(AppFont.kpiValue)
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                        .appAnimation(value: value)
                    Text(title)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)" + (subtitle.map { ", \($0)" } ?? ""))
    }
}
