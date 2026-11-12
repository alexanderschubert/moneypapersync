import SwiftUI

/// Logo V4 – Dokumentenfokus.
/// Abgerundetes Quadrat (Anthrazit), blau/cyanfarbener Ordner, weißes PDF-Dokument, grünes Blatt.
/// Geometrie in einem 100×100-Raster; identisch zu scripts/make_icons.py.
struct LogoMark: View {
    var size: CGFloat = 32
    /// Einfarbige Variante für kleine Darstellungen / Template-Nutzung.
    var monochrome = false

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 100
            let scale = CGAffineTransform(scaleX: s, y: s)

            func fill(_ path: Path, _ color: Color) {
                context.fill(path.applying(scale), with: .color(color))
            }

            if monochrome {
                let color = Color.primary
                fill(LogoGeometry.folderBack, color)
                fill(LogoGeometry.document, color.opacity(0.55))
                fill(LogoGeometry.folderFront, color)
                fill(LogoGeometry.leaf, color.opacity(0.75))
                return
            }

            let bg = Path(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerRadius: 22, style: .continuous)
            fill(bg, Color(hex: "151D29"))
            context.stroke(bg.applying(scale), with: .color(.white.opacity(0.08)), lineWidth: 1)

            fill(LogoGeometry.folderBack, Color(hex: "3B82F6"))
            fill(LogoGeometry.document, Color(hex: "F8FAFC"))
            fill(LogoGeometry.documentFold, Color(hex: "CBD5E1"))
            for line in LogoGeometry.documentLines {
                fill(line, Color(hex: "94A3B8"))
            }
            fill(LogoGeometry.folderFront, Color(hex: "38BDF8"))
            fill(LogoGeometry.leaf, Color(hex: "22C55E"))
            context.stroke(LogoGeometry.leafRib.applying(scale), with: .color(Color(hex: "0F5132")), lineWidth: 1.4 * s)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(monochrome ? 0 : 0.25), radius: size * 0.06, y: size * 0.03)
        .accessibilityLabel("MoneyPaperSync Logo")
    }
}

enum LogoGeometry {
    static var folderBack: Path {
        var p = Path()
        p.move(to: CGPoint(x: 14, y: 38))
        p.addLine(to: CGPoint(x: 14, y: 30))
        p.addQuadCurve(to: CGPoint(x: 18, y: 26), control: CGPoint(x: 14, y: 26))
        p.addLine(to: CGPoint(x: 38, y: 26))
        p.addQuadCurve(to: CGPoint(x: 43, y: 29), control: CGPoint(x: 41, y: 26))
        p.addLine(to: CGPoint(x: 46, y: 33))
        p.addLine(to: CGPoint(x: 82, y: 33))
        p.addQuadCurve(to: CGPoint(x: 86, y: 37), control: CGPoint(x: 86, y: 33))
        p.addLine(to: CGPoint(x: 86, y: 76))
        p.addQuadCurve(to: CGPoint(x: 82, y: 80), control: CGPoint(x: 86, y: 80))
        p.addLine(to: CGPoint(x: 18, y: 80))
        p.addQuadCurve(to: CGPoint(x: 14, y: 76), control: CGPoint(x: 14, y: 80))
        p.closeSubpath()
        return p
    }

    static var document: Path {
        var p = Path()
        p.move(to: CGPoint(x: 34, y: 18))
        p.addLine(to: CGPoint(x: 54, y: 18))
        p.addLine(to: CGPoint(x: 62, y: 26))
        p.addLine(to: CGPoint(x: 62, y: 58))
        p.addQuadCurve(to: CGPoint(x: 58, y: 62), control: CGPoint(x: 62, y: 62))
        p.addLine(to: CGPoint(x: 34, y: 62))
        p.addQuadCurve(to: CGPoint(x: 30, y: 58), control: CGPoint(x: 30, y: 62))
        p.addLine(to: CGPoint(x: 30, y: 22))
        p.addQuadCurve(to: CGPoint(x: 34, y: 18), control: CGPoint(x: 30, y: 18))
        p.closeSubpath()
        return p
    }

    static var documentFold: Path {
        var p = Path()
        p.move(to: CGPoint(x: 54, y: 18))
        p.addLine(to: CGPoint(x: 62, y: 26))
        p.addLine(to: CGPoint(x: 54, y: 26))
        p.closeSubpath()
        return p
    }

    static var documentLines: [Path] {
        [
            Path(CGRect(x: 36, y: 32, width: 20, height: 3)),
            Path(CGRect(x: 36, y: 38, width: 20, height: 3)),
            Path(CGRect(x: 36, y: 44, width: 13, height: 3))
        ]
    }

    static var folderFront: Path {
        var p = Path()
        p.move(to: CGPoint(x: 14, y: 52))
        p.addQuadCurve(to: CGPoint(x: 18, y: 48), control: CGPoint(x: 14, y: 48))
        p.addLine(to: CGPoint(x: 82, y: 48))
        p.addQuadCurve(to: CGPoint(x: 86, y: 52), control: CGPoint(x: 86, y: 48))
        p.addLine(to: CGPoint(x: 86, y: 76))
        p.addQuadCurve(to: CGPoint(x: 82, y: 80), control: CGPoint(x: 86, y: 80))
        p.addLine(to: CGPoint(x: 18, y: 80))
        p.addQuadCurve(to: CGPoint(x: 14, y: 76), control: CGPoint(x: 14, y: 80))
        p.closeSubpath()
        return p
    }

    static var leaf: Path {
        var p = Path()
        p.move(to: CGPoint(x: 64, y: 77))
        p.addCurve(to: CGPoint(x: 82, y: 57), control1: CGPoint(x: 62, y: 64), control2: CGPoint(x: 70, y: 57))
        p.addCurve(to: CGPoint(x: 64, y: 77), control1: CGPoint(x: 83, y: 70), control2: CGPoint(x: 76, y: 78))
        p.closeSubpath()
        return p
    }

    static var leafRib: Path {
        var p = Path()
        p.move(to: CGPoint(x: 64, y: 77))
        p.addLine(to: CGPoint(x: 78, y: 61))
        return p
    }
}

/// Wortmarke: „MoneyPaper“ in Weiß/Primärtext, „Sync“ im Akzent.
struct Wordmark: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("MoneyPaper").foregroundStyle(AppColors.textPrimary)
            Text("Sync").foregroundStyle(AppColors.accent)
        }
        .font(AppFont.wordmark)
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("MoneyPaperSync")
    }
}
