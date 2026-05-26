#!/usr/bin/env python3
"""Print metadata about a theme file: colors, brightness, favorite status."""
import os, re, sys

if len(sys.argv) < 2:
    print("usage: _theme_info.py <theme.toml>", file=sys.stderr)
    sys.exit(1)

target = sys.argv[1]
if not os.path.isfile(target):
    print(f"  not a file: {target}", file=sys.stderr)
    sys.exit(1)

name = os.path.basename(target)
if name.endswith(".toml"):
    name = name[:-5]

favs_file = os.environ.get(
    "TPICK_FAVORITES",
    os.path.expanduser("~/.local/share/tpick/favorites"),
)
favorites = set()
if os.path.exists(favs_file):
    try:
        with open(favs_file) as f:
            favorites = {l.strip() for l in f if l.strip()}
    except Exception:
        pass

with open(target) as f:
    content = f.read()


def find_color(key):
    m = re.search(rf"{key}\s*=\s*['\"]#?([0-9a-fA-F]{{6}})['\"]", content)
    return f"#{m.group(1).lower()}" if m else None


bg = find_color("background")
fg = find_color("foreground")
accent = find_color("blue")

brightness = "unknown"
if bg:
    r, g, b = int(bg[1:3], 16), int(bg[3:5], 16), int(bg[5:7], 16)
    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    brightness = "dark" if luminance < 0.5 else "light"

# ANSI swatches: small colored block next to each hex
def swatch(hex_color):
    if not hex_color:
        return "unknown"
    r, g, b = int(hex_color[1:3], 16), int(hex_color[3:5], 16), int(hex_color[5:7], 16)
    return f"\x1b[48;2;{r};{g};{b}m   \x1b[0m  {hex_color}"


star = "★ yes" if f"{name}.toml" in favorites else "no"
print(f"  {name}")
print(f"  {'─' * (len(name) + 2)}")
print(f"  background  {swatch(bg)}")
print(f"  foreground  {swatch(fg)}")
print(f"  blue        {swatch(accent)}")
print(f"  brightness  {brightness}")
print(f"  favorite    {star}")
print(f"  path        {target}")
