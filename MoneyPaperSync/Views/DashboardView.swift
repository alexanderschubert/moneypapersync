import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var env
    @Query private var documents: [StatementDocument]
    @Query private var accounts: [Account]

    private var imported: [StatementDocument] { documents.filter { $0.status == .imported } }
    private var waiting: Int { documents.filter { DocumentFilter.waiting.matches($0.status) }.count }
    private var failed: Int { documents.filter { $0.status == .failed }.count }
    private var review: Int { documents.filter { $0.status == .needsReview }.count }
    private var activeAccounts: Int { accounts.filter(\.isActive).count }

    private var importedThisMonth: Int {
        imported.filter {
            guard let date = $0.importedAt else { return false }
            return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
        }.count
    }

    private var recent: [StatementDocument] {
        imported.sorted { ($0.importedAt ?? .distantPast) > ($1.importedAt ?? .distantPast) }.prefix(5).map { $0 }
    }

    private var lastImportText: String {
        guard let date = imported.compactMap(\.importedAt).max() else { return "Noch kein Import" }
        if Calendar.current.isDateInToday(date) { return "Letzter Import \(DateFormat.time.string(from: date))" }
        return "Letzter Import \(DateFormat.short.string(from: date))"
    }

    var body: some View {
        PageScaffold { layout in
            PageHeader("Dashboard", subtitle: "Übersicht deiner Dokumentensynchronisation", isDashboard: true) {
                HStack(spacing: AppSpacing.md) {
                    HStack(spacing: AppSpacing.sm) {
                        StatusDot(color: syncColor, pulsing: env.sync.activeCount > 0)
                        Text(lastImportText)
                            .font(AppFont.secondary)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .frame(height: 30)
                    .glassCard(radius: AppRadius.small, shadow: false)
                    PrimaryButton(title: "Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath", isLoading: env.sync.isScanning) {
                        Task { await env.sync.syncNow() }
                    }
                }
            }

            kpiGrid(layout)
            twoColumns(layout) { systemStatus } right: { recentImports }
            twoColumns(layout) { statisticsChart } right: { bankDistribution }
        }
    }

    private var syncColor: Color {
        ConnectionState(kind: env.sync.summary.color, title: "", detail: nil).color
    }

    // MARK: KPIs

    private func kpiGrid(_ layout: LayoutClass) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.lg), count: layout.kpiColumns)
        return LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
            KPICard(
                title: "Importierte Dokumente",
                value: imported.count.formatted(),
                systemImage: "doc.text.fill",
                color: AppColors.accent,
                subtitle: nil,
                trend: importedThisMonth > 0 ? "+\(importedThisMonth) diesen Monat" : nil
            )
            KPICard(
                title: "Wartende Dokumente",
                value: waiting.formatted(),
                systemImage: "clock.fill",
                color: AppColors.accentCyan,
                subtitle: review > 0 ? "\(review) zur manuellen Prüfung" : nil
            )
            KPICard(
                title: "Fehlerhafte Dokumente",
                value: failed.formatted(),
                systemImage: "exclamationmark.triangle.fill",
                color: failed > 0 ? AppColors.error : AppColors.neutral
            )
            KPICard(
                title: "Erkannte Konten",
                value: activeAccounts.formatted(),
                systemImage: "person.crop.rectangle.stack.fill",
                color: AppColors.violet,
                subtitle: accounts.count > activeAccounts ? "\(accounts.count - activeAccounts) deaktiviert" : nil
            )
        }
    }

    @ViewBuilder
    private func twoColumns<L: View, R: View>(_ layout: LayoutClass, @ViewBuilder left: () -> L, @ViewBuilder right: () -> R) -> some View {
        if layout == .large {
            HStack(alignment: .top, spacing: AppSpacing.lg) {
                left().frame(maxWidth: .infinity)
                right().frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: AppSpacing.lg) {
                left()
                right()
            }
        }
    }

    // MARK: Systemstatus

    private var systemStatus: some View {
        GlassPanel("Systemstatus", systemImage: "antenna.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ConnectionIndicator(name: "MoneyMoney", state: env.sync.moneyMoneyState)
                Divider().overlay(AppColors.divider)
                ConnectionIndicator(name: "Paperless-ngx", state: env.sync.paperlessState)
                if !env.sync.moneyMoneyState.isOK || !env.sync.paperlessState.isOK {
                    SecondaryButton(title: "Einstellungen öffnen", systemImage: "gearshape") {
                        env.navigate(to: .settings)
                    }
                }
            }
        }
    }

    // MARK: Letzte Importe

    private var recentImports: some View {
        GlassPanel("Letzte Importe", systemImage: "tray.and.arrow.down") {
            if recent.isEmpty {
                EmptyStateView(
                    systemImage: "tray",
                    title: "Noch keine Importe",
                    message: "Sobald ein Kontoauszug in Paperless-ngx archiviert wurde, erscheint er hier.",
                    compact: true
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(recent) { doc in
                        Button {
                            env.open(doc)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Text(doc.bank?.name ?? "–")
                                    .frame(width: 90, alignment: .leading)
                                    .foregroundStyle(AppColors.textSecondary)
                                Text(doc.fileName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .truncationMode(.middle)
                                Text(doc.importedAt.map { DateFormat.short.string(from: $0) } ?? "–")
                                    .font(AppFont.tableNumber)
                                    .foregroundStyle(AppColors.textMuted)
                                StatusGlyph(status: doc.status)
                            }
                            .font(AppFont.table)
                            .lineLimit(1)
                            .frame(height: 34)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(doc.fileName), \(doc.bank?.name ?? "ohne Bank"), \(doc.status.title)")
                        if doc.id != recent.last?.id { Divider().overlay(AppColors.divider) }
                    }
                }
            }
        }
    }

    // MARK: Diagramme

    private struct MonthBucket: Identifiable {
        let month: Date
        let count: Int
        var id: Date { month }
    }

    private var monthBuckets: [MonthBucket] {
        let cal = Calendar.current
        guard let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) else { return [] }
        return (0..<12).reversed().compactMap { offset in
            guard let month = cal.date(byAdding: .month, value: -offset, to: thisMonth) else { return nil }
            let count = imported.filter {
                guard let date = $0.importedAt else { return false }
                return cal.isDate(date, equalTo: month, toGranularity: .month)
            }.count
            return MonthBucket(month: month, count: count)
        }
    }

    private var statisticsChart: some View {
        let buckets = monthBuckets
        return GlassPanel("Importstatistik", systemImage: "chart.bar.fill", subtitle: "Letzte 12 Monate") {
            if buckets.allSatisfy({ $0.count == 0 }) {
                EmptyStateView(
                    systemImage: "chart.bar",
                    title: "Keine Daten",
                    message: "Die Statistik erscheint nach den ersten erfolgreichen Importen.",
                    compact: true
                )
                .frame(height: 180)
            } else {
                Chart(buckets) { bucket in
                    BarMark(
                        x: .value("Monat", bucket.month, unit: .month),
                        y: .value("Dokumente", bucket.count)
                    )
                    .foregroundStyle(AppColors.accent)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(AppColors.divider)
                        AxisValueLabel().foregroundStyle(AppColors.textMuted)
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("Balkendiagramm der Importe pro Monat")
                .accessibilityValue(buckets.map { "\(DateFormat.monthShortYear.string(from: $0.month)): \($0.count)" }.joined(separator: ", "))
            }
        }
    }

    private struct BankSlice: Identifiable {
        let name: String
        let count: Int
        let color: Color
        var id: String { name }
    }

    private var bankSlices: [BankSlice] {
        let grouped = Dictionary(grouping: imported, by: { $0.bank?.name ?? "Ohne Bank" })
        let sorted = grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
        let palette = AppColors.chartSeries
        return sorted.enumerated().map { index, entry in
            BankSlice(name: entry.0, count: entry.1, color: palette[min(index, palette.count - 1)])
        }
    }

    private var bankDistribution: some View {
        let slices = bankSlices
        return GlassPanel("Verteilung nach Banken", systemImage: "chart.pie.fill") {
            if slices.isEmpty {
                EmptyStateView(
                    systemImage: "chart.pie",
                    title: "Keine Daten",
                    message: "Sobald Dokumente importiert wurden, siehst du hier die Verteilung.",
                    compact: true
                )
                .frame(height: 180)
            } else {
                HStack(spacing: AppSpacing.xl) {
                    Chart(slices) { slice in
                        SectorMark(
                            angle: .value("Dokumente", slice.count),
                            innerRadius: .ratio(0.62),
                            angularInset: 1.5
                        )
                        .foregroundStyle(slice.color)
                        .cornerRadius(3)
                    }
                    .frame(width: 170, height: 170)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        ForEach(slices) { slice in
                            HStack(spacing: AppSpacing.sm) {
                                Circle().fill(slice.color).frame(width: 8, height: 8)
                                Text(slice.name)
                                    .font(AppFont.secondary)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: AppSpacing.sm)
                                Text(slice.count.formatted())
                                    .font(AppFont.tableNumber)
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Verteilung nach Banken")
                .accessibilityValue(slices.map { "\($0.name): \($0.count)" }.joined(separator: ", "))
            }
        }
    }
}
