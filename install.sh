#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────┐
# │  Nocturne — ink-navy & aurora-mint theme for KDE Plasma 6    │
# │  installer                                                   │
# └──────────────────────────────────────────────────────────────┘
# Usage: ./install.sh [options]
#   -y, --yes            answer "yes" to every question (non-interactive)
#       --no-deps        don't install packages (use what's already there)
#       --no-layout      keep your current panels (skip top bar + dock + desktop widgets)
#       --no-sddm        don't install the login-screen theme
#       --no-shell       don't touch ~/.bashrc
#       --shell-only     only the terminal side (prompt, CLI tool themes, nvim) — no desktop changes
#       --wallpaper IMG  use your own wallpaper instead of the bundled one
#   -h, --help           show this help
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="$HOME/.local/share/nocturne"
export NOCTURNE_STATE="$HOME/.local/state/nocturne"
BACKUP="$NOCTURNE_STATE/backup"
WALL_DIR="$HOME/.local/share/wallpapers/Nocturne"

YES=0 DEPS=1 LAYOUT=1 SDDM=1 SHELLRC=1 SHELL_ONLY=0 WALLPAPER=""

# ── pretty output ────────────────────────────────────────────
if [[ -t 1 ]]; then
  M=$'\e[38;2;61;219;181m' V=$'\e[38;2;180;156;255m' Y=$'\e[38;2;242;205;124m'
  R=$'\e[38;2;255;107;139m' D=$'\e[38;2;105;115;140m' B=$'\e[1m' N=$'\e[0m'
else M= V= Y= R= D= B= N=; fi
step() { printf '\n%s◆%s %s%s%s\n' "$M" "$N" "$B" "$*" "$N"; }
info() { printf '  %s·%s %s\n' "$D" "$N" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$M" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
ask()  { # ask "question" default(y/n)
  local q=$1 def=${2:-y} a
  (( YES )) && return 0
  [[ -t 0 ]] || { [[ $def == y ]]; return; }
  read -r -p "  ${V}?${N} $q $([[ $def == y ]] && echo '[Y/n]' || echo '[y/N]') " a || true
  a=${a:-$def}; [[ ${a,,} == y* ]]
}
has() { command -v "$1" >/dev/null 2>&1; }
trap 'die "failed at line $LINENO: $BASH_COMMAND"' ERR

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while (($#)); do
  case $1 in
    -y|--yes) YES=1 ;;
    --no-deps) DEPS=0 ;;
    --no-layout) LAYOUT=0 ;;
    --no-sddm) SDDM=0 ;;
    --no-shell) SHELLRC=0 ;;
    --shell-only) SHELL_ONLY=1 LAYOUT=0 SDDM=0 ;;
    --wallpaper) WALLPAPER=${2:?--wallpaper needs a path}; shift ;;
    --wallpaper=*) WALLPAPER=${1#*=} ;;
    -h|--help) usage ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done

printf '%s\n' "${M}  ☾  nocturne${N}  ${D}ink-navy · aurora mint · violet${N}"

# ── sanity checks ────────────────────────────────────────────
step "Checking your system"
(( EUID != 0 )) || die "don't run this as root — it installs into your home directory (it will ask for sudo when needed)"
[[ $(uname -s) == Linux ]] || die "Nocturne is for Linux"
(( BASH_VERSINFO[0] >= 4 )) || die "bash 4+ required"
[[ -f $REPO/src/build.py ]] || die "run install.sh from inside the nocturne-kde folder"

PLASMA_MAJOR=0
if has plasmashell; then PLASMA_MAJOR=$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo 0); fi
if (( ! SHELL_ONLY )); then
  if (( PLASMA_MAJOR != 6 )); then
    warn "KDE Plasma 6 not found (got: ${PLASMA_MAJOR/#0/none}) — installing the terminal side only"
    SHELL_ONLY=1 LAYOUT=0 SDDM=0
  fi
fi
LIVE=0
if (( ! SHELL_ONLY )) && [[ ${XDG_CURRENT_DESKTOP-} == *KDE* ]] && [[ -n ${WAYLAND_DISPLAY-}${DISPLAY-} ]]; then
  LIVE=1
fi
(( SHELL_ONLY )) && info "mode: terminal only" || info "mode: full desktop (Plasma $PLASMA_MAJOR)$( ((LIVE)) || echo ', not in a Plasma session — changes apply at next login')"
if [[ -n $WALLPAPER ]]; then
  WALLPAPER=$(readlink -f -- "$WALLPAPER" || true)
  [[ -f $WALLPAPER ]] || die "wallpaper not found: $WALLPAPER"
fi

mkdir -p "$NOCTURNE_STATE"

# ── packages ─────────────────────────────────────────────────
PM=""
for p in pacman apt-get dnf zypper; do has $p && { PM=$p; break; }; done

declare -A PKGS=(
  [pacman]="python imagemagick inter-font ttf-jetbrains-mono-nerd papirus-icon-theme starship bat eza fzf zoxide atuin neovim fd ripgrep btop git-delta yazi lazygit fastfetch tealdeer eva git"
  [apt-get]="python3 imagemagick fonts-inter papirus-icon-theme bat eza fzf zoxide neovim fd-find ripgrep btop git-delta fastfetch tealdeer git"
  [dnf]="python3 ImageMagick rsms-inter-fonts papirus-icon-theme bat eza fzf zoxide neovim fd-find ripgrep btop git-delta fastfetch tealdeer git"
  [zypper]="python3 ImageMagick google-inter-fonts papirus-icon-theme starship bat eza fzf zoxide atuin neovim fd ripgrep btop git-delta yazi lazygit fastfetch tealdeer git"
)
pkg_available() {
  case $PM in
    pacman)  pacman -Si "$1" >/dev/null 2>&1 || pacman -Qi "$1" >/dev/null 2>&1 ;;
    apt-get) apt-cache show "$1" >/dev/null 2>&1 ;;
    dnf)     dnf -q info "$1" >/dev/null 2>&1 ;;
    zypper)  [[ $(zypper -q info "$1" 2>/dev/null) == *"Name"* ]] ;;
  esac
}
pkg_installed() {
  case $PM in
    pacman)  pacman -Qi "$1" >/dev/null 2>&1 ;;
    apt-get) dpkg -s "$1" >/dev/null 2>&1 ;;
    dnf|zypper) rpm -q "$1" >/dev/null 2>&1 ;;
  esac
}

if (( DEPS )); then
  step "Packages"
  if [[ -z $PM ]]; then
    warn "no supported package manager found (pacman/apt/dnf/zypper) — install the tools yourself, see README"
  else
    want=() missing=()
    for p in ${PKGS[$PM]}; do
      pkg_installed "$p" && continue
      if pkg_available "$p"; then want+=("$p"); else missing+=("$p"); fi
    done
    (( ${#missing[@]} )) && info "not in your repos (skipped): ${missing[*]}"
    if (( ${#want[@]} == 0 )); then
      ok "everything is already installed"
    elif ask "Install ${#want[@]} package(s): ${want[*]} ?" y; then
      case $PM in
        pacman)  sudo pacman -S --needed --noconfirm "${want[@]}" ;;
        apt-get) sudo apt-get update -qq && sudo apt-get install -y "${want[@]}" ;;
        dnf)     sudo dnf install -y "${want[@]}" ;;
        zypper)  sudo zypper --non-interactive install "${want[@]}" ;;
      esac || warn "some packages failed to install — continuing with what's available"
    fi
    # ble.sh lives in the AUR on Arch
    if [[ $PM == pacman ]] && ! pacman -Qq blesh blesh-git >/dev/null 2>&1; then
      AUR=$(command -v paru || command -v yay || true)
      if [[ -n $AUR ]] && ask "Install ble.sh (syntax highlighting + autosuggestions) from the AUR with ${AUR##*/}?" y; then
        "$AUR" -S --needed --noconfirm blesh-git || warn "ble.sh install failed — the prompt still works without it"
      fi
    fi
  fi
fi
has python3 || die "python3 is required"
has magick || has convert || warn "ImageMagick not found — wallpaper, frosted backgrounds and the fastfetch logo will be skipped"

# Debian/Ubuntu ship bat/fd as batcat/fdfind
mkdir -p "$HOME/.local/bin"
for pair in batcat:bat fdfind:fd; do
  src=${pair%%:*} dst=${pair##*:}
  if ! has "$dst" && has "$src"; then
    ln -sf "$(command -v "$src")" "$HOME/.local/bin/$dst"; ok "linked $src → ~/.local/bin/$dst"
    echo ".local/bin/$dst" >> "$NOCTURNE_STATE/created.txt"
  fi
done

# Nerd Font (icons in prompt, eza, nvim, yazi)
if has fc-list && [[ $(fc-list : family 2>/dev/null) != *"JetBrainsMono Nerd Font"* ]]; then
  warn "JetBrainsMono Nerd Font is not installed — icons will show as boxes"
  if has curl && has unzip && ask "Download it from github.com/ryanoasis/nerd-fonts into ~/.local/share/fonts?" y; then
    tmp=$(mktemp -d)
    if curl -fsSL -o "$tmp/f.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip; then
      mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerd"
      unzip -oq "$tmp/f.zip" '*.ttf' -d "$HOME/.local/share/fonts/JetBrainsMonoNerd"
      fc-cache -f >/dev/null; ok "font installed"
      echo ".local/share/fonts/JetBrainsMonoNerd" >> "$NOCTURNE_STATE/created.txt"
    else warn "download failed — install a Nerd Font manually"; fi
    rm -rf "$tmp"
  fi
fi

# ── backup ───────────────────────────────────────────────────
step "Backing up your current settings"
mkdir -p "$BACKUP"
first_install=0
[[ -f $NOCTURNE_STATE/installed-at ]] || { first_install=1; date -Is > "$NOCTURNE_STATE/installed-at"; }
for f in .config/kdeglobals .config/kwinrc .config/breezerc .config/plasmarc .config/plasmashellrc \
         .config/plasma-org.kde.plasma.desktop-appletsrc .config/ksplashrc .config/kscreenlockerrc \
         .config/kcminputrc .config/konsolerc .config/gtk-3.0/settings.ini .config/gtk-4.0/settings.ini \
         .config/gtk-4.0/gtk.css .config/starship.toml .gitconfig; do
  if [[ -f $HOME/$f && ! -e $BACKUP/$f ]]; then
    mkdir -p "$BACKUP/$(dirname "$f")"; cp -a "$HOME/$f" "$BACKUP/$f"
  fi
done
if (( first_install )) && has gsettings; then
  for k in color-scheme gtk-theme icon-theme cursor-theme font-name monospace-font-name; do
    printf '%s=%s\n' "$k" "$(gsettings get org.gnome.desktop.interface "$k" 2>/dev/null)" >> "$NOCTURNE_STATE/gsettings"
  done
fi
ok "originals saved in ${NOCTURNE_STATE/#$HOME/\~}/backup (first install only — re-runs keep them)"

# ── install files ────────────────────────────────────────────
step "Installing Nocturne"
mkdir -p "$PREFIX"
rm -rf "$PREFIX/src" "$PREFIX/shell"
cp -r "$REPO/src" "$REPO/shell" "$PREFIX/"
cp "$REPO/uninstall.sh" "$PREFIX/"
mkdir -p "$PREFIX/screenshots" "$PREFIX/wallpaper"
[[ -f $REPO/screenshots/preview.png ]] && cp "$REPO/screenshots/preview.png" "$PREFIX/screenshots/"
[[ -f $REPO/wallpaper/nocturne.jpg ]] && cp "$REPO/wallpaper/nocturne.jpg" "$PREFIX/wallpaper/"
install -m 755 "$REPO/bin/nocturne" "$HOME/.local/bin/nocturne"
ok "files in ${PREFIX/#$HOME/\~}, command: nocturne"

mkdir -p "$WALL_DIR" "$HOME/.config/nocturne"
if [[ -n $WALLPAPER ]]; then
  dest="$WALL_DIR/custom.${WALLPAPER##*.}"
  cp -f "$WALLPAPER" "$dest"; echo "$dest" > "$HOME/.config/nocturne/wallpaper"
  ok "wallpaper: $WALLPAPER"
elif [[ -f $HOME/.config/nocturne/wallpaper && ! -f $(cat "$HOME/.config/nocturne/wallpaper") ]]; then
  rm -f "$HOME/.config/nocturne/wallpaper"      # stale custom wallpaper → back to the default
fi
[[ -f $WALL_DIR/nocturne.jpg || ! -f $REPO/wallpaper/nocturne.jpg ]] || cp "$REPO/wallpaper/nocturne.jpg" "$WALL_DIR/"

step "Generating themes from the palette"
if (( SHELL_ONLY )); then export NOCTURNE_SHELL_ONLY=1; fi
python3 "$PREFIX/src/build.py" | sed "s|$HOME|~|; s/^/  ${D}·${N} /"

# Neovim: never overwrite an existing config
if has nvim; then
  if [[ -e $HOME/.config/nvim/init.lua || -e $HOME/.config/nvim/init.vim ]]; then
    if cmp -s "$REPO/nvim/init.lua" "$HOME/.config/nvim/init.lua" 2>/dev/null; then ok "nvim config up to date"
    else info "kept your nvim config — the colourscheme is available as :colorscheme nocturne"; fi
  else
    cp "$REPO/nvim/init.lua" "$HOME/.config/nvim/init.lua"
    echo ".config/nvim/init.lua" >> "$NOCTURNE_STATE/created.txt"
    ok "nvim config installed (plugins download on first launch)"
  fi
fi

# ── bash ─────────────────────────────────────────────────────
if (( SHELLRC )); then
  step "Bash"
  touch "$HOME/.bashrc"
  if grep -q '# >>> nocturne >>>' "$HOME/.bashrc"; then
    ok "~/.bashrc already sources Nocturne"
  else
    [[ -e $BACKUP/.bashrc ]] || cp -a "$HOME/.bashrc" "$BACKUP/.bashrc"
    block=$'# >>> nocturne >>>\n[[ -r ~/.local/share/nocturne/shell/bashrc.bash ]] && source ~/.local/share/nocturne/shell/bashrc.bash\n# <<< nocturne <<<'
    if grep -qE '^[^#]*ble-attach' "$HOME/.bashrc"; then
      # ble.sh must attach last, so the block goes right before your ble-attach line
      BLOCK="$block" awk '!done && /^[^#]*ble-attach/ { print ENVIRON["BLOCK"]; print ""; done=1 } { print }' \
        "$HOME/.bashrc" > "$HOME/.bashrc.nocturne-tmp" && mv "$HOME/.bashrc.nocturne-tmp" "$HOME/.bashrc"
      ok "added a Nocturne block to ~/.bashrc, before your ble-attach line"
    else
      printf '\n%s\n' "$block" >> "$HOME/.bashrc"
      ok "added a Nocturne block to ~/.bashrc (removed again by the uninstaller)"
    fi
  fi
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) info "add ~/.local/bin to your PATH to use the 'nocturne' command" ;; esac
  if has atuin && [[ ! -f $NOCTURNE_STATE/atuin-imported ]]; then
    atuin import auto >/dev/null 2>&1 && touch "$NOCTURNE_STATE/atuin-imported" && ok "imported bash history into atuin (local only)"
  fi
  has tldr && (tldr --update >/dev/null 2>&1 &)
fi

# ── apply to the running desktop ─────────────────────────────
if (( ! SHELL_ONLY )); then
  step "Applying to Plasma"
  if (( LIVE )); then
    plasma-apply-colorscheme BreezeDark >/dev/null 2>&1 || true
    plasma-apply-colorscheme Nocturne >/dev/null && ok "colour scheme"
    plasma-apply-desktoptheme default >/dev/null 2>&1 && ok "Plasma style (Breeze, follows the colours)" || true
    icons=$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null || echo breeze-dark)
    for c in /usr/lib/plasma-changeicons /usr/libexec/plasma-changeicons /usr/lib/*/libexec/plasma-changeicons; do
      [[ -x $c ]] && { "$c" "$icons" >/dev/null 2>&1 && ok "icons: $icons"; break; }
    done
    cursor=$(kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme 2>/dev/null || true)
    [[ -n $cursor ]] && plasma-apply-cursortheme "$cursor" >/dev/null 2>&1 && ok "cursor: $cursor" || true
    wp=$(cat "$HOME/.config/nocturne/wallpaper" 2>/dev/null || echo "$WALL_DIR/nocturne.jpg")
    [[ -f $wp ]] && plasma-apply-wallpaperimage "$wp" >/dev/null && ok "wallpaper"
    if has flatpak; then
      flatpak override --user --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro \
        --filesystem=xdg-data/icons:ro >/dev/null 2>&1 && ok "Flatpak apps can read the GTK theme"
    fi
    if (( LAYOUT )); then
      if ask "Replace your panels with the Nocturne top bar + dock and add the desktop widgets? (your current layout is backed up)" y; then
        bash "$PREFIX/src/apply-layout.sh" | sed "s/^/  ${D}·${N} /" || warn "layout step failed — run 'nocturne layout' later"
      else info "kept your panels — run 'nocturne layout' any time"; fi
    fi
    (qdbus6 org.kde.KWin /KWin reconfigure || qdbus org.kde.KWin /KWin reconfigure) >/dev/null 2>&1 || true
  else
    info "not inside a Plasma session: settings are written and apply at next login"
    # write the colour groups into kdeglobals so the next login is already dark
    has plasma-apply-colorscheme && plasma-apply-colorscheme Nocturne >/dev/null 2>&1 && ok "colour scheme written"
    info "after logging in, run: nocturne rebuild$( ((LAYOUT)) && echo ' && nocturne layout')"
  fi
fi

# ── SDDM ─────────────────────────────────────────────────────
if (( SDDM )); then
  step "Login screen (SDDM)"
  if ! has sddm; then info "SDDM not installed — skipped"
  elif ! has sddm-greeter-qt6; then warn "needs SDDM 0.21+ with the Qt6 greeter — skipped"
  elif ask "Install the Nocturne login screen? (needs sudo)" y; then
    sudo bash "$PREFIX/src/install-sddm.sh" "$PREFIX/sddm-theme/nocturne" | sed "s/^/  ${D}·${N} /" \
      && touch "$NOCTURNE_STATE/sddm-installed" || warn "SDDM theme not installed"
  fi
fi

printf '\n%s☾  Nocturne is installed.%s\n' "$M" "$N"
(( SHELL_ONLY )) && info "Open a new terminal to see the prompt." \
  || info "Open a new terminal for the prompt. Log out and back in for fonts, splash and logout screen."
info "Manage it with: ${B}nocturne rebuild | layout | wallpaper <img> | sddm | uninstall${N}"
