import SwiftUI
import AppKit

// MARK: - Zentrales Designsystem
//
// Alle Farben, Abstände, Typografie und Glass-Stile des Projekts sind in
// Design/ definiert. Views verwenden ausschließlich diese Werte.
//
//  - ColorPalette.swift  → AppColors
//  - Spacing.swift       → AppSpacing, AppRadius, AppLayout
//  - Typography.swift    → AppFont
//  - GlassStyles.swift   → .glassCard(), .flatPanel()
//  - Components/         → wiederverwendbare Views

// MARK: Hex- und dynamische Farben

extension NSColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex))
    }

    /// Farbe, die sich automatisch an Hell-/Dunkel-Darstellung anpasst.
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    init(lightHex: String, darkHex: String) {
        self.init(light: NSColor(hex: lightHex), dark: NSColor(hex: darkHex))
    }
}

// MARK: Bewegung (Reduced Motion)

struct AppMotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let duration: Double
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .easeInOut(duration: duration), value: value)
    }
}

enum AppMotion {
    static let navigation = 0.18
    static let status = 0.20
    static let sidebar = 0.20
    static let hover = 0.15
}

extension View {
    /// Animiert Änderungen von `value`, berücksichtigt „Bewegung reduzieren“.
    func appAnimation<V: Equatable>(_ duration: Double = AppMotion.status, value: V) -> some View {
        modifier(AppMotionModifier(duration: duration, value: value))
    }
}
