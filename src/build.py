#!/usr/bin/env python3
"""Nocturne theme generator — one palette, every config file.

Run:  python3 ~/.local/share/nocturne/src/build.py   (or: nocturne rebuild)
Edit PALETTE in palette.py and re-run to re-theme everything.
  build.py  -> desktop: KDE colours, Konsole, GTK4/libadwaita
  prompt.py -> Starship bash prompt
  tools.py  -> CLI tools: bat, fzf, eza, atuin, btop, delta, lazygit, yazi, fastfetch
  plasma.py -> wallpaper/frost, icons, widgets, splash, logout screen, global theme, KDE settings
  sddm.py   -> SDDM login theme (installed with install-sddm.sh)
"""
import sys
sys.path.insert(0, str(__import__("pathlib").Path(__file__).parent))
from palette import P, rgb, write, HOME  # noqa: E402


# ─────────────────────────── KDE color scheme ───────────────────────────
def kde_group(bg, bg_alt, fg=P["text"], inactive=P["subtext"], **over):
    vals = dict(
        BackgroundAlternate=bg_alt, BackgroundNormal=bg,
        DecorationFocus=P["mint"], DecorationHover=P["mint"],
        ForegroundActive=P["mint"], ForegroundInactive=inactive,
        ForegroundLink=P["blue"], ForegroundNegative=P["red"],
        ForegroundNeutral=P["orange"], ForegroundNormal=fg,
        ForegroundPositive=P["green"], ForegroundVisited=P["violet"],
    )
    vals.update(over)
    return "\n".join(f"{k}={rgb(v)}" for k, v in vals.items())


kde = f"""[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=112,111,110
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
{kde_group(P["surface"], P["surface2"])}

[Colors:Complementary]
{kde_group(P["crust"], P["base_alt"])}

[Colors:Header]
{kde_group(P["crust"], P["base"])}

[Colors:Header][Inactive]
{kde_group(P["crust"], P["base"], inactive=P["muted"])}

[Colors:Selection]
{kde_group(P["mint"], P["mint_dim"], fg=P["on_mint"], inactive=P["on_mint"],
           ForegroundActive=P["on_mint"], ForegroundLink="#0b3a66",
           ForegroundVisited="#3b1f7a")}

[Colors:Tooltip]
{kde_group(P["base_alt"], P["surface"])}

[Colors:View]
{kde_group(P["mantle"], P["base_alt"])}

[Colors:Window]
{kde_group(P["base"], P["base_alt"])}

[General]
ColorScheme=Nocturne
Name=Nocturne
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground={rgb(P["crust"])}
activeBlend={rgb(P["text"])}
activeForeground={rgb(P["text"])}
inactiveBackground={rgb(P["crust"])}
inactiveBlend={rgb(P["muted"])}
inactiveForeground={rgb(P["muted"])}
"""
write(".local/share/color-schemes/Nocturne.colors", kde)


# ─────────────────────────── Konsole ───────────────────────────
from palette import ANSI as ansi  # noqa: E402
k = [f"[General]\nDescription=Nocturne\nOpacity=0.94\nBlur=true\nWallpaper=\n",
     f"[Background]\nColor={rgb(P['mantle'])}\n", f"[BackgroundIntense]\nColor={rgb(P['crust'])}\n",
     f"[BackgroundFaint]\nColor={rgb(P['mantle'])}\n",
     f"[Foreground]\nColor={rgb(P['text'])}\n", f"[ForegroundIntense]\nColor=255,255,255\n",
     f"[ForegroundFaint]\nColor={rgb(P['subtext'])}\n"]
for i, (n, b) in enumerate(ansi):
    k.append(f"[Color{i}]\nColor={rgb(n)}\n")
    k.append(f"[Color{i}Intense]\nColor={rgb(b)}\n")
    k.append(f"[Color{i}Faint]\nColor={rgb(n)}\n")
write(".local/share/konsole/Nocturne.colorscheme", "\n".join(k))

write(".local/share/konsole/Nocturne.profile", """[Appearance]
ColorScheme=Nocturne
Font=JetBrainsMono Nerd Font,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
LineSpacing=2
UseFontLineChararacters=true

[Cursor Options]
CursorShape=1

[General]
Name=Nocturne
Parent=FALLBACK/
TerminalCenter=true
TerminalMargin=14

[Scrolling]
HistoryMode=2
ScrollBarPosition=2

[Terminal Features]
BlinkingCursorEnabled=true
""")


# ─────────────────────────── GTK4 / libadwaita ───────────────────────────
adw = {
    "accent_color": P["mint"], "accent_bg_color": P["mint"], "accent_fg_color": P["on_mint"],
    "destructive_color": P["red"], "destructive_bg_color": P["red"], "destructive_fg_color": P["crust"],
    "success_color": P["green"], "success_bg_color": P["green"], "success_fg_color": P["crust"],
    "warning_color": P["yellow"], "warning_bg_color": P["yellow"], "warning_fg_color": P["crust"],
    "error_color": P["red"], "error_bg_color": P["red"], "error_fg_color": P["crust"],
    "window_bg_color": P["base"], "window_fg_color": P["text"],
    "view_bg_color": P["mantle"], "view_fg_color": P["text"],
    "headerbar_bg_color": P["crust"], "headerbar_fg_color": P["text"],
    "headerbar_border_color": P["text"], "headerbar_backdrop_color": P["crust"],
    "headerbar_shade_color": "rgba(0,0,0,0.36)",
    "sidebar_bg_color": P["crust"], "sidebar_fg_color": P["text"],
    "sidebar_backdrop_color": P["crust"], "sidebar_shade_color": "rgba(0,0,0,0.36)",
    "secondary_sidebar_bg_color": P["mantle"], "secondary_sidebar_fg_color": P["text"],
    "secondary_sidebar_backdrop_color": P["mantle"],
    "card_bg_color": P["surface"], "card_fg_color": P["text"], "card_shade_color": "rgba(0,0,0,0.36)",
    "dialog_bg_color": P["base_alt"], "dialog_fg_color": P["text"],
    "popover_bg_color": P["base_alt"], "popover_fg_color": P["text"],
    "popover_shade_color": "rgba(0,0,0,0.36)",
    "thumbnail_bg_color": P["surface"], "thumbnail_fg_color": P["text"],
    "shade_color": "rgba(0,0,0,0.36)", "scrollbar_outline_color": "rgba(0,0,0,0.5)",
}
defs = "\n".join(f"@define-color {k} {v};" for k, v in adw.items())
vars_ = "\n".join(f"  --{k.replace('_', '-')}: {v};" for k, v in adw.items())
NOCTURNE_GTK = f"""/* >>> nocturne >>> (generated by nocturne/src/build.py) */
{defs}
:root {{
{vars_}
}}
/* <<< nocturne <<< */
"""


def inject(path, block):
    """Insert/replace our block in a gtk.css, keeping kde-gtk-config's imports."""
    f = HOME / path
    old = f.read_text() if f.exists() else ""
    if ">>> nocturne >>>" in old:
        old = old.split("/* >>> nocturne >>>")[0] + old.split("/* <<< nocturne <<< */\n")[-1]
    write(path, old.rstrip("\n") + "\n\n" + block)


if not __import__("os").environ.get("NOCTURNE_SHELL_ONLY"):
    inject(".config/gtk-4.0/gtk.css", NOCTURNE_GTK)


import os                       # noqa: E402
import prompt  # noqa: E402,F401
import tools   # noqa: E402,F401
if not os.environ.get("NOCTURNE_SHELL_ONLY"):
    import plasma  # noqa: E402,F401
    import sddm    # noqa: E402,F401
print("done.")
