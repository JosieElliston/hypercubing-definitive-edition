#!/usr/bin/env python3
"""Draw every app's icon and name in a grid, for the root README.

Run on the Mac after ./build.sh:  python3 scripts/icon-grid.py [--style mac|raw]
Writes icons/grid.png: one light-gray rounded card, the same in GitHub's light and dark themes.
Why light in both? Many icons are old Windows art with black outlines (MC4D, MC7D, MC3D)
that vanish on a dark background.

--style raw (default): the .icns artwork itself, trimmed and scaled to a common size.
--style mac: icons as macOS 26 shows them, via scripts/iconr, so non-square icons sit in
its gray squircle (smaller art, and the squircles look busy in a grid).
Needs Pillow, and scripts/iconr built (see NOTES.md).
"""
import argparse
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
APPS = ROOT / "dist/mac/hypercubing"
ICON = 240          # icon edge, px (README shows the PNG at half size)
COLS = 6
GAP_X, GAP_Y = 24, 56
LABEL_GAP = 18      # icon bottom to label top
FONT_PX = 34
PAD = 56
CARD = (196, 204, 214, 255)  # cool mid-gray: #f6f8fa read as glaring white
TEXT = (31, 35, 40, 255)
RADIUS = 48


def font():
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", FONT_PX)
    f.set_variation_by_name("Medium")  # not set_variation_by_axes: SFNS's first axis is width
    return f


def icon_mac(app, tmp):
    out = Path(tmp) / (app.stem + ".png")
    subprocess.run([str(ROOT / "scripts/iconr"), str(app), str(out), str(ICON)], check=True)
    return Image.open(out).convert("RGBA")


def icon_raw(app, tmp):
    icns = next((app / "Contents/Resources").glob("*.icns"))
    im = Image.open(icns)
    w, h, scale = max(im.info["sizes"], key=lambda s: s[0] * s[2])  # largest rep
    im.size = (w, h)
    im.load(scale=scale)
    im = im.convert("RGBA")
    im = im.crop(im.getbbox() or (0, 0, *im.size))  # trim transparent margins
    s = ICON * 0.86 / max(im.size)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    canvas = Image.new("RGBA", (ICON, ICON))
    canvas.alpha_composite(im, ((ICON - im.width) // 2, (ICON - im.height) // 2))
    return canvas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", choices=["mac", "raw"], default="raw")
    ap.add_argument("--out", default=str(ROOT / "icons"))
    ap.add_argument("--card", default=CARD, type=lambda v: (*bytes.fromhex(v.lstrip("#")), 255),
                    help="card color as hex, e.g. 'c8ced6'")
    args = ap.parse_args()

    apps = sorted(APPS.glob("*.app"), key=lambda p: p.stem.casefold())  # Finder's order
    if not apps:
        raise SystemExit(f"no apps in {APPS}; run ./build.sh first")
    get = icon_raw if args.style == "raw" else icon_mac
    with tempfile.TemporaryDirectory() as tmp:
        icons = [(a.stem, get(a, tmp)) for a in apps]

    f = font()
    cell_w = max(ICON, *(round(f.getlength(name)) for name, _ in icons)) + GAP_X
    asc, desc = f.getmetrics()
    cell_h = ICON + LABEL_GAP + asc + desc + GAP_Y
    rows = -(-len(icons) // COLS)
    W = COLS * cell_w + 2 * PAD - GAP_X
    H = rows * cell_h + 2 * PAD - GAP_Y

    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, W - 1, H - 1), RADIUS, fill=args.card)
    for i, (name, icon) in enumerate(icons):
        r, c = divmod(i, COLS)
        in_row = min(COLS, len(icons) - r * COLS)
        x0 = PAD + (COLS - in_row) * cell_w / 2 + c * cell_w  # center a short last row
        cx = round(x0 + (cell_w - GAP_X) / 2)
        y = PAD + r * cell_h
        img.alpha_composite(icon, (cx - ICON // 2, y))
        d.text((cx, y + ICON + LABEL_GAP), name, font=f, fill=TEXT, anchor="ma")
    path = Path(args.out) / "grid.png"
    img.save(path, optimize=True)
    print(path, img.size)


if __name__ == "__main__":
    main()
