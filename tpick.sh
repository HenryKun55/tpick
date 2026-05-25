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

  # Snapshot the FULL alacritty.toml before opening the picker.
  # We also extract the import path for the Ctrl-X "protected" check.
  # The full snapshot is what we'll restore on cancel — restoring just the
  # import line is racy because focus:execute-silent runs async, and a stray
  # set_theme.py finishing AFTER our restore would overwrite us.
  local original_config
  original_config="$(<"$config")"

  local original="" line
  while IFS= read -r line; do
    [[ "$line" == *import*=*\"*.toml\"* ]] || continue
    original="${line#*\"}"
    original="${original%%\"*}"
    break
  done <<< "$original_config"
  original="${original/#\~/$HOME}"

  local header
  case "$filter" in
    --dark)      header="dark themes  ·  " ;;
    --light)     header="light themes  ·  " ;;
    --favorites) header="★ favorites  ·  " ;;
    *)           header="" ;;
  esac
  header="${header}↑↓/Tab navigate  ·  Ctrl-F favorite  ·  Ctrl-N new  ·  Ctrl-X remove  ·  Enter select  ·  Esc restore"

  local new_py="$TPICK_DIR/_new_theme.py"
  local remove_py="$TPICK_DIR/_remove_theme.py"

  # We avoid execute() for Ctrl-N/Ctrl-X because in some terminals fzf doesn't
  # survive when the child receives SIGINT (Ctrl-C inside the helper takes the
  # picker down too). Instead we use --expect: fzf exits cleanly on those keys,
  # the helper runs in the normal shell, and the loop re-opens the picker.
  local current_query="" out key sel selected_path
  while true; do
    out=$(
      echo "$theme_list" | \
      fzf \
        --ansi \
        --layout=reverse \
        --delimiter=$'\t' \
        --with-nth=1 \
        --preview "python3 $preview_py \$(echo {2})" \
        --preview-window="right:55%:wrap" \
        --expect "ctrl-n,ctrl-x" \
        --bind "focus:execute-silent(python3 $set_py $config \$(echo {2}))" \
        --bind "tab:down,shift-tab:up" \
        --bind "ctrl-d:half-page-down,ctrl-u:half-page-up" \
        --bind "ctrl-f:execute-silent(python3 $toggle_fav_py \$(echo {2}))+reload(python3 $list_py $config_dir $filter_arg)" \
        --prompt "  Theme › " \
        --header "$header" \
        --query "$current_query" \
        --print-query
    )
    # --print-query: query is line 1
    # --expect:      key (or empty for Enter) is line 2
    # selection:                              is line 3 (empty on Esc/Ctrl-C)
    current_query=$(echo "$out" | sed -n 1p)
    key=$(echo "$out"            | sed -n 2p)
    sel=$(echo "$out"            | sed -n 3p)

    case "$key" in
      ctrl-n)
        if [[ -n "$sel" ]]; then
          pkill -f "${TPICK_DIR}/set_theme.py" 2>/dev/null
          sleep 0.1
          local src_path="${sel#*$'\t'}"
          python3 "$new_py" "$src_path"
        fi
        # Refresh list (in case a new theme was created) and reopen.
        theme_list=$(python3 "$list_py" "$config_dir" "$filter_arg")
        continue
        ;;
      ctrl-x)
        if [[ -n "$sel" ]]; then
          pkill -f "${TPICK_DIR}/set_theme.py" 2>/dev/null
          sleep 0.1
          local tgt_path="${sel#*$'\t'}"
          python3 "$remove_py" "$tgt_path" "$original"
        fi
        # If the user just removed the theme being live-previewed, restore the
        # snapshot so we don't reopen pointing at a missing file.
        if [[ ! -f "$original" ]] || [[ "$(<"$config")" != "$original_config" ]]; then
          printf '%s' "$original_config" > "$config"
        fi
        theme_list=$(python3 "$list_py" "$config_dir" "$filter_arg")
        continue
        ;;
      "")
        # Enter (sel set) or Esc/Ctrl-C (sel empty)
        break
        ;;
    esac
  done

  if [[ -n "$sel" ]]; then
    selected_path="${sel#*$'\t'}"
    pkill -f "${TPICK_DIR}/set_theme.py" 2>/dev/null
    sleep 0.1
    python3 "$set_py" "$config" "$selected_path"
    _tpick_sync "$selected_path"
    local sel_name="${selected_path##*/}"
    echo "  ${sel_name%.toml}"
  else
    # Cancelled — restore snapshot verbatim.
    pkill -f "${TPICK_DIR}/set_theme.py" 2>/dev/null
    sleep 0.15
    printf '%s' "$original_config" > "$config"
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

# ── New custom theme (copy + open in editor) ──────────────────────────────────
# Shell wrapper: figures out the current theme path and delegates to the Python
# helper, which does the prompt + copy + editor flow.

_tpick_new() {
  local preset_name="${1:-}"

  local config="${ALACRITTY_CONFIG:-$HOME/.config/alacritty/alacritty.toml}"
  if [[ ! -f "$config" ]]; then
    echo "tpick: alacritty config not found: $config" >&2
    return 1
  fi

  # Extract the currently-imported theme path (builtins only).
  local line src=""
  while IFS= read -r line; do
    [[ "$line" == *import*=*\"*.toml\"* ]] || continue
    src="${line#*\"}"
    src="${src%%\"*}"
    break
  done < "$config"

  if [[ -z "$src" ]]; then
    echo "tpick new: no theme import found in $config" >&2
    return 1
  fi
  src="${src/#\~/$HOME}"

  if [[ ! -f "$src" ]]; then
    echo "tpick new: source theme file not found: $src" >&2
    return 1
  fi

  if [[ -n "$preset_name" ]]; then
    python3 "$TPICK_DIR/_new_theme.py" "$src" "$preset_name"
  else
    python3 "$TPICK_DIR/_new_theme.py" "$src"
  fi
}

# ── Remove theme ──────────────────────────────────────────────────────────────
# Shell wrapper:
#   - With a name arg: locates the file and delegates to _remove_theme.py.
#   - Without args: opens a small fzf picker to choose the theme to remove.

_tpick_remove() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    _tpick_remove_picker
    return
  fi
  name="${name%.toml}"

  if [[ "$name" == "alacritty" ]]; then
    echo "tpick remove: refusing to remove 'alacritty.toml' (the config itself)" >&2
    return 1
  fi

  local config="${ALACRITTY_CONFIG:-$HOME/.config/alacritty/alacritty.toml}"
  local config_dir="${config%/*}"
  local themes_dir="${TPICK_THEMES_DIR:-$HOME/.local/share/tpick/themes}"

  local target="" dir
  for dir in "$themes_dir" "$config_dir"; do
    if [[ -f "$dir/$name.toml" ]]; then
      target="$dir/$name.toml"
      break
    fi
  done
  if [[ -z "$target" ]]; then
    echo "tpick remove: theme '$name' not found" >&2
    echo "  Checked: $themes_dir, $config_dir" >&2
    return 1
  fi

  # Pass the currently-applied path as "protected" so the helper blocks if it matches.
  local protected="" line
  while IFS= read -r line; do
    [[ "$line" == *import*=*\"*.toml\"* ]] || continue
    protected="${line#*\"}"
    protected="${protected%%\"*}"
    break
  done < "$config"

  python3 "$TPICK_DIR/_remove_theme.py" "$target" "$protected"
}

_tpick_remove_picker() {
  if ! _tpick_have fzf; then
    echo "tpick: fzf required" >&2
    return 1
  fi
  if ! _tpick_have python3; then
    echo "tpick: python3 required" >&2
    return 1
  fi

  local config="${ALACRITTY_CONFIG:-$HOME/.config/alacritty/alacritty.toml}"
  local config_dir="${config%/*}"
  local list_py="$TPICK_DIR/list_themes.py"
  local preview_py="$TPICK_DIR/preview.py"
  local remove_py="$TPICK_DIR/_remove_theme.py"

  local current
  current=$(_tpick_current 2>/dev/null)

  local theme_list
  theme_list=$(python3 "$list_py" "$config_dir" "")

  if [[ -z "$theme_list" ]]; then
    echo "tpick remove: no themes found." >&2
    return 1
  fi

  # Hide the currently-applied theme from the removal list.
  if [[ -n "$current" ]]; then
    local filtered="" line
    while IFS= read -r line; do
      [[ "$line" == *"/${current}.toml" ]] && continue
      filtered+="$line"$'\n'
    done <<< "$theme_list"
    theme_list="${filtered%$'\n'}"
  fi

  if [[ -z "$theme_list" ]]; then
    echo "tpick remove: nothing to remove (only the current theme exists)." >&2
    return 1
  fi

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
      --prompt "  Remove › " \
      --header "Pick a theme to remove  ·  Enter confirm  ·  Esc cancel  ·  (current theme hidden)"
  )

  [[ -z "$selected" ]] && { echo "  cancelled"; return 0; }

  local target
  target="${selected#*$'\t'}"

  python3 "$remove_py" "$target"
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
    new)
      _tpick_new "${2:-}"
      ;;
    remove|rm)
      _tpick_remove "${2:-}"
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
  tpick new [name]       Copy current theme as a new one and open in $EDITOR
  tpick remove [name]    Remove a theme file (asks confirmation)
  tpick fetch            Download themes from alacritty/alacritty-theme
  tpick update           Update tpick and download new themes
  tpick --alacritty      Force Alacritty mode
  tpick --claude         Claude Code theme picker

CONTROLS (inside picker)
  ↑↓ / Tab       Navigate (theme applies live)
  Ctrl-D / U     Scroll half-page down / up
  Ctrl-F         Toggle favorite ★
  Ctrl-N         New theme — copy focused one and open in $EDITOR
  Ctrl-X         Remove focused theme (asks confirmation)
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
