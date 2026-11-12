import SwiftUI

/// SF Pro (Systemschrift). Zahlen verwenden tabellarische Ziffern.
enum AppFont {
    static let dashboardTitle = Font.system(size: 28, weight: .bold)
    static let pageTitle = Font.system(size: 24, weight: .semibold)
    static let cardTitle = Font.system(size: 16, weight: .semibold)
    static let kpiValue = Font.system(size: 30, weight: .bold).monospacedDigit()
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let secondary = Font.system(size: 12, weight: .regular)
    static let table = Font.system(size: 12.5, weight: .regular)
    static let tableNumber = Font.system(size: 12.5, weight: .regular).monospacedDigit()
    static let caption = Font.system(size: 11, weight: .regular)
    static let captionMedium = Font.system(size: 11, weight: .medium)
    static let sectionLabel = Font.system(size: 11, weight: .semibold)
    static let wordmark = Font.system(size: 15, weight: .semibold, design: .default)
    static let mono = Font.system(size: 11.5, weight: .regular, design: .monospaced)
}
