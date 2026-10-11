#!/usr/bin/env bash
# Nocturne SDDM theme — install / uninstall system-wide (run with sudo).
#   sudo ./install-sddm.sh <path-to-built-theme-dir>
#   sudo ./install-sddm.sh --uninstall
set -euo pipefail

DEST=/usr/share/sddm/themes/nocturne
DROPIN=/etc/sddm.conf.d/zz-nocturne.conf      # "zz" sorts after kde_settings.conf
MAIN=/etc/sddm.conf
BAK=/etc/sddm.conf.bak-nocturne

[[ $EUID -eq 0 ]] || { echo "install-sddm: run with sudo" >&2; exit 1; }

if [[ ${1-} == --uninstall ]]; then
  rm -rf "$DEST" "$DROPIN"
  if [[ -f $BAK ]]; then mv -f "$BAK" "$MAIN"; echo "restored $MAIN"; fi
  echo "Nocturne SDDM theme removed"
  exit 0
fi

src=${1:?usage: install-sddm.sh <built theme dir> | --uninstall}
[[ -f $src/Main.qml && -f $src/metadata.desktop ]] || { echo "install-sddm: no theme in $src" >&2; exit 1; }
command -v sddm >/dev/null || { echo "install-sddm: SDDM is not installed — skipping" >&2; exit 2; }
if ! command -v sddm-greeter-qt6 >/dev/null; then
  echo "install-sddm: needs SDDM >= 0.21 with the Qt6 greeter (sddm-greeter-qt6) — skipping" >&2; exit 2
fi

rm -rf "$DEST"
cp -r "$src" "$DEST"
chown -R root:root "$DEST"
chmod -R u=rwX,go=rX "$DEST"

# /etc/sddm.conf is read last and wins, so if it pins a theme, edit it (with a backup);
# otherwise a drop-in is enough.
if [[ -f $MAIN ]] && grep -q '^[[:space:]]*Current[[:space:]]*=' "$MAIN"; then
  [[ -f $BAK ]] || cp -a "$MAIN" "$BAK"
  sed -i 's/^[[:space:]]*Current[[:space:]]*=.*/Current=nocturne/' "$MAIN"
  echo "set Current=nocturne in $MAIN (backup: $BAK)"
else
  mkdir -p /etc/sddm.conf.d
  printf '[Theme]\nCurrent=nocturne\n' > "$DROPIN"
  echo "wrote $DROPIN"
fi
echo "Nocturne SDDM theme installed — you'll see it at the next login"
