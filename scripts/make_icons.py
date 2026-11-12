#!/usr/bin/env python3
"""Erzeugt das App-Icon (Logo V4 – Dokumentenfokus) als PNG-Set für AppIcon.appiconset.

Geometrie identisch zu LogoGeometry in Design/Components/LogoView.swift (100×100-Raster).
Aufruf:  python3 scripts/make_icons.py
Benötigt: Pillow
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ICONSET = ROOT / "MoneyPaperSync/Resources/Assets.xcassets/AppIcon.appiconset"
BRAND = ROOT / "MoneyPaperSync/Resources/Assets.xcassets/LogoMono.imageset"

SS = 4  # Supersampling


def quad(p0, c, p1, n=12):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t ** 2 * p1[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t ** 2 * p1[1])
            for t in [i / n for i in range(1, n + 1)]]


def cubic(p0, c1, c2, p1, n=20):
    pts = []
    for i in range(1, n + 1):
        t = i / n
        u = 1 - t
        pts.append((u ** 3 * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t ** 3 * p1[0],
                    u ** 3 * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t ** 3 * p1[1]))
    return pts


def folder_back():
    p = [(14, 38), (14, 30)]
    p += quad((14, 30), (14, 26), (18, 26))
    p += [(38, 26)]
    p += quad((38, 26), (41, 26), (43, 29))
    p += [(46, 33), (82, 33)]
    p += quad((82, 33), (86, 33), (86, 37))
    p += [(86, 76)]
    p += quad((86, 76), (86, 80), (82, 80))
    p += [(18, 80)]
    p += quad((18, 80), (14, 80), (14, 76))
    return p


def document():
    p = [(34, 18), (54, 18), (62, 26), (62, 58)]
    p += quad((62, 58), (62, 62), (58, 62))
    p += [(34, 62)]
    p += quad((34, 62), (30, 62), (30, 58))
    p += [(30, 22)]
    p += quad((30, 22), (30, 18), (34, 18))
    return p


def folder_front():
    p = [(14, 52)]
    p += quad((14, 52), (14, 48), (18, 48))
    p += [(82, 48)]
    p += quad((82, 48), (86, 48), (86, 52))
    p += [(86, 76)]
    p += quad((86, 76), (86, 80), (82, 80))
    p += [(18, 80)]
    p += quad((18, 80), (14, 80), (14, 76))
    return p


def leaf():
    p = [(64, 77)]
    p += cubic((64, 77), (62, 64), (70, 57), (82, 57))
    p += cubic((82, 57), (83, 70), (76, 78), (64, 77))
    return p


def render_logo(size, mono=False, with_background=True):
    """Gibt ein RGBA-Bild zurück, in dem das 100er-Raster `size` Pixel breit ist."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = big / 100

    def poly(points, color):
        d.polygon([(x * s, y * s) for x, y in points], fill=color)

    if mono:
        black = (255, 255, 255, 255)
        poly(folder_back(), black)
        poly(document(), (255, 255, 255, 140))
        poly(folder_front(), black)
        poly(leaf(), (255, 255, 255, 190))
    else:
        if with_background:
            d.rounded_rectangle([0, 0, big - 1, big - 1], radius=22 * s, fill=(21, 29, 41, 255))
            d.rounded_rectangle([0, 0, big - 1, big - 1], radius=22 * s, outline=(255, 255, 255, 20), width=max(1, int(s)))
        poly(folder_back(), (59, 130, 246, 255))
        poly(document(), (248, 250, 252, 255))
        poly([(54, 18), (62, 26), (54, 26)], (203, 213, 225, 255))
        for x0, y0, w in [(36, 32, 20), (36, 38, 20), (36, 44, 13)]:
            d.rectangle([x0 * s, y0 * s, (x0 + w) * s, (y0 + 3) * s], fill=(148, 163, 184, 255))
        poly(folder_front(), (56, 189, 248, 255))
        poly(leaf(), (34, 197, 94, 255))
        d.line([(64 * s, 77 * s), (78 * s, 61 * s)], fill=(15, 81, 50, 255), width=max(1, int(1.4 * s)))

    return img.resize((size, size), Image.LANCZOS)


def render_app_icon(px):
    """macOS-Icon: Logo mit ~10 % Rand und dezentem Schatten auf transparentem Grund."""
    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    inner = int(px * 0.8)
    logo = render_logo(inner)
    offset = (px - inner) // 2

    shadow = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    mask = logo.split()[3].point(lambda a: int(a * 0.45))
    shadow.paste((0, 0, 0, 255), (offset, offset + max(1, px // 80)), mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(px / 60))

    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(logo, (offset, offset))
    return canvas


def main():
    ICONSET.mkdir(parents=True, exist_ok=True)
    BRAND.mkdir(parents=True, exist_ok=True)

    entries = []
    for base in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = base * scale
            name = f"icon_{base}x{base}{'@2x' if scale == 2 else ''}.png"
            render_app_icon(px).save(ICONSET / name)
            entries.append({
                "idiom": "mac",
                "size": f"{base}x{base}",
                "scale": f"{scale}x",
                "filename": name,
            })
    (ICONSET / "Contents.json").write_text(
        json.dumps({"images": entries, "info": {"version": 1, "author": "xcode"}}, indent=2)
    )

    # Zusätzliche Größen laut Spezifikation (Asset-Export, z. B. für Website/Dokumentation)
    export = ROOT / "Design-Assets"
    export.mkdir(exist_ok=True)
    for px in (16, 32, 64, 128, 256, 512, 1024):
        render_app_icon(px).save(export / f"AppIcon-{px}.png")
    render_logo(512, mono=True).save(export / "Logo-Monochrom-512.png")
    render_logo(128, mono=True).save(BRAND / "logo_mono.png")
    (BRAND / "Contents.json").write_text(json.dumps({
        "images": [{"idiom": "universal", "filename": "logo_mono.png", "scale": "1x"}],
        "info": {"version": 1, "author": "xcode"},
        "properties": {"template-rendering-intent": "template"},
    }, indent=2))

    print("Icons erzeugt:", ICONSET)


if __name__ == "__main__":
    main()
