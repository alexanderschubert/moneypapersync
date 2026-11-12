import SwiftUI

/// Standardkarte des Designsystems (Material + Overlay + Rand).
struct GlassCard<Content: View>: View {
    let padding: CGFloat
    var hoverHighlight: Bool
    @ViewBuilder let content: Content

    init(
        padding: CGFloat = AppSpacing.lg,
        hoverHighlight: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.hoverHighlight = hoverHighlight
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .glassCard(hoverHighlight: hoverHighlight)
    }
}
