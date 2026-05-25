"""Tests for list_themes.py — builds the fzf theme list."""
import sys, os, re, subprocess
from pathlib import Path
import pytest

SCRIPT = Path(__file__).parent.parent / "list_themes.py"

def strip_ansi(s: str) -> str:
    return re.sub(r'\x1b\[[0-9;]*m', '', s)

DARK_BG  = 'background = "#1e1e2e"'   # brightness ~0.12 → dark
LIGHT_BG = 'background = "#fafafa"'   # brightness ~0.98 → light


def make_theme(directory: Path, name: str, bg: str) -> Path:
    t = directory / name
    t.write_text(f'[colors.primary]\n{bg}\nforeground = "#cdd6f4"\n')
    return t


def run(config_dir: Path, filter_mode: str = "", fav_file: Path = None, themes_dir: Path = None) -> list[str]:
    env = {**os.environ}
    if fav_file:
        env["TPICK_FAVORITES"] = str(fav_file)
    if themes_dir:
        env["TPICK_THEMES_DIR"] = str(themes_dir)
    else:
        env["TPICK_THEMES_DIR"] = "/nonexistent"

    args = [sys.executable, str(SCRIPT), str(config_dir)]
    if filter_mode:
        args.append(filter_mode)

    result = subprocess.run(args, env=env, capture_output=True, text=True)
    return [l for l in result.stdout.splitlines() if l]


def test_lists_themes(tmp_path):
    make_theme(tmp_path, "dracula.toml", DARK_BG)
    make_theme(tmp_path, "one-light.toml", LIGHT_BG)
    lines = run(tmp_path)
    names = [strip_ansi(l.split("\t")[0]).strip().lstrip("★").strip() for l in lines]
    assert "dracula.toml" in names
    assert "one-light.toml" in names


def test_excludes_alacritty_toml(tmp_path):
    make_theme(tmp_path, "alacritty.toml", DARK_BG)
    make_theme(tmp_path, "dracula.toml", DARK_BG)
    lines = run(tmp_path)
    names = "\n".join(lines)
    assert "alacritty.toml" not in names


def test_dark_filter(tmp_path):
    make_theme(tmp_path, "dark-theme.toml", DARK_BG)
    make_theme(tmp_path, "light-theme.toml", LIGHT_BG)
    lines = run(tmp_path, "dark")
    names = [strip_ansi(l.split("\t")[0]).strip().lstrip("★").strip() for l in lines]
    assert "dark-theme.toml" in names
    assert "light-theme.toml" not in names


def test_light_filter(tmp_path):
    make_theme(tmp_path, "dark-theme.toml", DARK_BG)
    make_theme(tmp_path, "light-theme.toml", LIGHT_BG)
    lines = run(tmp_path, "light")
    names = [strip_ansi(l.split("\t")[0]).strip().lstrip("★").strip() for l in lines]
    assert "light-theme.toml" in names
    assert "dark-theme.toml" not in names


def test_favorites_filter(tmp_path):
    make_theme(tmp_path, "dracula.toml", DARK_BG)
    make_theme(tmp_path, "nord.toml", DARK_BG)
    fav = tmp_path / "favorites"
    fav.write_text("dracula.toml\n")
    lines = run(tmp_path, "favorites", fav_file=fav)
    names = [strip_ansi(l.split("\t")[0]).strip().lstrip("★").strip() for l in lines]
    assert "dracula.toml" in names
    assert "nord.toml" not in names


def test_favorites_sorted_first(tmp_path):
    make_theme(tmp_path, "aaa.toml", DARK_BG)
    make_theme(tmp_path, "zzz.toml", DARK_BG)
    fav = tmp_path / "favorites"
    fav.write_text("zzz.toml\n")
    lines = run(tmp_path, fav_file=fav)
    first_name = strip_ansi(lines[0].split("\t")[0]).strip().lstrip("★").strip()
    assert first_name == "zzz.toml"


def test_star_shown_for_favorite(tmp_path):
    make_theme(tmp_path, "dracula.toml", DARK_BG)
    fav = tmp_path / "favorites"
    fav.write_text("dracula.toml\n")
    lines = run(tmp_path, fav_file=fav)
    assert any("★" in l for l in lines)


def test_output_is_tab_delimited(tmp_path):
    make_theme(tmp_path, "theme.toml", DARK_BG)
    lines = run(tmp_path)
    assert all("\t" in l for l in lines)
