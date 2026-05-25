#!/usr/bin/env python3
"""Toggle a theme in the favorites file."""
import sys, os

if len(sys.argv) < 2:
    sys.exit(1)

path     = sys.argv[1]
name     = os.path.basename(path)
fav_file = os.environ.get("TPICK_FAVORITES", os.path.expanduser("~/.local/share/tpick/favorites"))

os.makedirs(os.path.dirname(fav_file), exist_ok=True)

favs = set()
if os.path.exists(fav_file):
    with open(fav_file) as f:
        favs = set(l.strip() for l in f if l.strip())

if name in favs:
    favs.discard(name)
else:
    favs.add(name)

with open(fav_file, "w") as f:
    f.write("\n".join(sorted(favs)) + "\n")
