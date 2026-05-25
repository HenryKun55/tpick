#!/usr/bin/env python3
"""Preview a Claude Code theme with representative color swatches."""
import sys, json, re

BUILTIN_PALETTES = {
    "dark": {
        "bg": "#1a1a1a", "fg": "#e0e0e0",
        "added": "#1a3a1a", "removed": "#3a1a1a",
        "info": "#1a2a3a", "accent": "#4a9eff",
        "green": "#22c55e", "red": "#ef4444", "yellow": "#f59e0b",
    },
    "light": {
        "bg": "#ffffff", "fg": "#1a1a1a",
        "added": "#dcfce7", "removed": "#fee2e2",
        "info": "#dbeafe", "accent": "#2563eb",
        "green": "#16a34a", "red": "#dc2626", "yellow": "#d97706",
    },
    "dark-daltonism": {
        "bg": "#1a1a1a", "fg": "#e0e0e0",
        "added": "#1a2a3a", "removed": "#3a2a1a",
        "info": "#1a1a3a", "accent": "#60a5fa",
        "green": "#60a5fa", "red": "#f59e0b", "yellow": "#a78bfa",
    },
    "light-daltonism": {
        "bg": "#ffffff", "fg": "#1a1a1a",
        "added": "#dbeafe", "removed": "#fef3c7",
        "info": "#ede9fe", "accent": "#2563eb",
        "green": "#2563eb", "red": "#d97706", "yellow": "#7c3aed",
    },
}

def hex_to_rgb(h):
    h = h.lstrip('#')
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

def bg(h, text="  ", pad=0):
    r, g, b = hex_to_rgb(h)
    return f"\033[48;2;{r};{g};{b}m{' ' * pad}{text}{' ' * pad}\033[0m"

def fg_on_bg(fgc, bgc, text):
    fr, fg2, fb = hex_to_rgb(fgc)
    br, bgg, bb = hex_to_rgb(bgc)
    return f"\033[38;2;{fr};{fg2};{fb}m\033[48;2;{br};{bgg};{bb}m{text}\033[0m"

def load_custom(path):
    try:
        with open(path) as f:
            data = json.load(f)
        base = data.get("base", "dark")
        palette = dict(BUILTIN_PALETTES.get(base, BUILTIN_PALETTES["dark"]))
        return palette, data.get("overrides", {}), base
    except Exception:
        return dict(BUILTIN_PALETTES["dark"]), {}, "dark"

def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    theme_name = sys.argv[1]
    theme_path = sys.argv[2] if len(sys.argv) > 2 else "(built-in)"

    if theme_path != "(built-in)" and theme_path.endswith(".json"):
        palette, overrides, base = load_custom(theme_path)
        display_name = f"custom:{theme_name.replace('custom:', '')}"
        base_label = f"based on {base}"
    else:
        palette = dict(BUILTIN_PALETTES.get(theme_name, BUILTIN_PALETTES["dark"]))
        overrides = {}
        display_name = theme_name
        base_label = "built-in"

    print(f"\033[1m  {display_name}\033[0m  \033[2m{base_label}\033[0m")
    print()

    # Sample text preview
    print(f"  {fg_on_bg(palette['fg'], palette['bg'], '  Hello from Claude Code  ')}")
    print()

    # Diff preview
    print(f"  \033[2mDiff preview\033[0m")
    print(f"  {bg(palette['removed'], '- removed line example     ')}")
    print(f"  {bg(palette['bg'],      '  unchanged line           ')}")
    print(f"  {bg(palette['added'],   '+ added line example       ')}")
    print()

    # Color dots (subagent colors)
    colors = {
        "green":  overrides.get("green_FOR_SUBAGENTS_ONLY",  palette["green"]),
        "red":    overrides.get("red_FOR_SUBAGENTS_ONLY",    palette["red"]),
        "yellow": overrides.get("yellow_FOR_SUBAGENTS_ONLY", palette["yellow"]),
        "accent": palette["accent"],
    }

    print(f"  \033[2mAccent colors\033[0m")
    row = "  "
    for name, color in colors.items():
        row += bg(color, f"  {name}  ")
    print(row)

    if overrides:
        print()
        print(f"  \033[2mOverrides\033[0m")
        for k, v in overrides.items():
            key = k.replace("_FOR_SUBAGENTS_ONLY", "")
            print(f"  \033[2m{key:12}\033[0m  {bg(v, '    ')}  {v}")

main()
