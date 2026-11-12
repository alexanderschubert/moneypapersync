import SwiftUI
import AppKit

// MARK: - Akzentfarben (konfigurierbar, Standard: Blau)

enum AccentOption: String, CaseIterable, Identifiable, Codable {
    case blue, cyan, violet, green

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: "Blau"
        case .cyan: "Cyan"
        case .violet: "Violett"
        case .green: "Grün"
        }
    }

    var baseHex: String {
        switch self {
        case .blue: "3B82F6"
        case .cyan: "0EA5E9"
        case .violet: "8B5CF6"
        case .green: "22C55E"
        }
    }

    var lightHex: String {
        switch self {
        case .blue: "60A5FA"
        case .cyan: "38BDF8"
        case .violet: "A78BFA"
        case .green: "4ADE80"
        }
    }

    var darkHex: String {
        switch self {
        case .blue: "2563EB"
        case .cyan: "0284C7"
        case .violet: "7C3AED"
        case .green: "16A34A"
        }
    }
}

/// Hält die aktuell gewählte Akzentfarbe. `@Observable`, damit Views bei Änderung neu zeichnen.
@Observable
final class AccentTheme {
    static let shared = AccentTheme()
    var option: AccentOption = .blue
}

// MARK: - Farbpalette

enum AppColors {
    // Hintergründe
    static let background = Color(lightHex: "F3F5F9", darkHex: "0B1018")
    static let backgroundSecondary = Color(lightHex: "E8ECF3", darkHex: "101824")
    static let backgroundTertiary = Color(lightHex: "DFE5EE", darkHex: "151F2C")
    static let surface = Color(lightHex: "FFFFFF", darkHex: "182434")
    static let surfaceElevated = Color(lightHex: "FFFFFF", darkHex: "1D2B3D")

    // Akzent
    static var accent: Color { Color(hex: AccentTheme.shared.option.baseHex) }
    static var accentLight: Color { Color(hex: AccentTheme.shared.option.lightHex) }
    static var accentDark: Color { Color(hex: AccentTheme.shared.option.darkHex) }
    static let accentCyan = Color(hex: "38BDF8")

    // Status
    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")
    static let info = Color(hex: "38BDF8")
    static let neutral = Color(hex: "94A3B8")
    static let violet = Color(hex: "A78BFA")

    // Text
    static let textPrimary = Color(lightHex: "0F172A", darkHex: "F8FAFC")
    static let textSecondary = Color(lightHex: "334155", darkHex: "CBD5E1")
    static let textMuted = Color(lightHex: "64748B", darkHex: "94A3B8")
    static let textDisabled = Color(lightHex: "94A3B8", darkHex: "64748B")

    // Glass
    static let glassFill = Color(
        light: NSColor(white: 1, alpha: 0.65),
        dark: NSColor(white: 1, alpha: 0.05)
    )
    static let glassFillHover = Color(
        light: NSColor(white: 1, alpha: 0.85),
        dark: NSColor(white: 1, alpha: 0.08)
    )
    static let glassBorder = Color(
        light: NSColor(white: 0, alpha: 0.08),
        dark: NSColor(white: 1, alpha: 0.10)
    )
    static let divider = Color(
        light: NSColor(white: 0, alpha: 0.07),
        dark: NSColor(white: 1, alpha: 0.07)
    )
    static let sidebarBackground = Color(
        light: NSColor(hex: "E8ECF3").withAlphaComponent(0.92),
        dark: NSColor(hex: "101824").withAlphaComponent(0.90)
    )

    // Diagramm-Serie (feste Reihenfolge, keine Zufallsfarben)
    static let chartSeries: [Color] = [
        Color(hex: "3B82F6"), Color(hex: "38BDF8"), Color(hex: "A78BFA"),
        Color(hex: "22C55E"), Color(hex: "F59E0B"), Color(hex: "94A3B8")
    ]
}
