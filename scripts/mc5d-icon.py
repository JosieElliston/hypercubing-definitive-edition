#!/usr/bin/env python3
"""Generate icons/MC5D.svg: exploding colored cubes radiating from a center on black.

The icon captures MC5D's signature visual: tiny colored cubes (the stickers of a 5D
Rubik's cube) radiating outward from a central point, as the program actually looks
when you open it. Each direction uses one of the 10 face colors.

Run: python3 scripts/mc5d-icon.py   (edit this script, not the SVG)
"""
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "icons"
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">\n'

# MC5D's 10 face colours, matched from the program's actual palette.
COLORS = [
    "#ff3388",  # hot pink / magenta
    "#0066ff",  # blue
    "#00cc44",  # green
    "#00cccc",  # cyan
    "#ee2222",  # red
    "#eeee22",  # yellow
    "#ff8800",  # orange
    "#aa44ff",  # purple
    "#cccccc",  # light grey / white
    "#8888cc",  # lavender / muted blue
]


def cube_faces(cx, cy, s):
    """Return (front, top, right) polygon point-strings for a small isometric cube."""
    # Isometric-ish projection offsets
    dx, dy = s * 0.5, -s * 0.45
    # Front face
    f = [(cx - s, cy - s), (cx + s, cy - s), (cx + s, cy + s), (cx - s, cy + s)]
    # Top face: front-top edge → back-top edge
    t = [f[0], f[1], (f[1][0] + dx, f[1][1] + dy), (f[0][0] + dx, f[0][1] + dy)]
    # Right face: front-right edge → back-right edge
    r = [f[1], f[2], (f[2][0] + dx, f[2][1] + dy), (f[1][0] + dx, f[1][1] + dy)]
    return (
        " ".join(f"{x:.1f},{y:.1f}" for x, y in f),
        " ".join(f"{x:.1f},{y:.1f}" for x, y in t),
        " ".join(f"{x:.1f},{y:.1f}" for x, y in r),
    )


def darken(hex_color, factor=0.6):
    """Return a darker version of a hex colour."""
    r, g, b = int(hex_color[1:3], 16), int(hex_color[3:5], 16), int(hex_color[5:7], 16)
    return f"#{int(r*factor):02x}{int(g*factor):02x}{int(b*factor):02x}"


def lighten(hex_color, factor=0.3):
    """Return a lighter version of a hex colour."""
    r, g, b = int(hex_color[1:3], 16), int(hex_color[3:5], 16), int(hex_color[5:7], 16)
    r = min(255, int(r + (255 - r) * factor))
    g = min(255, int(g + (255 - g) * factor))
    b = min(255, int(b + (255 - b) * factor))
    return f"#{r:02x}{g:02x}{b:02x}"


def mc5d():
    cx, cy = 32, 33

    s = HEAD

    all_cubes = []  # (dist, x, y, size, color)

    n_rays = 10
    for i in range(n_rays):
        angle = i * 360 / n_rays - 90
        color = COLORS[i]
        rad = math.radians(angle)

        # Each ray: 2–3 cubes at increasing distances
        if i % 2 == 0:
            dists = [9, 16, 23]
        else:
            dists = [11, 20]

        for d in dists:
            x = cx + d * math.cos(rad)
            y = cy + d * math.sin(rad)
            cube_size = max(1.3, 2.5 - d * 0.04)
            all_cubes.append((d, x, y, cube_size, color))

    # Sort back-to-front
    all_cubes.sort(key=lambda c: -c[0])

    stroke = 'stroke="#000" stroke-width="0.4" stroke-linejoin="round"'
    for _, x, y, size, color in all_cubes:
        front_pts, top_pts, right_pts = cube_faces(x, y, size)
        # Three visible faces: top (light), front (normal), right (dark)
        s += f'<polygon points="{top_pts}" fill="{lighten(color)}" {stroke}/>\n'
        s += f'<polygon points="{right_pts}" fill="{darken(color)}" {stroke}/>\n'
        s += f'<polygon points="{front_pts}" fill="{color}" {stroke}/>\n'

    # Central cube, slightly larger and brighter
    cs = 3.0
    front_pts, top_pts, right_pts = cube_faces(cx, cy, cs)
    s += f'<polygon points="{top_pts}" fill="{lighten("#ff3388")}" {stroke}/>\n'
    s += f'<polygon points="{right_pts}" fill="{darken("#ff3388")}" {stroke}/>\n'
    s += f'<polygon points="{front_pts}" fill="#ff3388" {stroke}/>\n'

    s += '</svg>\n'
    return s


OUT.mkdir(exist_ok=True)
p = OUT / "MC5D.svg"
p.write_text(mc5d())
print(f"Wrote {p}")
