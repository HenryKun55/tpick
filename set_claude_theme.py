#!/usr/bin/env python3
"""Update the theme in ~/.claude/settings.json."""
import sys, json, os

if len(sys.argv) < 3:
    print("Usage: set_claude_theme.py <settings.json> <theme-name>", file=sys.stderr)
    sys.exit(1)

settings_path, theme = sys.argv[1], sys.argv[2]
try:
    with open(settings_path) as f:
        data = json.load(f)
    data["theme"] = theme
    with open(settings_path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
except Exception as e:
    print(e, file=sys.stderr)
    sys.exit(1)
