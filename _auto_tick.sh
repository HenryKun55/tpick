#!/bin/zsh
# Invoked periodically by launchd (see `tpick auto on`).
# Applies the tpick auto theme based on macOS appearance, but only if it
# differs from what's currently set — `_tpick_auto_apply` is a no-op on match.
#
# Why zsh and not bash: tpick.sh uses heredocs inside command substitutions
# (e.g. `bg=$(python3 - "$path" <<'EOF' ... EOF)`), which macOS's built-in
# bash 3.2 mis-parses. zsh (and modern bash) handle it fine.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
TPICK_DIR="${TPICK_DIR:-$HOME/.tpick}"
[ -f "$TPICK_DIR/tpick.sh" ] || exit 0
source "$TPICK_DIR/tpick.sh" 2>/dev/null
_tpick_auto_apply >>"${TPICK_AUTO_LOG:-/tmp/tpick-auto.log}" 2>&1
