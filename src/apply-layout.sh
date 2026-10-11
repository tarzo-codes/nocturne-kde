#!/usr/bin/env bash
# Nocturne: rebuild panels + desktop widgets from layout.js, then reload Plasma and KWin.
# Replaces ALL existing panels. Safe to re-run.
set -euo pipefail
dir="$(dirname "$(readlink -f "$0")")"

QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)
[[ -n $QDBUS ]] || { echo "apply-layout: qdbus6 not found — skipping panel layout" >&2; exit 1; }
"$QDBUS" org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 || {
  echo "apply-layout: plasmashell is not running (log into Plasma first) — skipping" >&2; exit 1; }

# ── pinned apps: first match of each group that is installed ──
want=(
  "org.kde.dolphin"
  "org.kde.konsole|org.wezfurlong.wezterm|kitty|Alacritty|com.mitchellh.ghostty"
  "firefox|org.mozilla.firefox|chromium|google-chrome|brave-browser|com.brave.Browser|vivaldi-stable|zen"
  "org.kde.kate|code|codium|dev.zed.Zed|org.kde.kwrite"
  "com.obsproject.Studio"
  "systemsettings|kdesystemsettings"
)
appdirs=("$HOME/.local/share/applications" /usr/share/applications /usr/local/share/applications
         /var/lib/flatpak/exports/share/applications "$HOME/.local/share/flatpak/exports/share/applications")
launchers=()
for group in "${want[@]}"; do
  IFS='|' read -ra ids <<< "$group"
  for id in "${ids[@]}"; do
    for d in "${appdirs[@]}"; do
      if [[ -f "$d/$id.desktop" ]]; then launchers+=("applications:$id.desktop"); break 2; fi
    done
  done
done
LAUNCHERS=$(IFS=,; echo "${launchers[*]}")
script=$(sed "s|__LAUNCHERS__|$LAUNCHERS|" "$dir/layout.js")

out=$("$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script")
echo "$out"

# Plasma rewrites its config files while running, so edit them with the shell stopped.
systemctl --user stop plasma-plasmashell.service 2>/dev/null || { kquitapp6 plasmashell 2>/dev/null || true; sleep 2; }

# translucent panels (0 adaptive, 1 opaque, 2 translucent) — KWin blur shows through
while read -r kind a b c d; do
  if [[ $kind == top || $kind == dock ]] && [[ $b =~ ^[0-9]+$ ]]; then
    kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $b" --key panelOpacity 2
    [[ $kind == dock ]] && kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $b" --key floatingApplets 1
  fi
done <<< "$out"

# desktop widget positions, per containment and per screen size
NOCTURNE_OUT="$out" python3 - <<'EOF'
import os, re, subprocess
from pathlib import Path
rc = "plasma-org.kde.plasma.desktop-appletsrc"
desks = {}
for line in os.environ["NOCTURNE_OUT"].splitlines():
    f = line.split()
    if f and f[0] == "desk":
        desks[f[1]] = (int(f[3]), int(f[4]))
apps, cur = {}, None
for line in (Path.home() / ".config" / rc).read_text().splitlines():
    m = re.fullmatch(r"\[Containments\]\[(\d+)\]\[Applets\]\[(\d+)\]", line)
    if m:
        cur = m.groups(); continue
    if line.startswith("["):
        cur = None
    elif cur and line.startswith("plugin="):
        apps.setdefault(cur[0], []).append((cur[1], line[7:]))
for cid, (W, H) in desks.items():
    geo = []
    for aid, plugin in apps.get(cid, []):
        if plugin == "org.nocturne.clock":
            geo.append(f"Applet-{aid}:88,88,640,320,0;")
        elif plugin == "org.nocturne.stats":
            geo.append(f"Applet-{aid}:{W - 88 - 400},88,400,270,0;")
    if geo:
        for key in (f"ItemGeometries-{W}x{H}", "ItemGeometriesHorizontal"):
            subprocess.run(["kwriteconfig6", "--file", rc, "--group", "Containments", "--group", cid,
                            "--key", key, "".join(geo)], check=True)
        print(f"placed {len(geo)} widget(s) on containment {cid} ({W}x{H})")
EOF

systemctl --user start plasma-plasmashell.service 2>/dev/null || (setsid plasmashell >/dev/null 2>&1 &)
"$QDBUS" org.kde.KWin /KWin reconfigure 2>/dev/null || true
echo "layout applied"
