#!/usr/bin/env bash
# Nocturne uninstaller — restores the settings backed up at install time and
# removes every file Nocturne created.   Usage: ./uninstall.sh [-y]
set -uo pipefail

STATE="$HOME/.local/state/nocturne"
BACKUP="$STATE/backup"
PREFIX="$HOME/.local/share/nocturne"
YES=0; [[ ${1-} == -y || ${1-} == --yes ]] && YES=1

M=$'\e[38;2;61;219;181m' Y=$'\e[38;2;242;205;124m' D=$'\e[38;2;105;115;140m' N=$'\e[0m'
ok()   { printf '  %s✓%s %s\n' "$M" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*" >&2; }
has()  { command -v "$1" >/dev/null 2>&1; }

[[ -d $STATE ]] || { echo "Nocturne doesn't seem to be installed (no $STATE)"; exit 0; }
(( EUID != 0 )) || { echo "run as your normal user"; exit 1; }
if (( ! YES )); then
  read -r -p "Remove Nocturne and restore your previous settings? [y/N] " a
  [[ ${a,,} == y* ]] || exit 0
fi

running=0
if [[ ${XDG_CURRENT_DESKTOP-} == *KDE* ]] && pgrep -u "$USER" -x plasmashell >/dev/null; then
  running=1
  systemctl --user stop plasma-plasmashell.service 2>/dev/null || { kquitapp6 plasmashell 2>/dev/null; sleep 2; }
fi

# 1. restore every file we backed up (except .bashrc — we only strip our block from it)
if [[ -d $BACKUP ]]; then
  while IFS= read -r -d '' f; do
    rel=${f#"$BACKUP/"}
    [[ $rel == .bashrc ]] && continue
    mkdir -p "$HOME/$(dirname "$rel")"
    cp -a "$f" "$HOME/$rel"
  done < <(find "$BACKUP" -type f -print0)
  ok "restored your original settings"
fi

# 2. delete files that did not exist before Nocturne
if [[ -f $STATE/created.txt ]]; then
  sort -u "$STATE/created.txt" | while IFS= read -r rel; do
    [[ -n $rel && $rel != /* && $rel != *..* ]] || continue
    [[ -e $HOME/$rel || -L $HOME/$rel ]] && rm -rf -- "${HOME:?}/$rel"
    # prune folders that are now empty (never above $HOME)
    d=$(dirname "$rel")
    while [[ $d != . && $d != / ]]; do
      rmdir -- "$HOME/$d" 2>/dev/null || break
      d=$(dirname "$d")
    done
  done
fi
for d in .local/share/plasma/plasmoids/org.nocturne.clock .local/share/plasma/plasmoids/org.nocturne.stats \
         .local/share/plasma/look-and-feel/org.nocturne.desktop .local/share/icons/Papirus-Nocturne \
         .local/share/wallpapers/Nocturne .config/nocturne .local/share/color-schemes/Nocturne.colors \
         .local/share/konsole/Nocturne.profile .local/share/konsole/Nocturne.colorscheme \
         .local/share/icons/hicolor/scalable/apps/nocturne-logo.svg .local/bin/nocturne; do
  rm -rf -- "${HOME:?}/$d"
done
ok "removed Nocturne files"

# 3. ~/.bashrc: strip the Nocturne block only
if [[ -f $HOME/.bashrc ]] && grep -q '# >>> nocturne >>>' "$HOME/.bashrc"; then
  sed -i '/^$/N;/\n# >>> nocturne >>>/!P;D' "$HOME/.bashrc" 2>/dev/null || true
  sed -i '/# >>> nocturne >>>/,/# <<< nocturne <<</d' "$HOME/.bashrc"
  ok "removed the Nocturne block from ~/.bashrc"
fi

# 4. git: drop the delta include (only if .gitconfig wasn't restored from backup)
if has git; then
  git config --global --fixed-value --unset-all include.path "$HOME/.config/nocturne/delta.gitconfig" 2>/dev/null || true
  # a .gitconfig that only ever held our include is now empty — remove it
  if [[ -f $HOME/.gitconfig && -z $(git config --global --list 2>/dev/null) ]]; then rm -f "$HOME/.gitconfig"; fi
fi

# 5. GNOME/GTK settings
if [[ -f $STATE/gsettings ]] && has gsettings; then
  while IFS='=' read -r k v; do
    [[ -n $v ]] && gsettings set org.gnome.desktop.interface "$k" "$v" 2>/dev/null || true
  done < "$STATE/gsettings"
fi

# 6. login screen
if [[ -f $STATE/sddm-installed ]]; then
  if [[ -f $PREFIX/src/install-sddm.sh ]]; then
    sudo bash "$PREFIX/src/install-sddm.sh" --uninstall || warn "couldn't remove the SDDM theme — run: sudo rm -rf /usr/share/sddm/themes/nocturne"
  fi
fi

# 7. re-apply the restored look
if (( running )); then
  scheme=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null || echo BreezeDark)
  systemctl --user start plasma-plasmashell.service 2>/dev/null || (setsid plasmashell >/dev/null 2>&1 &)
  sleep 2
  plasma-apply-colorscheme "${scheme:-BreezeDark}" >/dev/null 2>&1 || true
  (qdbus6 org.kde.KWin /KWin reconfigure || qdbus org.kde.KWin /KWin reconfigure) >/dev/null 2>&1 || true
fi

rm -rf -- "${PREFIX:?}" "${STATE:?}"
printf '\n%s☾  Nocturne removed.%s %sLog out and back in to finish.%s\n' "$M" "$N" "$D" "$N"
