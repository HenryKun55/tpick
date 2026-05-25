#!/usr/bin/env bash
# tpick — terminal theme picker
# https://github.com/HenryKun55/tpick

TPICK_DIR="${TPICK_DIR:-${HOME}/.tpick}"
TPICK_THEMES_DIR="${TPICK_THEMES_DIR:-${HOME}/.local/share/tpick/themes}"
TPICK_FAVORITES="${TPICK_FAVORITES:-${HOME}/.local/share/tpick/favorites}"
export TPICK_THEMES_DIR TPICK_FAVORITES

_tpick_have() { command -v "$1" &>/dev/null; }

# ── Terminal detection ────────────────────────────────────────────────────────

_tpick_detect_terminal() {
  [[ -n "$KITTY_PID" ]] && echo "kitty" && return
  case "${TERM_PROGRAM:-}" in
    alacritty) echo "alacritty" && return ;;
    kitty)     echo "kitty"     && return ;;
  esac
  [[ -f "${ALACRITTY_CONFIG:-${HOME}/.config/alacritty/alacritty.toml}" ]] && echo "alacritty" && return
  echo "unknown"
}

# ── Post-apply sync ───────────────────────────────────────────────────────────

_tpick_sync_nvim() {
  local theme_name="$1"
  _tpick_have nvim || return

  # Name mapping: Alacritty theme → Neovim colorscheme
  local cs
  case "$theme_name" in
    catppuccin_mocha|catppuccin_latte|catppuccin_frappe|catppuccin_macchiato|catppuccin)
                           cs="catppuccin" ;;
    dracula*)              cs="dracula" ;;
    nord*)                 cs="nord" ;;
    gruvbox*|gruvbox)      cs="gruvbox" ;;
    tokyonight*)           cs="tokyonight" ;;
    tokyonight_night)      cs="tokyonight-night" ;;
    onedark*)              cs="onedark" ;;
    everforest*)           cs="everforest" ;;
    rose_pine*)            cs="rose-pine" ;;
    kanagawa*)             cs="kanagawa" ;;
    nightfox*|dayfox*|duskfox*|nordfox*|carbonfox*|terafox*)
                           cs="${theme_name//_/-}" ;;
    *)                     cs="$theme_name" ;;
  esac

  # Find running nvim instances via socket (avoid globs — zsh throws on no match)
  local sock
  [[ -S "${NVIM:-}" ]] && \
    nvim --server "$NVIM" --remote-send ":colorscheme $cs<CR>" 2>/dev/null || true
  while IFS= read -r sock; do
    [[ -S "$sock" ]] || continue
    nvim --server "$sock" --remote-send ":colorscheme $cs<CR>" 2>/dev/null || true
  done < <(find /tmp "${XDG_RUNTIME_DIR:-/tmp}" -maxdepth 4 -name "0" -path "*/nvim*" 2>/dev/null)
}

_tpick_sync_tmux() {
  local theme_path="$1"
  _tpick_have tmux || return
  tmux list-sessions &>/dev/null || return

  local bg fg accent
  bg=$(python3 - "$theme_path" <<'EOF'
import re, sys
for line in open(sys.argv[1]):
    m = re.match(r'background\s*=\s*[\'"](\#[0-9a-fA-F]{6})[\'"]', line.strip())
    if m: print(m.group(1)); break
EOF
)
  fg=$(python3 - "$theme_path" <<'EOF'
import re, sys
for line in open(sys.argv[1]):
    m = re.match(r'foreground\s*=\s*[\'"](\#[0-9a-fA-F]{6})[\'"]', line.strip())
    if m: print(m.group(1)); break
EOF
)
  accent=$(python3 - "$theme_path" <<'EOF'
import re, sys
section = ""
for line in open(sys.argv[1]):
    line = line.strip()
    sm = re.match(r'^\[([^\]]+)\]', line)
    if sm: section = sm.group(1)
    if section == "colors.normal":
        m = re.match(r'blue\s*=\s*[\'"](\#[0-9a-fA-F]{6})[\'"]', line)
        if m: print(m.group(1)); break
EOF
)

  [[ -n "$bg" && -n "$fg" ]] && \
    tmux set-option -gq status-style "bg=${bg},fg=${fg}" 2>/dev/null
  [[ -n "$accent" ]] && \
    tmux set-option -gq pane-active-border-style "fg=${accent}" 2>/dev/null
  [[ -n "$accent" && -n "$bg" ]] && \
    tmux set-option -gq message-style "bg=${accent},fg=${bg}" 2>/dev/null
}

_tpick_sync() {
  local theme_path="$1"
  local theme_name
  theme_name=$(basename "$theme_path" .toml)

  _tpick_sync_nvim "$theme_name"
  _tpick_sync_tmux "$theme_path"

  # Custom hook: define tpick_on_change() in ~/.tpick/hooks.sh
  if [[ -f "${TPICK_DIR}/hooks.sh" ]]; then
    # shellcheck disable=SC1090
    source "${TPICK_DIR}/hooks.sh"
    declare -f tpick_on_change &>/dev/null && tpick_on_change "$theme_name" "$theme_path" 2>/dev/null
  fi
}

# ── Alacritty picker ──────────────────────────────────────────────────────────

_tpick_alacritty() {
  local config="${ALACRITTY_CONFIG:-${HOME}/.config/alacritty/alacritty.toml}"
  local config_dir
  config_dir=$(dirname "$config")
  local filter="${1:-}"   # --dark | --light | --favorites | ""

  [[ ! -f "$config" ]] && { echo "tpick: alacritty config not found: $config" >&2; return 1; }

  local set_py="$TPICK_DIR/set_theme.py"
  local preview_py="$TPICK_DIR/preview.py"
  local list_py="$TPICK_DIR/list_themes.py"
  local toggle_fav_py="$TPICK_DIR/toggle_fav.py"

  # Strip leading -- for python filter arg
  local filter_arg="${filter#--}"

  local theme_list
  theme_list=$(python3 "$list_py" "$config_dir" "$filter_arg")

  if [[ -z "$theme_list" ]]; then
    echo "tpick: no themes found${filter:+ matching '$filter'}." >&2
    [[ "$filter" == "--favorites" ]] && echo "  Use ctrl-f inside tpick to mark favorites." >&2
    [[ -z "$filter" ]] && echo "  Run 'tpick fetch' to download themes." >&2
    return 1
  fi

  local original
  original=$(grep '^import' "$config" 2>/dev/null | grep -oE '"[^"]*\.toml"' | tr -d '"')
  original="${original/#\~/$HOME}"

  local header
  case "$filter" in
    --dark)      header="dark themes  ·  " ;;
    --light)     header="light themes  ·  " ;;
    --favorites) header="★ favorites  ·  " ;;
    *)           header="" ;;
  esac
  header="${header}↑↓/Tab navigate  ·  Ctrl-D/U scroll  ·  Ctrl-F favorite  ·  Enter select  ·  Esc restore"

  local selected
  selected=$(
    echo "$theme_list" | \
    fzf \
      --ansi \
      --layout=reverse \
      --delimiter=$'\t' \
      --with-nth=1 \
      --preview "python3 $preview_py \$(echo {2})" \
      --preview-window="right:55%:wrap" \
      --bind "focus:execute-silent(python3 $set_py $config \$(echo {2}))" \
      --bind "tab:down,shift-tab:up" \
      --bind "ctrl-d:half-page-down,ctrl-u:half-page-up" \
      --bind "ctrl-f:execute-silent(python3 $toggle_fav_py \$(echo {2}))+reload(python3 $list_py $config_dir $filter_arg)" \
      --prompt "  Theme › " \
      --header "$header"
  )

  if [[ -n "$selected" ]]; then
    local selected_path
    selected_path=$(echo "$selected" | cut -f2)
    python3 "$set_py" "$config" "$selected_path"
    _tpick_sync "$selected_path"
    echo "  $(basename "$selected_path" .toml)"
  elif [[ -n "$original" ]]; then
    python3 "$set_py" "$config" "$original"
  fi
}

# ── Random ────────────────────────────────────────────────────────────────────

_tpick_random() {
  local config="${ALACRITTY_CONFIG:-${HOME}/.config/alacritty/alacritty.toml}"
  local config_dir
  config_dir=$(dirname "$config")
  local filter="${1:-}"
  local filter_arg="${filter#--}"

  [[ ! -f "$config" ]] && { echo "tpick: alacritty config not found: $config" >&2; return 1; }

  local chosen
  chosen=$(
    python3 "$TPICK_DIR/list_themes.py" "$config_dir" "$filter_arg" \
      | cut -f2 \
      | python3 -c "import sys,random; lines=[l.rstrip() for l in sys.stdin if l.strip()]; print(random.choice(lines)) if lines else sys.exit(1)"
  )

  if [[ -z "$chosen" ]]; then
    echo "tpick: no themes found${filter:+ matching '$filter'}." >&2
    return 1
  fi

  python3 "$TPICK_DIR/set_theme.py" "$config" "$chosen"
  _tpick_sync "$chosen"
  echo "  $(basename "$chosen" .toml)"
}

# ── Update ────────────────────────────────────────────────────────────────────

_tpick_update() {
  echo "  Updating tpick..."
  if git -C "$TPICK_DIR" pull --quiet 2>/dev/null; then
    echo "  ✓ tpick updated"
  else
    echo "  ✗ could not update (not a git repo or no remote)" >&2
  fi
  echo ""
  echo "  Checking for new themes..."
  python3 "$TPICK_DIR/fetch_themes.py"
}

# ── Current theme ─────────────────────────────────────────────────────────────

_tpick_current() {
  local terminal config line name
  terminal=$(_tpick_detect_terminal)

  case "$terminal" in
    alacritty)
      config="${ALACRITTY_CONFIG:-$HOME/.config/alacritty/alacritty.toml}"
      if [[ ! -f "$config" ]]; then
        echo "tpick: alacritty config not found: $config" >&2
        return 1
      fi
      # Parse com builtins só — não depende de grep/head/tr/basename.
      while IFS= read -r line; do
        [[ "$line" == *import*=*\"*.toml\"* ]] || continue
        name="${line#*\"}"   # tira tudo até a primeira aspas
        name="${name%%\"*}"  # tira da próxima aspas em diante
        name="${name##*/}"   # basename
        name="${name%.toml}" # tira extensão
        echo "$name"
        return 0
      done < "$config"
      echo "tpick: no theme import found in $config" >&2
      return 1
      ;;
    *)
      echo "tpick: 'current' is only supported for alacritty (detected: ${terminal:-none})" >&2
      return 1
      ;;
  esac
}

# ── Claude Code picker ────────────────────────────────────────────────────────

_tpick_claude() {
  local themes_dir="${HOME}/.claude/themes"
  local settings="${HOME}/.claude/settings.json"

  [[ ! -f "$settings" ]] && { echo "tpick: ~/.claude/settings.json not found" >&2; return 1; }

  mkdir -p "$themes_dir"

  local builtins="dark
light
dark-daltonism
light-daltonism"

  local theme_list
  theme_list=$(
    echo "$builtins" | while IFS= read -r t; do
      printf "  %s\t(built-in)\n" "$t"
    done
    find "$themes_dir" -maxdepth 1 -name "*.json" 2>/dev/null \
      | while IFS= read -r f; do
          local name; name=$(basename "$f" .json)
          printf "  custom:%s\t%s\n" "$name" "$f"
        done | sort
  )

  local original
  original=$(python3 -c "
import json
try:
  print(json.load(open('$settings')).get('theme','dark'))
except: print('dark')
" 2>/dev/null)

  local selected
  selected=$(
    echo "$theme_list" | \
    fzf \
      --ansi \
      --layout=reverse \
      --delimiter=$'\t' \
      --with-nth=1 \
      --preview "python3 $TPICK_DIR/preview_claude.py {1} {2}" \
      --preview-window="right:50%:wrap" \
      --bind "focus:execute-silent(python3 $TPICK_DIR/set_claude_theme.py $settings \$(echo {1} | xargs))" \
      --bind "tab:down,shift-tab:up" \
      --bind "ctrl-d:half-page-down,ctrl-u:half-page-up" \
      --prompt "  Claude Code Theme › " \
      --header $'↑↓/Tab navigate  ·  Enter select  ·  Esc restore'
  )

  if [[ -n "$selected" ]]; then
    local theme_name
    theme_name=$(echo "$selected" | cut -f1 | xargs)
    python3 "$TPICK_DIR/set_claude_theme.py" "$settings" "$theme_name"
    echo "  $theme_name (restart Claude Code to apply)"
  else
    python3 "$TPICK_DIR/set_claude_theme.py" "$settings" "$original"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

tpick() {
  if ! _tpick_have fzf; then
    echo "tpick: fzf is required" >&2
    echo "  macOS:  brew install fzf" >&2
    echo "  Linux:  sudo apt install fzf  /  sudo pacman -S fzf" >&2
    return 1
  fi
  if ! _tpick_have python3; then
    echo "tpick: python3 is required" >&2
    return 1
  fi

  case "${1:-}" in
    fetch)
      python3 "$TPICK_DIR/fetch_themes.py" "${@:2}"
      ;;
    random)
      _tpick_random "${2:-}"
      ;;
    update)
      _tpick_update
      ;;
    current)
      _tpick_current
      ;;
    fav|favs|favorites)
      if [[ -f "$TPICK_FAVORITES" ]] && [[ -s "$TPICK_FAVORITES" ]]; then
        echo "  Favorites:"
        sed 's/^/    ★ /' "$TPICK_FAVORITES"
      else
        echo "  No favorites yet. Use Ctrl-F inside tpick to mark themes."
      fi
      ;;
    --favorites|-f)
      _tpick_alacritty --favorites
      ;;
    --dark)
      _tpick_alacritty --dark
      ;;
    --light)
      _tpick_alacritty --light
      ;;
    --alacritty|-a)
      _tpick_alacritty
      ;;
    --claude|-c)
      _tpick_claude
      ;;
    --help|-h|help)
      cat <<'EOF'
tpick — terminal theme picker

USAGE
  tpick                  Auto-detect terminal and open picker
  tpick --dark           Show only dark themes
  tpick --light          Show only light themes
  tpick --favorites      Show only favorited themes
  tpick random           Apply a random theme
  tpick random --dark    Apply a random dark theme
  tpick random --light   Apply a random light theme
  tpick fav              List your favorites
  tpick current          Print the currently applied theme name
  tpick fetch            Download themes from alacritty/alacritty-theme
  tpick update           Update tpick and download new themes
  tpick --alacritty      Force Alacritty mode
  tpick --claude         Claude Code theme picker

CONTROLS (inside picker)
  ↑↓ / Tab       Navigate (theme applies live)
  Ctrl-D / U     Scroll half-page down / up
  Ctrl-F         Toggle favorite ★
  Enter          Confirm selection
  Esc            Cancel and restore original theme
  /              Search by name

SYNC
  After selecting a theme, tpick automatically syncs:
  - Neovim  (sends :colorscheme via --server)
  - tmux    (updates status bar colors)
  Custom:   define tpick_on_change() in ~/.tpick/hooks.sh

ENVIRONMENT
  TPICK_DIR          install dir       (default: ~/.tpick)
  TPICK_THEMES_DIR   downloaded themes (default: ~/.local/share/tpick/themes)
  TPICK_FAVORITES    favorites file    (default: ~/.local/share/tpick/favorites)
  ALACRITTY_CONFIG   config path       (default: ~/.config/alacritty/alacritty.toml)

EOF
      ;;
    "")
      local terminal
      terminal=$(_tpick_detect_terminal)
      case "$terminal" in
        alacritty) _tpick_alacritty ;;
        kitty)
          echo "tpick: kitty support coming soon. Use tpick --alacritty to force Alacritty mode." >&2
          return 1
          ;;
        *)
          echo "tpick: could not detect a supported terminal." >&2
          echo "  Supported: alacritty" >&2
          echo "  Force with: tpick --alacritty" >&2
          return 1
          ;;
      esac
      ;;
    *)
      echo "tpick: unknown option '$1'. Try: tpick --help" >&2
      return 1
      ;;
  esac
}
