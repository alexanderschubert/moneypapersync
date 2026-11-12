import SwiftUI

/// Verbindungsanzeige mit Punkt, Titel und optionalem Detail.
struct ConnectionIndicator: View {
    let name: String
    let state: ConnectionState
    var showsDetail = true

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            ZStack {
                Circle().fill(state.color.opacity(0.18)).frame(width: 28, height: 28)
                if state.kind == .checking {
                    ProgressView().controlSize(.small).scaleEffect(0.6)
                } else {
                    Image(systemName: state.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(state.color)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary)
                Text(state.title)
                    .font(AppFont.secondary)
                    .foregroundStyle(state.kind == .ok ? AppColors.textMuted : state.color)
                if showsDetail, let detail = state.detail {
                    Text(detail)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.textMuted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .appAnimation(value: state)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(state.title)")
    }
}

/// Kleiner Statuspunkt (Sidebar-Footer).
struct StatusDot: View {
    let color: Color
    var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay {
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .scaleEffect(pulse ? 1.9 : 1)
                    .opacity(pulse ? 0 : (pulsing ? 0.8 : 0))
            }
            .onAppear {
                guard pulsing, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
            }
            .accessibilityHidden(true)
    }
}
