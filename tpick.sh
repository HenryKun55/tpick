#!/usr/bin/env bash
# tpick — terminal theme picker
# https://github.com/HenryKun55/tpick

TPICK_DIR="${TPICK_DIR:-${HOME}/.tpick}"
TPICK_THEMES_DIR="${TPICK_THEMES_DIR:-${HOME}/.local/share/tpick/themes}"

_tpick_have() { command -v "$1" &>/dev/null; }

_tpick_detect_terminal() {
  [[ -n "$KITTY_PID" ]] && echo "kitty" && return
  case "${TERM_PROGRAM:-}" in
    alacritty) echo "alacritty" && return ;;
    kitty)     echo "kitty"     && return ;;
  esac
  # Alacritty fallback: check config existence
  [[ -f "${HOME}/.config/alacritty/alacritty.toml" ]] && echo "alacritty" && return
  echo "unknown"
}

_tpick_alacritty() {
  local config="${ALACRITTY_CONFIG:-${HOME}/.config/alacritty/alacritty.toml}"
  local config_dir
  config_dir=$(dirname "$config")

  [[ ! -f "$config" ]] && { echo "tpick: alacritty config not found: $config" >&2; return 1; }

  local set_py="$TPICK_DIR/set_theme.py"
  local preview_py="$TPICK_DIR/preview.py"

  local theme_list
  theme_list=$(
    {
      find "$config_dir" -maxdepth 1 -name "*.toml" ! -name "alacritty.toml" \
        | while IFS= read -r f; do printf "%s\t%s\n" "$(basename "$f")" "$f"; done
      [[ -d "$TPICK_THEMES_DIR" ]] && \
        find "$TPICK_THEMES_DIR" -maxdepth 1 -name "*.toml" \
          | while IFS= read -r f; do printf "%s\t%s\n" "$(basename "$f")" "$f"; done
    } | sort -u
  )

  if [[ -z "$theme_list" ]]; then
    echo "tpick: no themes found. Run 'tpick fetch' to download themes." >&2
    return 1
  fi

  local original
  original=$(grep '^import' "$config" 2>/dev/null | grep -oE '"[^"]*\.toml"' | tr -d '"')
  original="${original/#\~/$HOME}"

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
      --prompt "  Theme › " \
      --header $'↑↓/Tab  navigate  ·  Ctrl-D/U  scroll fast  ·  Enter  select  ·  Esc  restore'
  )

  if [[ -n "$selected" ]]; then
    local selected_path
    selected_path=$(echo "$selected" | cut -f2)
    python3 "$set_py" "$config" "$selected_path"
    echo "  $(basename "$selected_path" .toml)"
  elif [[ -n "$original" ]]; then
    python3 "$set_py" "$config" "$original"
  fi
}

_tpick_claude() {
  local themes_dir="${HOME}/.claude/themes"
  local settings="${HOME}/.claude/settings.json"
  local set_py="$TPICK_DIR/set_claude_theme.py"
  local preview_py="$TPICK_DIR/preview_claude.py"

  [[ ! -f "$settings" ]] && { echo "tpick: ~/.claude/settings.json not found" >&2; return 1; }

  mkdir -p "$themes_dir"

  # Built-in themes (always available)
  local builtins="dark
light
dark-daltonism
light-daltonism"

  # Custom themes from ~/.claude/themes/
  local custom_themes=""
  if [[ -d "$themes_dir" ]]; then
    custom_themes=$(find "$themes_dir" -maxdepth 1 -name "*.json" \
      | while IFS= read -r f; do
          local name; name=$(basename "$f" .json)
          printf "custom:%s\t%s\n" "$name" "$f"
        done | sort)
  fi

  local theme_list
  theme_list=$(
    echo "$builtins" | while IFS= read -r t; do printf "%s\t(built-in)\n" "$t"; done
    [[ -n "$custom_themes" ]] && echo "$custom_themes"
  )

  local original
  original=$(python3 -c "
import json, sys
try:
  s = json.load(open('$settings'))
  print(s.get('theme','dark'))
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
      --preview "python3 $preview_py {1} {2}" \
      --preview-window="right:50%:wrap" \
      --bind "focus:execute-silent(python3 $set_py $settings {1})" \
      --bind "tab:down,shift-tab:up" \
      --bind "ctrl-d:half-page-down,ctrl-u:half-page-up" \
      --prompt "  Claude Code Theme › " \
      --header $'↑↓/Tab  navigate  ·  Enter  select  ·  Esc  restore'
  )

  if [[ -n "$selected" ]]; then
    local theme_name
    theme_name=$(echo "$selected" | cut -f1)
    python3 "$set_py" "$settings" "$theme_name"
    echo "  $theme_name (restart Claude Code to apply)"
  else
    python3 "$set_py" "$settings" "$original"
  fi
}

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
  tpick              Auto-detect terminal and open picker
  tpick fetch        Download 174 themes from alacritty/alacritty-theme
  tpick --alacritty  Force Alacritty mode

CONTROLS
  ↑↓ / Tab    Navigate (live preview updates as you move)
  Ctrl-D/U    Scroll half-page down/up (fast browsing)
  Enter       Confirm selection
  Esc         Cancel and restore original theme
  /           Search by name

ENVIRONMENT
  TPICK_DIR         tpick install dir     (default: ~/.tpick)
  TPICK_THEMES_DIR  downloaded themes dir (default: ~/.local/share/tpick/themes)
  ALACRITTY_CONFIG  alacritty config path (default: ~/.config/alacritty/alacritty.toml)

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
