#!/usr/bin/env python3
"""Convert an Alacritty TOML theme to kitty or ghostty config format.

Used by `tpick export <name> --kitty|--ghostty`. Parsing is done via regex
to avoid a tomllib dependency (Python 3.11+) and tolerate slightly malformed
themes that still load fine in Alacritty.

Usage:
    _convert_theme.py <alacritty.toml> <kitty|ghostty>
"""
import re
import sys


def parse_theme(path):
    """Returns {(section, key): '#xxxxxx'} for every 6-hex color we find."""
    out = {}
    section = ""
    for raw in open(path):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^\[([^\]]+)\]", line)
        if m:
            section = m.group(1)
            continue
        m = re.match(
            r"^([a-zA-Z_]+)\s*=\s*['\"]?#?([0-9a-fA-F]{6})['\"]?",
            line,
        )
        if m:
            out[(section, m.group(1))] = f"#{m.group(2).lower()}"
    return out


NORMAL = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]


def _palette_pairs(theme):
    """Yields (index, hex_color) for indices 0..15, where present."""
    for i, name in enumerate(NORMAL):
        c = theme.get(("colors.normal", name))
        if c:
            yield i, c
    for i, name in enumerate(NORMAL):
        c = theme.get(("colors.bright", name))
        if c:
            yield i + 8, c


def to_kitty(theme):
    bg = theme.get(("colors.primary", "background"))
    fg = theme.get(("colors.primary", "foreground"))
    out = []
    if bg: out.append(f"background {bg}")
    if fg: out.append(f"foreground {fg}")

    cursor = theme.get(("colors.cursor", "cursor")) or fg
    cursor_text = theme.get(("colors.cursor", "text")) or bg
    if cursor:      out.append(f"cursor {cursor}")
    if cursor_text: out.append(f"cursor_text_color {cursor_text}")

    sel_bg = theme.get(("colors.selection", "background"))
    sel_fg = theme.get(("colors.selection", "text"))
    if sel_bg: out.append(f"selection_background {sel_bg}")
    if sel_fg: out.append(f"selection_foreground {sel_fg}")

    for i, c in _palette_pairs(theme):
        out.append(f"color{i} {c}")

    return "\n".join(out) + "\n"


def to_ghostty(theme):
    bg = theme.get(("colors.primary", "background"))
    fg = theme.get(("colors.primary", "foreground"))
    out = []
    if bg: out.append(f"background = {bg}")
    if fg: out.append(f"foreground = {fg}")

    cursor = theme.get(("colors.cursor", "cursor")) or fg
    if cursor: out.append(f"cursor-color = {cursor}")

    sel_bg = theme.get(("colors.selection", "background"))
    sel_fg = theme.get(("colors.selection", "text"))
    if sel_bg: out.append(f"selection-background = {sel_bg}")
    if sel_fg: out.append(f"selection-foreground = {sel_fg}")

    for i, c in _palette_pairs(theme):
        out.append(f"palette = {i}={c}")

    return "\n".join(out) + "\n"


def main():
    if len(sys.argv) < 3:
        print("usage: _convert_theme.py <alacritty.toml> <kitty|ghostty>", file=sys.stderr)
        sys.exit(1)
    path, fmt = sys.argv[1], sys.argv[2]
    theme = parse_theme(path)
    if fmt == "kitty":
        sys.stdout.write(to_kitty(theme))
    elif fmt == "ghostty":
        sys.stdout.write(to_ghostty(theme))
    else:
        print(f"unknown format: {fmt}", file=sys.stderr)
        sys.exit(1)


main()
