"""Tests for set_claude_theme.py — updates theme in settings.json."""
import sys, json, subprocess
from pathlib import Path
import pytest

SCRIPT = Path(__file__).parent.parent / "set_claude_theme.py"


def run(settings: Path, theme: str) -> None:
    subprocess.run([sys.executable, str(SCRIPT), str(settings), theme], check=True)


def test_sets_theme(tmp_path):
    s = tmp_path / "settings.json"
    s.write_text('{"model": "claude-opus-4-7"}\n')
    run(s, "dark")
    assert json.loads(s.read_text())["theme"] == "dark"


def test_updates_existing_theme(tmp_path):
    s = tmp_path / "settings.json"
    s.write_text('{"theme": "light", "model": "claude-opus-4-7"}\n')
    run(s, "dark-daltonism")
    assert json.loads(s.read_text())["theme"] == "dark-daltonism"


def test_preserves_other_keys(tmp_path):
    s = tmp_path / "settings.json"
    s.write_text('{"model": "claude-opus-4-7", "theme": "dark"}\n')
    run(s, "light")
    data = json.loads(s.read_text())
    assert data["model"] == "claude-opus-4-7"
    assert data["theme"] == "light"


def test_custom_theme_name(tmp_path):
    s = tmp_path / "settings.json"
    s.write_text('{"theme": "dark"}\n')
    run(s, "custom:my-theme")
    assert json.loads(s.read_text())["theme"] == "custom:my-theme"


def test_output_is_valid_json(tmp_path):
    s = tmp_path / "settings.json"
    s.write_text('{"theme": "dark"}\n')
    run(s, "light")
    json.loads(s.read_text())  # should not raise
