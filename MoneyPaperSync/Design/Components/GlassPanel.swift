import SwiftUI

/// Karte mit Titelzeile (Titel, optionales Icon, optionale Aktionen rechts).
struct GlassPanel<Content: View, Trailing: View>: View {
    let title: String
    var systemImage: String?
    var subtitle: String?
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

    init(
        _ title: String,
        systemImage: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(AppFont.cardTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        if let subtitle {
                            Text(subtitle)
                                .font(AppFont.caption)
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                    Spacer(minLength: AppSpacing.sm)
                    trailing
                }
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

extension GlassPanel where Trailing == EmptyView {
    init(
        _ title: String,
        systemImage: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title, systemImage: systemImage, subtitle: subtitle, trailing: { EmptyView() }, content: content)
    }
}

/// Seitenkopf: Titel, Untertitel und Aktionen.
struct PageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var isDashboard = false
    @ViewBuilder let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        isDashboard: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isDashboard = isDashboard
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(isDashboard ? AppFont.dashboardTitle : AppFont.pageTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.body)
                        .foregroundStyle(AppColors.textMuted)
                }
            }
            Spacer(minLength: AppSpacing.lg)
            trailing
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, isDashboard: Bool = false) {
        self.init(title, subtitle: subtitle, isDashboard: isDashboard, trailing: { EmptyView() })
    }
}
