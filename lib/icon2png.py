"""Render an icon source to a 1024x1024 RGBA PNG for building an .icns.

usage: python3 -I icon2png.py <in.ico|.png|.exe> <out.png>

Why not sips? sips converts old 4-bit .ico files with alpha 15 instead of 255, so the
icons came out nearly transparent (as of macOS 26.6). Small images are scaled up with
nearest-neighbor so pixel art stays crisp. Needs Pillow.
"""

import os
import subprocess
import sys
import tempfile

from PIL import Image

SIZE = 1024


def load(path):
    if path.lower().endswith(".exe"):
        here = os.path.dirname(os.path.abspath(__file__))
        with tempfile.TemporaryDirectory() as tmp:
            ico = os.path.join(tmp, "x.ico")
            subprocess.run([sys.executable, "-I", os.path.join(here, "exe2ico.py"), path, ico], check=True)
            return load(ico)
    im = Image.open(path)
    if im.format == "ICO":
        im.size = max(im.info["sizes"])  # Pillow loads the frame matching .size
    return im.convert("RGBA")


def main(src, dst):
    im = load(src)
    w, h = im.size
    scale = SIZE / max(w, h)
    if scale > 1:
        k = int(scale)  # integer factor keeps pixels square
        im = im.resize((w * k, h * k), Image.NEAREST)
    else:
        im = im.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE))
    canvas.paste(im, ((SIZE - im.width) // 2, (SIZE - im.height) // 2))
    canvas.save(dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
