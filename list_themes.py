#!/usr/bin/env python3
"""Build the fzf-ready theme list with ★ for favorites and dark/light filtering."""
import os, sys, re

config_dir   = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.config/alacritty")
filter_mode  = sys.argv[2] if len(sys.argv) > 2 else ""   # dark | light | favorites | ""
themes_dir   = os.environ.get("TPICK_THEMES_DIR",  os.path.expanduser("~/.local/share/tpick/themes"))
fav_file     = os.environ.get("TPICK_FAVORITES",   os.path.expanduser("~/.local/share/tpick/favorites"))

def load_favs():
    if not os.path.exists(fav_file):
        return set()
    with open(fav_file) as f:
        return set(l.strip() for l in f if l.strip())

def brightness(path):
    try:
        for line in open(path):
            m = re.match(r'background\s*=\s*[\'"]#([0-9a-fA-F]{6})[\'"]', line.strip())
            if m:
                h = m.group(1)
                r, g, b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
                return (0.299*r + 0.587*g + 0.114*b) / 255
    except Exception:
        pass
    return 0.0

def collect():
    paths = []
    for d in [config_dir, themes_dir]:
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".toml") and f not in ("alacritty.toml",):
                paths.append(os.path.join(d, f))
    return paths

favs   = load_favs()
themes = collect()

if filter_mode == "dark":
    themes = [t for t in themes if brightness(t) < 0.5]
elif filter_mode == "light":
    themes = [t for t in themes if brightness(t) >= 0.5]
elif filter_mode == "favorites":
    themes = [t for t in themes if os.path.basename(t) in favs]

themes.sort(key=lambda t: (0 if os.path.basename(t) in favs else 1, os.path.basename(t).lower()))

for path in themes:
    name = os.path.basename(path)
    star = "\033[33m★\033[0m " if name in favs else "  "
    print(f"{star}{name}\t{path}")
