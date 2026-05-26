#!/usr/bin/env zsh
# Non-interactive test suite for tpick.
# Run:  ./test.sh
#
# All state is kept in a temp dir — the real ~/.local/share/tpick and
# ~/.config/alacritty are NOT touched.

set -u
emulate -L zsh
setopt extended_glob

PASS=0
FAIL=0
typeset -a FAILED_TESTS

# ── Isolated environment ─────────────────────────────────────────────────────
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export TPICK_DIR="${TPICK_DIR:-$HOME/.tpick}"
export TPICK_THEMES_DIR="$TMP/themes"
export TPICK_FAVORITES="$TMP/favorites"
export TPICK_LAST_FILE="$TMP/last"
export TPICK_AUTO_DIR="$TMP/auto"
export TPICK_HISTORY_FILE="$TMP/history"
export TPICK_BRIGHTNESS_CACHE="$TMP/bcache.json"
export ALACRITTY_CONFIG="$TMP/alacritty.toml"

mkdir -p "$TPICK_THEMES_DIR"

# Three mock themes covering brightness extremes.
cat > "$TPICK_THEMES_DIR/dark_one.toml" <<'EOF'
[colors.primary]
background = "#111111"
foreground = "#eeeeee"

[colors.cursor]
cursor = "#eeeeee"
text   = "#111111"

[colors.selection]
background = "#222244"
text       = "#eeeeee"

[colors.normal]
black   = "#000000"
red     = "#ff0000"
green   = "#00ff00"
yellow  = "#ffff00"
blue    = "#0000ff"
magenta = "#ff00ff"
cyan    = "#00ffff"
white   = "#ffffff"

[colors.bright]
black   = "#444444"
red     = "#ff4444"
green   = "#44ff44"
yellow  = "#ffff44"
blue    = "#4444ff"
magenta = "#ff44ff"
cyan    = "#44ffff"
white   = "#ffffff"
EOF

cat > "$TPICK_THEMES_DIR/light_one.toml" <<'EOF'
[colors.primary]
background = "#eeeeee"
foreground = "#111111"

[colors.normal]
black = "#000000"
red   = "#aa0000"
green = "#00aa00"
EOF

cat > "$ALACRITTY_CONFIG" <<EOF
[general]
import = ["$TPICK_THEMES_DIR/dark_one.toml"]
EOF

# Load tpick. Silence sync hooks so tests don't talk to real nvim/tmux.
source "$TPICK_DIR/tpick.sh" 2>/dev/null
_tpick_sync_nvim() { :; }
_tpick_sync_tmux() { :; }

# ── Assertion helpers ────────────────────────────────────────────────────────
pass() {
  PASS=$((PASS+1))
  printf "  \033[32m✓\033[0m %s\n" "$1"
}
fail() {
  FAIL=$((FAIL+1))
  FAILED_TESTS+=("$1")
  printf "  \033[31m✗\033[0m %s\n" "$1"
  [[ -n "${2:-}" ]] && printf "      %s\n" "$2"
}
assert_eq() {
  if [[ "$3" == "$2" ]]; then pass "$1"; else fail "$1" "want '$2' got '$3'"; fi
}
assert_contains() {
  if [[ "$3" == *"$2"* ]]; then pass "$1"; else fail "$1" "missing '$2' in: $3"; fi
}
assert_file() {
  [[ -f "$2" ]] && pass "$1" || fail "$1" "missing file: $2"
}
assert_no_file() {
  [[ ! -e "$2" ]] && pass "$1" || fail "$1" "should not exist: $2"
}
assert_exit() {
  # $1=desc $2=expected $3...=command
  local d="$1" e="$2"; shift 2
  "$@" >/dev/null 2>&1
  local rc=$?
  if (( rc == e )); then pass "$d"; else fail "$d" "want exit $e, got $rc"; fi
}

# Run a tpick subcommand with EDITOR overridden to /usr/bin/true. We need a
# function (not `env`) because tpick is a shell function — env can't invoke it.
with_editor() {
  local saved="${EDITOR:-}"
  EDITOR=true "$@"
  local rc=$?
  EDITOR="$saved"
  return $rc
}

echo
echo "tpick test suite"
echo "================"

# ── current / info ───────────────────────────────────────────────────────────
echo
echo "[ current / info ]"
assert_eq "tpick current → dark_one" "dark_one" "$(tpick current)"

out=$(tpick info dark_one 2>&1)
assert_contains "tpick info: name printed"      "dark_one" "$out"
assert_contains "tpick info: background hex"    "#111111"  "$out"
assert_contains "tpick info: brightness dark"   "dark"     "$out"

out=$(tpick info 2>&1)
assert_contains "tpick info (no args) → current" "dark_one" "$out"

assert_exit "tpick info bogus → exit 1" 1 tpick info bogus_xyz

# ── last toggle ──────────────────────────────────────────────────────────────
echo
echo "[ last ]"
rm -f "$TPICK_LAST_FILE"
assert_exit "tpick last (no slot) → exit 1" 1 tpick last

# Seed the slot manually, then toggle.
printf '%s\n' "$TPICK_THEMES_DIR/light_one.toml" > "$TPICK_LAST_FILE"
out=$(tpick last 2>&1)
assert_contains "tpick last: light_one applied" "light_one" "$out"
assert_eq        "current is light_one"          "light_one" "$(tpick current)"

# Toggle should now bring dark_one back (since last was rotated).
out=$(tpick last 2>&1)
assert_contains "tpick last: dark_one returned" "dark_one" "$out"
assert_eq        "current is dark_one again"    "dark_one" "$(tpick current)"

# ── new / edit / remove ──────────────────────────────────────────────────────
echo
echo "[ new / edit / remove ]"
with_editor tpick new test_one >/dev/null
assert_file "tpick new creates file" "$TPICK_THEMES_DIR/test_one.toml"

assert_exit "tpick new with existing name → exit 1" 1 \
  with_editor tpick new test_one

assert_exit "tpick edit current → exit 0" 0 \
  with_editor tpick edit
assert_exit "tpick edit by name → exit 0" 0 \
  with_editor tpick edit test_one
assert_exit "tpick edit unknown → exit 1" 1 \
  with_editor tpick edit no_such_xyz

# Remove the test theme (confirm y).
echo "y" | tpick remove test_one >/dev/null 2>&1
assert_no_file "tpick remove deleted the file" "$TPICK_THEMES_DIR/test_one.toml"

# Should refuse to remove the currently-applied theme.
out=$(echo "y" | tpick remove dark_one 2>&1)
assert_contains "tpick remove blocks current" "active theme" "$out"

# Should refuse to remove "alacritty".
out=$(echo "y" | tpick remove alacritty 2>&1)
assert_contains "tpick remove refuses alacritty.toml" "refusing" "$out"

# ── history (MRU) ────────────────────────────────────────────────────────────
echo
echo "[ history ]"
assert_file "history file was populated by toggling" "$TPICK_HISTORY_FILE"

# First entry should be the most recent path.
first_history=$(head -1 "$TPICK_HISTORY_FILE")
assert_contains "history top is dark_one" "dark_one.toml" "$first_history"

# Listing should show recent themes first.
listing=$(python3 "$TPICK_DIR/list_themes.py" "$TMP" "" 2>&1)
first_line=$(printf '%s\n' "$listing" | head -1)
assert_contains "listing puts dark_one first" "dark_one" "$first_line"

# ── brightness cache ─────────────────────────────────────────────────────────
echo
echo "[ brightness cache ]"
rm -f "$TPICK_BRIGHTNESS_CACHE"
python3 "$TPICK_DIR/list_themes.py" "$TMP" "dark" >/dev/null
assert_file "cache file created after dark filter" "$TPICK_BRIGHTNESS_CACHE"

# Second invocation should not change file mtime since nothing new to compute.
sleep 1
mt_before=$(stat -f %m "$TPICK_BRIGHTNESS_CACHE")
python3 "$TPICK_DIR/list_themes.py" "$TMP" "dark" >/dev/null
mt_after=$(stat -f %m "$TPICK_BRIGHTNESS_CACHE")
assert_eq "cache mtime unchanged on second run" "$mt_before" "$mt_after"

# ── auto (macOS dark/light) ──────────────────────────────────────────────────
echo
echo "[ auto ]"
rm -rf "$TPICK_AUTO_DIR"

out=$(tpick auto status 2>&1)
assert_contains "auto status mentions appearance" "macOS appearance" "$out"
assert_contains "auto status: dark not set"       "not set"          "$out"

tpick auto set dark dark_one >/dev/null
assert_file "auto set dark wrote slot" "$TPICK_AUTO_DIR/dark"
tpick auto set light light_one >/dev/null
assert_file "auto set light wrote slot" "$TPICK_AUTO_DIR/light"

out=$(tpick auto status 2>&1)
assert_contains "auto status shows dark slot"  "dark_one"  "$out"
assert_contains "auto status shows light slot" "light_one" "$out"

assert_exit "tpick auto apply (no-op when matching) exit 0" 0 tpick auto

# auto set without args classifies current
tpick auto set >/dev/null
assert_file "auto set (no args) wrote a slot" "$TPICK_AUTO_DIR/dark"

# clear
tpick auto clear >/dev/null 2>&1
assert_no_file "auto clear removed dir" "$TPICK_AUTO_DIR"

# ── sync (bat / delta) ───────────────────────────────────────────────────────
echo
echo "[ sync ]"
out=$(tpick sync 2>&1)
assert_contains "sync status mentions bat"   "bat:"   "$out"
assert_contains "sync status mentions delta" "delta:" "$out"

# Without bat/delta installed in this environment, on/off should not error.
assert_exit "tpick sync on does not error"  0 tpick sync on
assert_exit "tpick sync off does not error" 0 tpick sync off

# ── export (kitty / ghostty) ─────────────────────────────────────────────────
echo
echo "[ export ]"
out=$(tpick export dark_one --kitty 2>&1)
assert_contains "export kitty: background line"  "background #111111" "$out"
assert_contains "export kitty: color0"           "color0 #000000"     "$out"
assert_contains "export kitty: color15"          "color15 #ffffff"    "$out"
assert_contains "export kitty: cursor mapping"   "cursor #eeeeee"     "$out"
assert_contains "export kitty: selection bg"     "selection_background #222244" "$out"

out=$(tpick export dark_one --ghostty 2>&1)
assert_contains "export ghostty: background"  "background = #111111" "$out"
assert_contains "export ghostty: palette syntax" "palette = 0=#000000" "$out"
assert_contains "export ghostty: cursor"      "cursor-color = #eeeeee" "$out"

out=$(tpick export 2>&1)
assert_contains "export missing format errors" "missing format" "$out"
out=$(tpick export bogus_xyz --kitty 2>&1)
assert_contains "export unknown theme errors" "not found" "$out"

# ── import (without args) ────────────────────────────────────────────────────
echo
echo "[ import ]"
out=$(tpick import 2>&1)
assert_contains "import without args shows usage" "usage" "$out"

# ── Summary ──────────────────────────────────────────────────────────────────
echo
echo "================"
printf "%s passed, %s failed\n" "$PASS" "$FAIL"
if (( FAIL > 0 )); then
  echo
  echo "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do
    printf "  - %s\n" "$t"
  done
  exit 1
fi
exit 0
