#!/usr/bin/env bash
set -e

REPO="https://github.com/HenryKun55/tpick"
INSTALL_DIR="${TPICK_DIR:-$HOME/.tpick}"

_have() { command -v "$1" &>/dev/null; }
_ok()   { echo "  ✓  $*"; }
_warn() { echo "  ⚠  $*"; }
_info() { echo "     $*"; }

echo ""
echo "  tpick — terminal theme picker"
echo "  ────────────────────────────────────"
echo ""

# ── Dependencies ──────────────────────────────────────────────────────────────

if ! _have python3; then
  echo "  python3 is required but not found. Please install it first."
  exit 1
fi
_ok "python3 found"

if ! _have git; then
  echo "  git is required but not found. Please install it first."
  exit 1
fi
_ok "git found"

if ! _have fzf; then
  _warn "fzf not found (required for the picker)"
  if _have brew; then
    read -rp "     Install with brew now? [Y/n] " yn
    [[ "${yn:-Y}" =~ ^[Yy]$ ]] && brew install fzf || { echo "  Install fzf: https://github.com/junegunn/fzf"; exit 1; }
  elif _have apt-get; then
    read -rp "     Install with apt now? [Y/n] " yn
    [[ "${yn:-Y}" =~ ^[Yy]$ ]] && sudo apt-get install -y fzf || exit 1
  elif _have pacman; then
    read -rp "     Install with pacman now? [Y/n] " yn
    [[ "${yn:-Y}" =~ ^[Yy]$ ]] && sudo pacman -S --noconfirm fzf || exit 1
  else
    _info "Install fzf: https://github.com/junegunn/fzf#installation"
    exit 1
  fi
fi
_ok "fzf found"

echo ""

# ── Clone / update ────────────────────────────────────────────────────────────

if [[ -d "$INSTALL_DIR/.git" ]]; then
  _ok "Updating tpick at $INSTALL_DIR"
  git -C "$INSTALL_DIR" pull --quiet
else
  _ok "Installing tpick to $INSTALL_DIR"
  git clone --quiet "$REPO" "$INSTALL_DIR"
fi

echo ""

# ── Terminal detection ────────────────────────────────────────────────────────

ALACRITTY_CONFIG="${ALACRITTY_CONFIG:-$HOME/.config/alacritty/alacritty.toml}"
DETECTED_TERMINAL="none"

if [[ -f "$ALACRITTY_CONFIG" ]]; then
  DETECTED_TERMINAL="alacritty"
  _ok "Alacritty detected: $ALACRITTY_CONFIG"

  # Ensure live_config_reload is enabled (required for live preview)
  if grep -q 'live_config_reload' "$ALACRITTY_CONFIG"; then
    _ok "live_config_reload already set"
  else
    echo "" >> "$ALACRITTY_CONFIG"
    echo "live_config_reload = true" >> "$ALACRITTY_CONFIG"
    _ok "Added live_config_reload = true to alacritty.toml"
    _info "(this is required for the live preview to work)"
  fi
else
  _warn "No supported terminal config found"
  _info "Alacritty config not found at: $ALACRITTY_CONFIG"
  _info "If your config is in a different location, set ALACRITTY_CONFIG before running tpick"
  _info "Example: export ALACRITTY_CONFIG=~/.config/alacritty/alacritty.toml"
fi

echo ""

# ── Shell integration ─────────────────────────────────────────────────────────

detect_shell_config() {
  case "$(basename "${SHELL:-bash}")" in
    zsh)  [[ -f "$HOME/.zshrc" ]] && echo "$HOME/.zshrc" || echo "$HOME/.zprofile" ;;
    bash) [[ -f "$HOME/.bashrc" ]] && echo "$HOME/.bashrc" || echo "$HOME/.bash_profile" ;;
    *)    echo "$HOME/.profile" ;;
  esac
}

SHELL_CONFIG=$(detect_shell_config)
SOURCE_LINE="source \"$INSTALL_DIR/tpick.sh\""

if grep -qF "tpick.sh" "$SHELL_CONFIG" 2>/dev/null; then
  _ok "tpick already sourced in $SHELL_CONFIG"
else
  { echo ""; echo "# tpick — terminal theme picker"; echo "$SOURCE_LINE"; } >> "$SHELL_CONFIG"
  _ok "Added to $SHELL_CONFIG"
fi

echo ""

# ── Offer to download themes ──────────────────────────────────────────────────

read -rp "  Download 174 themes now? [Y/n] " yn
if [[ "${yn:-Y}" =~ ^[Yy]$ ]]; then
  echo ""
  python3 "$INSTALL_DIR/fetch_themes.py"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "  ────────────────────────────────────"
echo "  All done! Restart your shell or run:"
echo ""
echo "    source $SHELL_CONFIG"
echo ""
echo "  Then just run:"
echo ""
echo "    tpick"
echo ""
[[ "$DETECTED_TERMINAL" == "none" ]] && _warn "No terminal was detected — run 'tpick --alacritty' to force Alacritty mode"
