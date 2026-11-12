import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if env.settings.onboardingCompleted {
                MainView()
            } else {
                OnboardingView()
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .preferredColorScheme(env.settings.appearance.colorScheme)
        .tint(AppColors.accent)
    }
}

struct MainView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var env = env
        HStack(spacing: 0) {
            SidebarView()
            Divider().overlay(AppColors.divider)
            ZStack {
                AppColors.background
                content
                    .id(env.selection)
                    .transition(.opacity)
            }
            .appAnimation(AppMotion.navigation, value: env.selection)
        }
        .ignoresSafeArea(.container, edges: .top)
        .sheet(item: $env.detailDocument) { document in
            DocumentDetailView(document: document)
        }
        .sheet(item: $env.editingDocument) { document in
            DetectionEditSheet(document: document)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch env.selection {
        case .dashboard: DashboardView()
        case .documents: DocumentsView()
        case .queue: QueueView()
        case .accounts: AccountsView()
        case .banks: BanksView()
        case .log: LogView()
        case .settings: SettingsView()
        }
    }
}

/// Gemeinsamer Rahmen für Ansichten: Scrollbereich mit einheitlichem Padding und Breitenmessung.
struct PageScaffold<Content: View>: View {
    @ViewBuilder let content: (LayoutClass) -> Content

    var body: some View {
        GeometryReader { geo in
            let layout = LayoutClass(contentWidth: geo.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    content(layout)
                }
                .padding(AppLayout.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
