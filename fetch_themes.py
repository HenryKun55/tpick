#!/usr/bin/env python3
"""Download all themes from alacritty/alacritty-theme into TPICK_THEMES_DIR."""
import urllib.request, urllib.parse, json, os, sys

API = "https://api.github.com/repos/alacritty/alacritty-theme/contents/themes"
RAW = "https://raw.githubusercontent.com/alacritty/alacritty-theme/master/themes"

def main():
    themes_dir = os.environ.get(
        "TPICK_THEMES_DIR",
        os.path.expanduser("~/.local/share/tpick/themes")
    )
    os.makedirs(themes_dir, exist_ok=True)

    print(f"Fetching theme list from alacritty/alacritty-theme...")
    try:
        req = urllib.request.Request(API, headers={"User-Agent": "tpick"})
        with urllib.request.urlopen(req) as r:
            entries = json.loads(r.read())
    except Exception as e:
        print(f"Error fetching list: {e}", file=sys.stderr)
        sys.exit(1)

    files = [e for e in entries if e["name"].endswith(".toml")]
    total = len(files)
    print(f"{total} themes found\n")

    downloaded, skipped, failed = 0, 0, 0
    for i, entry in enumerate(files, 1):
        name = entry["name"]
        dest = os.path.join(themes_dir, name)
        if os.path.exists(dest):
            print(f"  [{i:3}/{total}] skip  {name}")
            skipped += 1
            continue
        try:
            url = f"{RAW}/{urllib.parse.quote(name)}"
            req = urllib.request.Request(url, headers={"User-Agent": "tpick"})
            with urllib.request.urlopen(req) as r:
                open(dest, "wb").write(r.read())
            print(f"  [{i:3}/{total}] ✓     {name}")
            downloaded += 1
        except Exception as e:
            print(f"  [{i:3}/{total}] ✗     {name}: {e}")
            failed += 1

    print(f"\nDone — {downloaded} downloaded, {skipped} already existed, {failed} errors")
    print(f"Themes at: {themes_dir}")
    print("Run 'tpick' to pick one.")

main()
