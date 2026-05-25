#!/usr/bin/env bash
set -e

REPO="https://github.com/HenryKun55/tpick"
INSTALL_DIR="${TPICK_DIR:-$HOME/.tpick}"

_have() { command -v "$1" &>/dev/null; }

echo "  tpick installer"
echo "  ─────────────────────────────"

# Check dependencies
if ! _have fzf; then
  echo ""
  echo "  fzf is required but not found."
  if _have brew; then
    read -rp "  Install with brew? [Y/n] " yn
    [[ "${yn:-Y}" =~ ^[Yy]$ ]] && brew install fzf
  else
    echo "  Install fzf: https://github.com/junegunn/fzf#installation"
    exit 1
  fi
fi

if ! _have python3; then
  echo "  python3 is required but not found. Please install it first."
  exit 1
fi

# Clone or update
if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo "  Updating tpick at $INSTALL_DIR..."
  git -C "$INSTALL_DIR" pull --quiet
else
  echo "  Installing tpick to $INSTALL_DIR..."
  git clone --quiet "$REPO" "$INSTALL_DIR"
fi

# Detect shell config file
detect_shell_config() {
  local shell_name
  shell_name=$(basename "${SHELL:-bash}")
  case "$shell_name" in
    zsh)
      [[ -f "$HOME/.zshrc" ]] && echo "$HOME/.zshrc" || echo "$HOME/.zprofile"
      ;;
    bash)
      [[ -f "$HOME/.bashrc" ]] && echo "$HOME/.bashrc" || echo "$HOME/.bash_profile"
      ;;
    *)
      echo "$HOME/.profile"
      ;;
  esac
}

SOURCE_LINE="source \"$INSTALL_DIR/tpick.sh\""
SHELL_CONFIG=$(detect_shell_config)

if grep -qF "tpick.sh" "$SHELL_CONFIG" 2>/dev/null; then
  echo "  tpick already sourced in $SHELL_CONFIG"
else
  echo "" >> "$SHELL_CONFIG"
  echo "# tpick — terminal theme picker" >> "$SHELL_CONFIG"
  echo "$SOURCE_LINE" >> "$SHELL_CONFIG"
  echo "  Added to $SHELL_CONFIG"
fi

echo ""
echo "  Done! Restart your shell or run:"
echo "    source $SHELL_CONFIG"
echo ""
echo "  Then:"
echo "    tpick fetch   # download 174 themes"
echo "    tpick         # open the picker"
