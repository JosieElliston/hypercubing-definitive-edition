#!/usr/bin/env python3
"""Write icons/{MC3D,NM11C,11C3D}.svg, for programs without a custom leaderboard icon.

Run: python3 scripts/own-icons.py   (edit the numbers here, not the SVGs)
"""
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "icons"
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">\n'


def mc3d():
    # The 1D-vision view of MC3D, stylized: one black strip holding equal-width runs, one per
    # face, in the video's order (F R D L B, a black gap, U). Each face's stickers are joined.
    colors = ["#0000ff", "#ee2222", "#eeee22", "#f0a030", "#44dd33", "#000000", "#ffffff"]
    w, pad, h = 8, 3, 12
    x0 = 32 - w * len(colors) / 2; y0 = 32 - h / 2
    s = HEAD + (f'<rect x="{x0 - pad}" y="{y0 - pad}" width="{w * len(colors) + 2 * pad}" '
                f'height="{h + 2 * pad}" rx="3" fill="#000"/>\n')
    for i, color in enumerate(colors):
        s += (f'<rect x="{x0 + i * w}" y="{y0}" width="{w}" height="{h}" fill="{color}" '
              f'stroke="#000" stroke-width="1.2"/>\n')
    return s + "</svg>\n"


def elevencell():
    # Nan Ma's Magic 11-Cell layout: 11 colored discs, without the icosahedron wireframes.
    # No background, and black outlines, to match the other icons (most are outlined art on
    # transparency); the outlines also keep the darkest discs from blending into a dark page.
    # Centers and colors are sampled from a screenshot (1540x1272, disc radius about 143 px).
    discs = [("#570d5d", 573, 185), ("#c8c840", 907, 185), ("#5cc93b", 401, 450),
             ("#bb271a", 741, 503), ("#bb27c5", 1079, 450), ("#be6625", 258, 730),
             ("#5cc9ca", 741, 792), ("#0000c4", 1223, 730), ("#666666", 425, 1022),
             ("#683710", 739, 1097), ("#204f11", 1055, 1022)]
    r = 143
    xs = [x for _, x, _ in discs]; ys = [y for _, _, y in discs]
    cx = (min(xs) + max(xs)) / 2; cy = (min(ys) + max(ys)) / 2
    span = max(max(xs) - min(xs), max(ys) - min(ys)) + 2 * r
    k = 60 / span
    s = HEAD
    for color, x, y in discs:
        s += (f'<circle cx="{32 + (x - cx) * k:.2f}" cy="{32 + (y - cy) * k:.2f}" '
              f'r="{r * k:.2f}" fill="{color}" stroke="#000" stroke-width="1.6"/>\n')
    return s + "</svg>\n"


def concave_pentagon(radius, rot_deg, pull):
    """Path of a pentagon whose sides bow toward the center (pull: control-point radius)."""
    pts = [(32 + radius * math.cos(math.radians(rot_deg + 72 * i)),
            32 + radius * math.sin(math.radians(rot_deg + 72 * i))) for i in range(5)]
    d = f"M{pts[0][0]:.2f},{pts[0][1]:.2f}"
    for i in range(5):
        a = math.radians(rot_deg + 72 * i + 36)
        nx, ny = pts[(i + 1) % 5]
        d += f" Q{32 + pull * math.cos(a):.2f},{32 + pull * math.sin(a):.2f} {nx:.2f},{ny:.2f}"
    return d + " Z", pts


def elevencell3d():
    # ElevenCell3D's green cell, vertex-centered, as if it were uncut (a 1x1): a pentagon
    # bowing inward, the far 5 vertices peeking out between its points, and 5 edges
    # running to the near vertex in the middle.
    back, _ = concave_pentagon(29, -90 + 36, 13)
    front, pts = concave_pentagon(30, -90, 14)
    stroke = 'stroke="#000" stroke-width="1.6" stroke-linejoin="round"'
    s = HEAD
    s += f'<path d="{back}" fill="#00b000" {stroke}/>\n'
    s += f'<path d="{front}" fill="#00ff00" {stroke}/>\n'
    for x, y in pts:
        s += f'<line x1="32" y1="32" x2="{x:.2f}" y2="{y:.2f}" {stroke}/>\n'
    return s + "</svg>\n"


OUT.mkdir(exist_ok=True)
for name, fn in [("MC3D", mc3d), ("NM11C", elevencell), ("11C3D", elevencell3d)]:
    (OUT / f"{name}.svg").write_text(fn())
