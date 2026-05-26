#!/usr/bin/env python3
"""Build the fzf-ready theme list with ★ for favorites, MRU ranking, and
dark/light filtering. Caches brightness (mtime-keyed) to avoid re-reading
every theme file on every invocation."""
import json, os, re, sys

config_dir   = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.config/alacritty")
filter_mode  = sys.argv[2] if len(sys.argv) > 2 else ""   # dark | light | favorites | ""
themes_dir   = os.environ.get("TPICK_THEMES_DIR",     os.path.expanduser("~/.local/share/tpick/themes"))
fav_file     = os.environ.get("TPICK_FAVORITES",      os.path.expanduser("~/.local/share/tpick/favorites"))
history_file = os.environ.get("TPICK_HISTORY_FILE",   os.path.expanduser("~/.local/share/tpick/history"))
cache_file   = os.environ.get("TPICK_BRIGHTNESS_CACHE", os.path.expanduser("~/.local/share/tpick/brightness.cache.json"))


def load_favs():
    if not os.path.exists(fav_file):
        return set()
    with open(fav_file) as f:
        return {l.strip() for l in f if l.strip()}


def load_history():
    """Returns a dict path -> rank (lower = more recent). Top of file is most recent."""
    if not os.path.exists(history_file):
        return {}
    out = {}
    with open(history_file) as f:
        for i, line in enumerate(l.strip() for l in f if l.strip()):
            out.setdefault(line, i)
    return out


def load_brightness_cache():
    """{path: {"mtime": float, "brightness": float}}"""
    if not os.path.exists(cache_file):
        return {}
    try:
        with open(cache_file) as f:
            return json.load(f)
    except Exception:
        return {}


def save_brightness_cache(cache):
    try:
        os.makedirs(os.path.dirname(cache_file), exist_ok=True)
        with open(cache_file, "w") as f:
            json.dump(cache, f)
    except Exception:
        pass


def compute_brightness(path):
    try:
        for line in open(path):
            m = re.match(r'background\s*=\s*[\'"]#([0-9a-fA-F]{6})[\'"]', line.strip())
            if m:
                h = m.group(1)
                r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
                return (0.299 * r + 0.587 * g + 0.114 * b) / 255
    except Exception:
        pass
    return 0.0


cache = load_brightness_cache()
cache_dirty = False


def brightness(path):
    """Cache-aware lookup. Returns the cached value when mtime matches, else
    recomputes and updates the cache."""
    global cache_dirty
    try:
        mt = os.path.getmtime(path)
    except OSError:
        return 0.0
    entry = cache.get(path)
    if entry and entry.get("mtime") == mt:
        return entry["brightness"]
    val = compute_brightness(path)
    cache[path] = {"mtime": mt, "brightness": val}
    cache_dirty = True
    return val


def collect():
    paths = []
    for d in [config_dir, themes_dir]:
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".toml") and f != "alacritty.toml":
                paths.append(os.path.join(d, f))
    return paths


favs    = load_favs()
history = load_history()
themes  = collect()

if filter_mode == "dark":
    themes = [t for t in themes if brightness(t) < 0.5]
elif filter_mode == "light":
    themes = [t for t in themes if brightness(t) >= 0.5]
elif filter_mode == "favorites":
    themes = [t for t in themes if os.path.basename(t) in favs]


def sort_key(path):
    name = os.path.basename(path)
    # Tier 0: favorites (preserve recent ordering inside)
    # Tier 1: recently-used (top 20 of history, ranked)
    # Tier 2: everything else, alphabetical
    is_fav = name in favs
    hist_rank = history.get(path)
    if is_fav:
        return (0, hist_rank if hist_rank is not None else 999, name.lower())
    if hist_rank is not None and hist_rank < 20:
        return (1, hist_rank, name.lower())
    return (2, 0, name.lower())


themes.sort(key=sort_key)

for path in themes:
    name = os.path.basename(path)
    star = "\033[33m★\033[0m " if name in favs else "  "
    print(f"{star}{name}\t{path}")

# Prune cache entries for files that no longer exist (cheap hygiene).
existing = {*cache.keys()} & {*themes, *[p for p in cache.keys() if os.path.exists(p)]}
if len(existing) != len(cache):
    cache = {p: cache[p] for p in cache if p in existing or os.path.exists(p)}
    cache_dirty = True

if cache_dirty:
    save_brightness_cache(cache)
