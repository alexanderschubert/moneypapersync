import SwiftUI

/// 4-Punkt-Raster
enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let section: CGFloat = 40
}

enum AppRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let card: CGFloat = 14
    static let large: CGFloat = 18
}

enum AppLayout {
    static let minWidth: CGFloat = 1000
    static let minHeight: CGFloat = 680
    static let idealWidth: CGFloat = 1280
    static let idealHeight: CGFloat = 850
    static let sidebarWidth: CGFloat = 220
    static let sidebarCompactWidth: CGFloat = 72
    static let contentPadding: CGFloat = 24
}

/// Breakpoints für adaptive Layouts, bezogen auf die Breite des Inhaltsbereichs.
enum LayoutClass {
    case large, medium, small

    init(contentWidth: CGFloat) {
        switch contentWidth {
        case 980...: self = .large
        case 720...: self = .medium
        default: self = .small
        }
    }

    var kpiColumns: Int {
        switch self {
        case .large: 4
        case .medium: 2
        case .small: 1
        }
    }
}
