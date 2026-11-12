import SwiftUI

/// Einheitliche Statusanzeige: Symbol + Text + Farbe (nie nur Farbe).
struct StatusBadge: View {
    let text: String
    let systemImage: String
    let color: Color
    var tooltip: String?

    init(text: String, systemImage: String, color: Color, tooltip: String? = nil) {
        self.text = text
        self.systemImage = systemImage
        self.color = color
        self.tooltip = tooltip
    }

    init(status: DocumentStatus, tooltip: String? = nil) {
        self.init(text: status.title, systemImage: status.symbol, color: status.color, tooltip: tooltip)
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(AppFont.captionMedium)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.14)))
        .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 1))
        .help(tooltip ?? text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(text)")
    }
}

/// Kompaktes Statussymbol für Tabellenzeilen.
struct StatusGlyph: View {
    let status: DocumentStatus

    var body: some View {
        Image(systemName: status.symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(status.color)
            .help(status.title)
            .accessibilityLabel("Status: \(status.title)")
    }
}
