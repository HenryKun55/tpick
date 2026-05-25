"""Tests for _remove_theme.py — removes a theme file with confirmation."""
import sys, os, subprocess
from pathlib import Path
import pytest

SCRIPT = Path(__file__).parent.parent / "_remove_theme.py"

THEME_CONTENT = '[colors.primary]\nbackground = "#1e1e2e"\nforeground = "#cdd6f4"\n'


def run(args: list, fav_file: Path = None, stdin: str = "y\n") -> subprocess.CompletedProcess:
    env = {**os.environ}
    if fav_file:
        env["TPICK_FAVORITES"] = str(fav_file)
    return subprocess.run(
        [sys.executable, str(SCRIPT)] + args,
        env=env, capture_output=True, text=True, input=stdin
    )


def test_removes_theme_file(tmp_path):
    theme = tmp_path / "dracula.toml"
    theme.write_text(THEME_CONTENT)
    result = run([str(theme)], stdin="y\n")
    assert result.returncode == 0
    assert not theme.exists()


def test_aborts_on_no(tmp_path):
    theme = tmp_path / "nord.toml"
    theme.write_text(THEME_CONTENT)
    result = run([str(theme)], stdin="n\n")
    assert result.returncode != 0
    assert theme.exists()


def test_fails_if_file_not_found(tmp_path):
    result = run([str(tmp_path / "nonexistent.toml")])
    assert result.returncode != 0


def test_refuses_to_remove_alacritty_toml(tmp_path):
    theme = tmp_path / "alacritty.toml"
    theme.write_text(THEME_CONTENT)
    result = run([str(theme)], stdin="y\n")
    assert result.returncode != 0
    assert theme.exists()


def test_refuses_to_remove_protected_theme(tmp_path):
    theme = tmp_path / "active.toml"
    theme.write_text(THEME_CONTENT)
    result = run([str(theme), str(theme)], stdin="y\n")
    assert result.returncode != 0
    assert theme.exists()
    assert "active theme" in result.stdout or "Apply" in result.stdout


def test_removes_from_favorites_on_delete(tmp_path):
    theme = tmp_path / "dracula.toml"
    theme.write_text(THEME_CONTENT)
    fav = tmp_path / "favorites"
    fav.write_text("dracula.toml\nnord.toml\n")
    result = run([str(theme)], fav_file=fav, stdin="y\n")
    assert result.returncode == 0
    assert "dracula.toml" not in fav.read_text()
    assert "nord.toml" in fav.read_text()


def test_keeps_other_favorites_intact(tmp_path):
    theme = tmp_path / "dracula.toml"
    theme.write_text(THEME_CONTENT)
    fav = tmp_path / "favorites"
    fav.write_text("catppuccin_mocha.toml\ndracula.toml\nnord.toml\n")
    run([str(theme)], fav_file=fav, stdin="y\n")
    remaining = fav.read_text().splitlines()
    assert "catppuccin_mocha.toml" in remaining
    assert "nord.toml" in remaining
