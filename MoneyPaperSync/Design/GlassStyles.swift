import SwiftUI

/// Glass-Karte: natives Material + dezentes Overlay + feiner Rand.
/// Nur für Karten/Panels verwenden – nicht für einzelne Listenzeilen (Performance).
struct GlassCardStyle: ViewModifier {
    var radius: CGFloat = AppRadius.card
    var shadow: Bool = true
    var hoverHighlight: Bool = false

    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(hovering && hoverHighlight ? AppColors.glassFillHover : AppColors.glassFill)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(AppColors.glassBorder, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(shadow ? 0.18 : 0), radius: 12, y: 4)
            }
            .onHover { inside in
                if hoverHighlight { hovering = inside }
            }
            .appAnimation(AppMotion.hover, value: hovering)
    }
}

/// Flache Fläche ohne Blur – für Tabellen und lange Listen.
struct FlatPanelStyle: ViewModifier {
    var radius: CGFloat = AppRadius.card

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.surface.opacity(0.65))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(AppColors.glassBorder, lineWidth: 1)
                    }
            }
    }
}

extension View {
    func glassCard(radius: CGFloat = AppRadius.card, shadow: Bool = true, hoverHighlight: Bool = false) -> some View {
        modifier(GlassCardStyle(radius: radius, shadow: shadow, hoverHighlight: hoverHighlight))
    }

    func flatPanel(radius: CGFloat = AppRadius.card) -> some View {
        modifier(FlatPanelStyle(radius: radius))
    }
}
