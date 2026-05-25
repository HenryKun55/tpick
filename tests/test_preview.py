"""Tests for preview.py and preview_claude.py — terminal color swatch renderers."""
import sys, subprocess
from pathlib import Path
import pytest

PREVIEW = Path(__file__).parent.parent / "preview.py"
PREVIEW_CLAUDE = Path(__file__).parent.parent / "preview_claude.py"

DARK_THEME = """\
[colors.primary]
background = '#1e1e2e'
foreground = '#cdd6f4'

[colors.normal]
black   = '#45475a'
red     = '#f38ba8'
green   = '#a6e3a1'
yellow  = '#f9e2af'
blue    = '#89b4fa'
magenta = '#f5c2e7'
cyan    = '#94e2d5'
white   = '#bac2de'

[colors.bright]
black   = '#585b70'
red     = '#f38ba8'
green   = '#a6e3a1'
yellow  = '#f9e2af'
blue    = '#89b4fa'
magenta = '#f5c2e7'
cyan    = '#94e2d5'
white   = '#a6adc8'
"""


def run_preview(theme_path: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(PREVIEW), str(theme_path)],
        capture_output=True, text=True
    )


def run_preview_claude(theme_name: str, theme_path: str = "(built-in)") -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(PREVIEW_CLAUDE), theme_name, theme_path],
        capture_output=True, text=True
    )


def test_preview_produces_output(tmp_path):
    t = tmp_path / "catppuccin_mocha.toml"
    t.write_text(DARK_THEME)
    result = run_preview(t)
    assert result.returncode == 0
    assert len(result.stdout) > 0


def test_preview_shows_theme_name(tmp_path):
    t = tmp_path / "catppuccin_mocha.toml"
    t.write_text(DARK_THEME)
    result = run_preview(t)
    assert "catppuccin_mocha" in result.stdout


def test_preview_shows_hex_colors(tmp_path):
    t = tmp_path / "theme.toml"
    t.write_text(DARK_THEME)
    result = run_preview(t)
    assert "#1e1e2e" in result.stdout
    assert "#cdd6f4" in result.stdout


def test_preview_handles_missing_file_gracefully():
    result = run_preview(Path("/nonexistent/theme.toml"))
    assert result.returncode == 0


def test_preview_handles_single_quoted_colors(tmp_path):
    t = tmp_path / "single_quotes.toml"
    t.write_text("[colors.primary]\nbackground = '#282a36'\nforeground = '#f8f8f2'\n")
    result = run_preview(t)
    assert "#282a36" in result.stdout


def test_preview_claude_builtin_dark():
    result = run_preview_claude("dark")
    assert result.returncode == 0
    assert len(result.stdout) > 0


def test_preview_claude_builtin_light():
    result = run_preview_claude("light")
    assert result.returncode == 0


def test_preview_claude_shows_diff_mock():
    result = run_preview_claude("dark")
    assert "removed line" in result.stdout or "added line" in result.stdout


def test_preview_claude_no_args():
    result = subprocess.run(
        [sys.executable, str(PREVIEW_CLAUDE)],
        capture_output=True, text=True
    )
    assert result.returncode != 0
