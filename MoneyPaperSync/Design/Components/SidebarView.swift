import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(AppEnvironment.self) private var env
    @Query private var documents: [StatementDocument]

    private var compact: Bool { env.settings.sidebarCollapsed }

    private var totalCount: Int { documents.filter { $0.status == .imported }.count }
    private var queueCount: Int { documents.filter { $0.status.isInQueue }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 34) // Platz für die Fenster-Ampel
                .padding(.bottom, AppSpacing.xl)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    group("Übersicht", [.dashboard])
                    group("Dokumente", [.documents, .queue])
                    group("Verwaltung", [.accounts, .banks])
                    group("System", [.log])
                }
            }
            .scrollIndicators(.never)

            Spacer(minLength: AppSpacing.md)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                NavigationItem(item: .settings, isSelected: env.selection == .settings, compact: compact) {
                    env.navigate(to: .settings)
                }
                Divider().overlay(AppColors.divider)
                statusFooter
                collapseButton
            }
        }
        .padding(.horizontal, compact ? AppSpacing.sm : AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
        .frame(width: compact ? AppLayout.sidebarCompactWidth : AppLayout.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                AppColors.sidebarBackground
            }
            .ignoresSafeArea()
        }
        .appAnimation(AppMotion.sidebar, value: compact)
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            LogoMark(size: compact ? 36 : 32)
            if !compact { Wordmark() }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
        .padding(.horizontal, compact ? 0 : AppSpacing.md)
    }

    private func group(_ title: String, _ items: [SidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if !compact {
                Text(title)
                    .font(AppFont.sectionLabel)
                    .foregroundStyle(AppColors.textMuted)
                    .textCase(.uppercase)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, 2)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(items) { item in
                NavigationItem(
                    item: item,
                    isSelected: env.selection == item,
                    badge: badge(for: item),
                    badgeColor: item == .queue ? AppColors.warning : AppColors.accent,
                    compact: compact
                ) {
                    env.navigate(to: item)
                }
            }
        }
    }

    private func badge(for item: SidebarItem) -> Int? {
        switch item {
        case .documents: totalCount
        case .queue: queueCount
        default: nil
        }
    }

    private var statusFooter: some View {
        let summary = env.sync.summary
        let color = stateColor(summary.color)
        return HStack(spacing: AppSpacing.sm) {
            StatusDot(color: color, pulsing: summary.pulsing)
            if !compact {
                Text(summary.text)
                    .font(AppFont.secondary)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
        .padding(.horizontal, compact ? 0 : AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .help(summary.text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(summary.text)")
    }

    private func stateColor(_ kind: ConnectionState.Kind) -> Color {
        ConnectionState(kind: kind, title: "", detail: nil).color
    }

    private var collapseButton: some View {
        Button {
            env.toggleSidebar()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: compact ? "sidebar.right" : "sidebar.left")
                if !compact { Text("Einklappen").font(AppFont.secondary) }
            }
            .foregroundStyle(AppColors.textMuted)
            .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
            .padding(.horizontal, compact ? 0 : AppSpacing.md)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(compact ? "Sidebar einblenden" : "Sidebar einklappen")
        .accessibilityLabel(compact ? "Sidebar einblenden" : "Sidebar einklappen")
    }
}
