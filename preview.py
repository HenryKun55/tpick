#!/usr/bin/env python3
"""Render a color swatch preview for an Alacritty TOML theme file."""
import sys, re

def hex_to_rgb(h):
    h = h.lstrip('#')
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

def swatch(h, w=5):
    r, g, b = hex_to_rgb(h)
    return f"\033[48;2;{r};{g};{b}m{' ' * w}\033[0m"

def on_bg(bgc, fgc, text):
    br, bg2, bb = hex_to_rgb(bgc)
    fr, fg2, fb = hex_to_rgb(fgc)
    return f"\033[48;2;{br};{bg2};{bb}m\033[38;2;{fr};{fg2};{fb}m{text}\033[0m"


def parse(path):
    colors, section = {}, ""
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                m = re.match(r'^\[([^\]]+)\]', line)
                if m:
                    section = m.group(1)
                    continue
                m = re.match(r'^(\w+)\s*=\s*[\'"](\#[0-9a-fA-F]{6})[\'"]', line)
                if m:
                    colors[f"{section}.{m.group(1)}"] = m.group(2)
    except Exception:
        pass
    return colors

def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    path = sys.argv[1]
    name = path.split("/")[-1]
    if name.endswith(".toml"):
        name = name[:-5]

    c = parse(path)
    bg  = c.get("colors.primary.background", "#1a1a1a")
    fg  = c.get("colors.primary.foreground", "#f0f0f0")
    red = c.get("colors.normal.red",    "#ff5555")
    grn = c.get("colors.normal.green",  "#55ff55")
    yel = c.get("colors.normal.yellow", "#ffff55")
    blu = c.get("colors.normal.blue",   "#5555ff")
    r, g, b = hex_to_rgb(bg)
    fr, fg2, fb = hex_to_rgb(fg)

    # ── Header ────────────────────────────────────────────────────────────────
    print(f"\033[1m  {name}\033[0m")
    print()

    # ── Terminal sample ───────────────────────────────────────────────────────
    sample = "  Hello, World! · 0123456789 · #%@!  "
    print(f"  \033[48;2;{r};{g};{b}m\033[38;2;{fr};{fg2};{fb}m{sample}\033[0m")
    print()
    print(f"  {swatch(bg, 4)} bg {bg}    {swatch(fg, 4)} fg {fg}")
    print()

    palette = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
    for label, prefix in [("Normal", "colors.normal"), ("Bright", "colors.bright")]:
        has_section = any(f"{prefix}.{k}" in c for k in palette)
        if not has_section:
            continue
        print(f"  \033[2m{label}\033[0m")
        swatches_row = "  "
        hexes_row    = "  "
        for k in palette:
            color = c.get(f"{prefix}.{k}", "#888888")
            swatches_row += swatch(color, 5)
            hexes_row    += f"\033[2m{color}\033[0m "
        print(swatches_row)
        print(hexes_row)
        print()

    # ── Claude Code mock ──────────────────────────────────────────────────────
    # Claude Code uses chalk bgRed/bgGreen (ANSI indexed), so the diff bg
    # comes directly from the terminal theme's colors.normal.red/green.
    print(f"  \033[2m{'─' * 38}\033[0m")
    print(f"  \033[2mClaude Code preview\033[0m")
    print()

    print(f"  {on_bg(bg, blu, '● ')}  {on_bg(bg, fg, 'Edit')}  \033[2msrc/app.ts\033[0m")
    print()

    W = 36
    l_rem  = f"  {'- const x = oldValue':<{W}}"
    l_unch = f"  {'  const y = value':<{W}}"
    l_add  = f"  {'+  const x = newValue':<{W}}"
    print(f"  {on_bg(red, bg, l_rem)}")   # bgRed   → terminal's normal.red as bg
    print(f"  {on_bg(bg,  fg, l_unch)}")
    print(f"  {on_bg(grn, bg, l_add)}")   # bgGreen → terminal's normal.green as bg
    print()

    print(f"  {on_bg(bg, yel, '●')}  \033[2mBash\033[0m  \033[2mnpm run build\033[0m")
    print(f"  \033[2m  └ Build successful in 1.2s\033[0m")
    print()

main()
