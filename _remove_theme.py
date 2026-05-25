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


def wait_for_enter():
    if WAIT:
        try:
            input("  Press Enter to continue...")
        except (KeyboardInterrupt, EOFError):
            pass


def fail(msg, code=1):
    print(f"  {msg}")
    wait_for_enter()
    sys.exit(code)


def safe_input(prompt):
    try:
        return input(prompt)
    except (KeyboardInterrupt, EOFError):
        print()
        fail("cancelled", code=130)


def main():
    if not args:
        print("  usage: _remove_theme.py <theme_path> [protected_path] [--wait]")
        wait_for_enter()
        sys.exit(1)

    target = args[0]
    protected = args[1] if len(args) > 1 else ""
    favs_file = os.environ.get(
        "TPICK_FAVORITES",
        os.path.expanduser("~/.local/share/tpick/favorites"),
    )

    target_name = os.path.basename(target)

    if not os.path.isfile(target):
        fail(f"theme not found: {target}")

    if target_name == "alacritty.toml":
        fail("refusing to remove 'alacritty.toml' (the config itself)")

    if protected:
        try:
            same = os.path.samefile(target, os.path.expanduser(protected))
        except (FileNotFoundError, OSError):
            same = False
        if same:
            print(f"  '{target_name}' was the active theme when you opened tpick.")
            print("  Apply a different theme first (Enter on it), then remove this one.")
            wait_for_enter()
            sys.exit(1)

    yn = safe_input(f"  Remove {target_name}? [y/N] ").strip().lower()
    if yn not in ("y", "yes"):
        print("  aborted")
        wait_for_enter()
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
                lines = [l for l in f.read().splitlines()
                         if l.strip() and l.strip() != target_name]
            with open(favs_file, "w") as f:
                f.write("\n".join(lines) + ("\n" if lines else ""))
        except Exception:
            pass

    wait_for_enter()


try:
    main()
except KeyboardInterrupt:
    print("\n  cancelled")
    wait_for_enter()
    sys.exit(130)
