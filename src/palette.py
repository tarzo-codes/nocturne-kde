"""Nocturne palette — the single source of truth for every generated theme.

Also holds the shared helpers every generator uses:
  write()  — writes a file, backing up anything it replaces (see NOCTURNE_STATE)
  WALLPAPER / FROST — the desktop wallpaper and its frosted-glass variant
"""
import os
import shutil
from pathlib import Path

HOME = Path.home()
SRC = Path(__file__).resolve().parent                 # installed copy of src/
STATE = Path(os.environ.get("NOCTURNE_STATE", HOME / ".local/state/nocturne"))
BACKUP = STATE / "backup"                               # originals of every file we replaced
MANIFEST = STATE / "created.txt"                        # files that did not exist before

PALETTE = {
    # surfaces (darkest -> lightest)
    "crust":    "#090c13",   # panels, title bars
    "mantle":   "#0c1019",   # views / editors / terminal
    "base":     "#10151f",   # windows
    "base_alt": "#141a26",   # alternate rows, tooltips, popovers
    "surface":  "#1a2130",   # buttons, cards
    "surface2": "#232c3e",   # hover
    "border":   "#2b3448",
    # text
    "text":     "#e3e7f1",
    "subtext":  "#a3acc2",
    "muted":    "#69738c",
    # accents
    "mint":     "#3ddbb5",   # primary accent (aurora)
    "mint_dim": "#2bb497",
    "on_mint":  "#06201a",
    "mint_tint": "#163a33",  # pill backgrounds
    "violet_tint": "#2a2348",
    "violet":   "#b49cff",   # secondary accent
    "blue":     "#7aa2f7",
    "pink":     "#f5a3d0",
    "red":      "#ff6b8b",
    "orange":   "#ffa66b",
    "yellow":   "#f2cd7c",
    "green":    "#8fdc7a",
}
P = PALETTE

# terminal ANSI 0-7: (normal, bright)
ANSI = [
    ("#1a2130", "#3b4560"), (P["red"], "#ff8fa6"), (P["green"], "#aaeb98"),
    (P["yellow"], "#f7dc9e"), (P["blue"], "#9bbaff"), (P["violet"], "#cdbdff"),
    (P["mint"], "#74f0d2"), ("#c8cede", "#f2f4f9"),
]

# ── wallpaper ────────────────────────────────────────────────
WALL_DIR = HOME / ".local/share/wallpapers/Nocturne"
_wall_cfg = HOME / ".config/nocturne/wallpaper"
WALLPAPER = Path(_wall_cfg.read_text().strip()) if _wall_cfg.exists() else WALL_DIR / "nocturne.jpg"
FROST = WALL_DIR / "frost.jpg"           # blurred + tinted + grain: lock screen, splash, logout, SDDM


def rgb(h):
    h = h.lstrip("#")
    return ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


def _remember(path: Path):
    """Back up an existing file once (first install wins), or record that we created it."""
    try:
        rel = path.relative_to(HOME)
    except ValueError:
        return
    made = _created()
    if any(str(parent) in made for parent in [rel, *rel.parents]):
        return                                      # Nocturne created it (or its folder)
    if path.exists():
        dest = BACKUP / rel
        if not dest.exists():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest)
    else:
        MANIFEST.parent.mkdir(parents=True, exist_ok=True)
        with MANIFEST.open("a") as f:
            f.write(f"{rel}\n")
        made.add(str(rel))


_created_cache = None


def _created():
    global _created_cache
    if _created_cache is None:
        _created_cache = set(MANIFEST.read_text().split("\n")) if MANIFEST.exists() else set()
    return _created_cache


def track(path):
    """Call before modifying a file outside write() (e.g. via kwriteconfig6)."""
    p = Path(path)
    p = p if p.is_absolute() else HOME / p
    _remember(p)


def write(path, text):
    path = HOME / path
    _remember(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    print("wrote", path)
