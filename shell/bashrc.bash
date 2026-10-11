# Nocturne shell setup — sourced from ~/.bashrc by nocturne-kde.
# Works with or without ble.sh / starship / any of the tools: each piece is optional.

[[ $- == *i* ]] || return

# ── ble.sh (syntax highlighting, autosuggestions) — only if not already loaded ──
__noc_ble_attach=
if [[ ! ${BLE_VERSION-} ]]; then
  for __f in /usr/share/blesh/ble.sh /usr/local/share/blesh/ble.sh "$HOME/.local/share/blesh/ble.sh"; do
    if [[ -r $__f ]]; then source "$__f" --noattach && __noc_ble_attach=1; break; fi
  done
  unset __f
fi

# ── History ─────────────────────────────────────────────
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend checkwinsize autocd cdspell globstar 2>/dev/null

# ── Environment ─────────────────────────────────────────
__has() { command -v "$1" >/dev/null 2>&1; }
__has nvim && export EDITOR=nvim VISUAL=nvim
__has bat && export MANPAGER="sh -c 'col -bx | bat -l man -p'" MANROFFOPT="-c"
# generated colours: LS_COLORS, FZF_*, BAT_THEME, EZA_CONFIG_DIR
[[ -r ~/.config/nocturne/env.bash ]] && source ~/.config/nocturne/env.bash

# ── Aliases ─────────────────────────────────────────────
if __has eza; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -l --icons=auto --group-directories-first --git --time-style=relative'
  alias la='ll -a'
  alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
else
  alias ls='ls --color=auto --group-directories-first'
  alias ll='ls -lh' la='ls -lAh'
fi
__has bat       && alias cat='bat -pp'
__has nvim      && alias vim='nvim' v='nvim'
__has btop      && alias top='btop'
__has lazygit   && alias lg='lazygit'
__has eva       && alias calc='eva'
__has fastfetch && alias ff='fastfetch'
alias grep='grep --color=auto'
alias ..='cd ..' ...='cd ../..'

# yazi: `y` opens the file manager and cd's to wherever you quit
if __has yazi; then
  y() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)"
    yazi "$@" --cwd-file="$tmp"
    cwd="$(<"$tmp")" && [[ -n $cwd && $cwd != "$PWD" ]] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
  }
fi

# ── ble.sh look & behaviour ─────────────────────────────
if declare -F ble-face >/dev/null; then
  bleopt char_width_mode=west          # box-drawing & Nerd Font glyphs are 1 cell
  bleopt exec_errexit_mark=            # the prompt already shows exit status
  bleopt exec_elapsed_mark=            # the prompt already shows duration
  __has starship && bleopt prompt_ps1_final='$(starship module character)'   # transient prompt
  [[ -r ~/.config/nocturne/ble.bash ]] && source ~/.config/nocturne/ble.bash
fi

# ── Prompt ──────────────────────────────────────────────
if __has starship; then
  eval "$(starship init bash)"
  # ble.sh already attached earlier in ~/.bashrc? Then it would draw the first prompt
  # from the old PS1 — render the Starship prompt now.
  [[ ${BLE_ATTACHED-} ]] && declare -F starship_precmd >/dev/null && starship_precmd
else
  PS1='\[\e[38;2;61;219;181m\]\w\[\e[0m\] \[\e[1;38;2;61;219;181m\]❯\[\e[0m\] '
fi

# ── Tools ───────────────────────────────────────────────
__has zoxide && eval "$(zoxide init bash)"            # z <dir>, zi = interactive
if __has fzf; then                                     # Ctrl-T files, Alt-C dirs, ** completion
  if declare -F ble-import >/dev/null; then
    ble-import -d integration/fzf-completion
    ble-import integration/fzf-key-bindings
  elif fzf --bash >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  fi
fi
__has atuin && eval "$(atuin init bash --disable-up-arrow)"   # Ctrl-R history search

unset -f __has
[[ $__noc_ble_attach ]] && ble-attach
unset __noc_ble_attach
