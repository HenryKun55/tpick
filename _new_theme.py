#!/usr/bin/env python3
"""Create a new theme as a copy of <source>, open in $EDITOR.

Used by tpick (Ctrl-N in picker, or `tpick new`). Prompts for the new theme
name; the new file lands in TPICK_THEMES_DIR and is opened in the user's editor.

--wait: pause for Enter at the end, so the user can read output before control
returns to the caller. Use when invoked from inside fzf's execute().
"""
import os, re, shutil, subprocess, sys

args = [a for a in sys.argv[1:] if a != "--wait"]
WAIT = "--wait" in sys.argv

if not args:
    print("  usage: _new_theme.py <source_path> [--wait]")
    if WAIT: input("  Press Enter to continue...")
    sys.exit(1)

source = args[0]

def fail(msg):
    print(f"  {msg}")
    if WAIT: input("  Press Enter to continue...")
    sys.exit(1)

if not os.path.isfile(source):
    fail(f"source theme not found: {source}")

themes_dir = os.environ.get(
    "TPICK_THEMES_DIR",
    os.path.expanduser("~/.local/share/tpick/themes"),
)
os.makedirs(themes_dir, exist_ok=True)

source_name = os.path.basename(source)
if source_name.endswith(".toml"):
    source_name = source_name[:-5]
print(f"  Creating a new theme based on '{source_name}'")

try:
    name = input("  Name for the new theme: ").strip()
except EOFError:
    name = ""

if not name:
    fail("name is required")

if name.endswith(".toml"):
    name = name[:-5]

if not re.match(r"^[a-zA-Z0-9_-]+$", name):
    fail("name must contain only letters, digits, _ or -")

dest = os.path.join(themes_dir, name + ".toml")
if os.path.exists(dest):
    fail(f"'{name}.toml' already exists at {dest}")

try:
    shutil.copyfile(source, dest)
    print(f"  ✓ created {dest}")
except Exception as e:
    fail(f"failed to copy: {e}")

editor = os.environ.get("VISUAL") or os.environ.get("EDITOR")
if not editor:
    for candidate in ("nvim", "vim", "vi"):
        if shutil.which(candidate):
            editor = candidate
            break

if not editor:
    print("  no editor found — set $EDITOR or open the file manually.")
    if WAIT: input("  Press Enter to continue...")
    sys.exit(0)

print(f"  Opening in {editor}...")
subprocess.call([editor, dest])
print(f"  ✓ '{name}' now in the list")
if WAIT: input("  Press Enter to return to tpick...")
