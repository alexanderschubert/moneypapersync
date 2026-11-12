import SwiftUI

/// Eintrag der Sidebar (voll oder kompakt).
struct NavigationItem: View {
    let item: SidebarItem
    let isSelected: Bool
    var badge: Int?
    var badgeColor: Color = AppColors.accent
    var compact = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: item.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? AppColors.accentLight : AppColors.textSecondary)
                    .accessibilityHidden(true)
                if !compact {
                    Text(item.title)
                        .font(isSelected ? AppFont.bodyMedium : AppFont.body)
                        .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let badge, badge > 0 {
                        BadgeCount(value: badge, color: badgeColor)
                    }
                }
            }
            .padding(.horizontal, compact ? 0 : AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
            .frame(height: 34)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(isSelected ? AppColors.accent.opacity(0.18) : (hovering ? AppColors.glassFill : .clear))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                .strokeBorder(AppColors.accent.opacity(0.35), lineWidth: 1)
                        }
                    }
            }
            .overlay(alignment: .topTrailing) {
                if compact, let badge, badge > 0 {
                    Circle().fill(badgeColor).frame(width: 8, height: 8).offset(x: -6, y: 5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .appAnimation(AppMotion.navigation, value: isSelected)
        .appAnimation(AppMotion.hover, value: hovering)
        .help(item.title)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var accessibilityText: String {
        if let badge, badge > 0 { return "\(item.title), \(badge)" }
        return item.title
    }
}

struct BadgeCount: View {
    let value: Int
    var color: Color = AppColors.accent

    var body: some View {
        Text(value > 999 ? "999+" : "\(value)")
            .font(AppFont.captionMedium.monospacedDigit())
            .foregroundStyle(color == AppColors.accent ? AppColors.accentLight : color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.18)))
    }
}
