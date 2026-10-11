"""Nocturne crescent logo (SVG) + helpers to rasterise it."""
import shutil
import subprocess

from palette import P

C = P
LOGO = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="g" x1="0" y1="1" x2="1" y2="0">
      <stop offset="0" stop-color="{C['mint']}"/>
      <stop offset="1" stop-color="{C['violet']}"/>
    </linearGradient>
  </defs>
  <path fill="url(#g)" d="M107.2 76.6 A48 48 0 1 1 51.4 20.8 A40 40 0 0 0 107.2 76.6 Z"/>
  <path fill="{C['mint']}" d="M94 22 Q96 34 108 36 Q96 38 94 50 Q92 38 80 36 Q92 34 94 22 Z"/>
</svg>
"""

MAGICK = shutil.which("magick") or shutil.which("convert")


def magick(*args):
    """Run ImageMagick (v7 `magick` or v6 `convert`); returns True on success."""
    if not MAGICK:
        return False
    return subprocess.run([MAGICK, *map(str, args)], capture_output=True).returncode == 0


def pixels(svg_path, size):
    """Rasterise an SVG to size×size and return rows of (r,g,b,a) tuples, or None."""
    if not MAGICK:
        return None
    out = subprocess.run([MAGICK, "-background", "none", "-density", "384", str(svg_path),
                          "-resize", f"{size}x{size}", "-depth", "8", "rgba:-"],
                         capture_output=True).stdout
    if len(out) != size * size * 4:
        return None
    return [[tuple(out[(y * size + x) * 4:(y * size + x) * 4 + 4]) for x in range(size)] for y in range(size)]
