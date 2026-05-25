"""Tests for toggle_fav.py — adds/removes theme from favorites file."""
import sys, os, subprocess
from pathlib import Path
import pytest

SCRIPT = Path(__file__).parent.parent / "toggle_fav.py"


def run(theme_path: str, fav_file: Path) -> None:
    env = {**os.environ, "TPICK_FAVORITES": str(fav_file)}
    subprocess.run([sys.executable, str(SCRIPT), theme_path], env=env, check=True)


def test_adds_theme(tmp_path):
    fav = tmp_path / "favorites"
    run("/themes/dracula.toml", fav)
    assert "dracula.toml" in fav.read_text()


def test_removes_theme_when_already_favorited(tmp_path):
    fav = tmp_path / "favorites"
    fav.write_text("dracula.toml\n")
    run("/themes/dracula.toml", fav)
    assert "dracula.toml" not in fav.read_text()


def test_toggle_twice_restores(tmp_path):
    fav = tmp_path / "favorites"
    run("/themes/nord.toml", fav)
    run("/themes/nord.toml", fav)
    assert "nord.toml" not in fav.read_text()


def test_multiple_favorites_sorted(tmp_path):
    fav = tmp_path / "favorites"
    run("/themes/tokyo.toml", fav)
    run("/themes/dracula.toml", fav)
    lines = [l for l in fav.read_text().splitlines() if l]
    assert lines == sorted(lines)


def test_does_not_duplicate(tmp_path):
    fav = tmp_path / "favorites"
    run("/themes/catppuccin_mocha.toml", fav)
    run("/themes/catppuccin_mocha.toml", fav)  # remove
    run("/themes/catppuccin_mocha.toml", fav)  # add again
    count = fav.read_text().splitlines().count("catppuccin_mocha.toml")
    assert count == 1
