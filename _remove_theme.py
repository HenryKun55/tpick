#!/usr/bin/env python3
"""Remove a theme file. Used by tpick (Ctrl-X in picker, or `tpick remove`).

Usage:
    _remove_theme.py <theme_path> [protected_path] [--wait]

If protected_path is given and resolves to the same file as theme_path, the
removal is refused (protects the user's original theme inside the live-preview
picker).

--wait: pause for Enter at the end, so the user can read the output before
control returns to the caller. Use when invoked from inside fzf's execute().
"""
import os, sys

args = [a for a in sys.argv[1:] if a != "--wait"]
WAIT = "--wait" in sys.argv

if not args:
    print("  usage: _remove_theme.py <theme_path> [protected_path] [--wait]")
    if WAIT: input("  Press Enter to continue...")
    sys.exit(1)

target = args[0]
protected = args[1] if len(args) > 1 else ""
favs_file = os.environ.get(
    "TPICK_FAVORITES",
    os.path.expanduser("~/.local/share/tpick/favorites"),
)

target_name = os.path.basename(target)

def fail(msg):
    print(f"  {msg}")
    if WAIT: input("  Press Enter to continue...")
    sys.exit(1)

if not os.path.isfile(target):
    fail(f"theme not found: {target}")

if target_name == "alacritty.toml":
    fail("refusing to remove 'alacritty.toml' (the config itself)")

# Protect the theme that was active when the picker opened.
if protected:
    try:
        same = os.path.samefile(target, os.path.expanduser(protected))
    except (FileNotFoundError, OSError):
        same = False
    if same:
        print(f"  '{target_name}' was the active theme when you opened tpick.")
        print("  Apply a different theme first (Enter on it), then remove this one.")
        if WAIT: input("  Press Enter to continue...")
        sys.exit(1)

try:
    yn = input(f"  Remove {target_name}? [y/N] ").strip().lower()
except EOFError:
    yn = ""

if yn not in ("y", "yes"):
    print("  aborted")
    if WAIT: input("  Press Enter to continue...")
    sys.exit(1)

try:
    os.remove(target)
    print(f"  ✓ removed {target}")
except Exception as e:
    fail(f"failed to remove: {e}")

# Scrub from favorites file if present.
if os.path.exists(favs_file):
    try:
        with open(favs_file) as f:
            lines = [l for l in f.read().splitlines() if l.strip() and l.strip() != target_name]
        with open(favs_file, "w") as f:
            f.write("\n".join(lines) + ("\n" if lines else ""))
    except Exception:
        pass

if WAIT: input("  Press Enter to continue...")
