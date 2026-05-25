"""Tests for _new_theme.py — creates a theme copy and opens in editor."""
import sys, os, subprocess
from pathlib import Path
import pytest

SCRIPT = Path(__file__).parent.parent / "_new_theme.py"

THEME_CONTENT = '[colors.primary]\nbackground = "#1e1e2e"\nforeground = "#cdd6f4"\n'


def run(args: list, themes_dir: Path, env_extra: dict = None) -> subprocess.CompletedProcess:
    # EDITOR=true: the `true` command exits immediately with 0, avoids opening a real editor
    env = {**os.environ, "TPICK_THEMES_DIR": str(themes_dir), "EDITOR": "true", "VISUAL": ""}
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        [sys.executable, str(SCRIPT)] + args,
        env=env, capture_output=True, text=True
    )


def test_creates_theme_copy(tmp_path):
    src = tmp_path / "dracula.toml"
    src.write_text(THEME_CONTENT)
    themes_dir = tmp_path / "themes"
    result = run([str(src), "my_theme"], themes_dir)
    assert result.returncode == 0
    assert (themes_dir / "my_theme.toml").exists()
    assert (themes_dir / "my_theme.toml").read_text() == THEME_CONTENT


def test_strips_toml_extension_from_name(tmp_path):
    src = tmp_path / "nord.toml"
    src.write_text(THEME_CONTENT)
    themes_dir = tmp_path / "themes"
    result = run([str(src), "custom.toml"], themes_dir)
    assert result.returncode == 0
    assert (themes_dir / "custom.toml").exists()


def test_fails_if_source_not_found(tmp_path):
    themes_dir = tmp_path / "themes"
    result = run(["/nonexistent/theme.toml", "new_name"], themes_dir)
    assert result.returncode != 0


def test_fails_if_dest_already_exists(tmp_path):
    src = tmp_path / "dracula.toml"
    src.write_text(THEME_CONTENT)
    themes_dir = tmp_path / "themes"
    themes_dir.mkdir()
    (themes_dir / "my_theme.toml").write_text(THEME_CONTENT)
    result = run([str(src), "my_theme"], themes_dir)
    assert result.returncode != 0
    assert "already exists" in result.stdout


def test_rejects_invalid_name_characters(tmp_path):
    src = tmp_path / "dracula.toml"
    src.write_text(THEME_CONTENT)
    themes_dir = tmp_path / "themes"
    result = run([str(src), "bad name!"], themes_dir)
    assert result.returncode != 0
    assert "letters" in result.stdout or "name" in result.stdout


def test_creates_themes_dir_if_missing(tmp_path):
    src = tmp_path / "source.toml"
    src.write_text(THEME_CONTENT)
    themes_dir = tmp_path / "does" / "not" / "exist"
    result = run([str(src), "new_theme"], themes_dir)
    assert result.returncode == 0
    assert (themes_dir / "new_theme.toml").exists()
