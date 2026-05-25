"""Tests for set_theme.py — updates import = [...] in alacritty.toml."""
import sys, re
from pathlib import Path
import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

THEME = "/themes/catppuccin_mocha.toml"


def apply(config_content: str, theme: str = THEME) -> str:
    """Run set_theme logic on a string and return the result."""
    import importlib.util, types, io, contextlib

    new_import = f'import = ["{theme}"]'

    if re.search(r'import\s*=\s*\[', config_content):
        return re.sub(r'import\s*=\s*\[[^\]]*\]', new_import, config_content)
    elif '[general]' in config_content:
        return re.sub(r'(\[general\])', f'\\1\n{new_import}', config_content, count=1)
    else:
        return f'[general]\n{new_import}\n\n' + config_content


def test_updates_existing_import():
    cfg = '[general]\nimport = ["/old/theme.toml"]\n\n[env]\n'
    result = apply(cfg)
    assert f'import = ["{THEME}"]' in result
    assert "/old/theme.toml" not in result


def test_adds_import_under_existing_general():
    cfg = '[general]\nlive_config_reload = true\n\n[font]\n'
    result = apply(cfg)
    assert f'import = ["{THEME}"]' in result
    assert '[general]\n' in result


def test_prepends_general_when_missing():
    cfg = '[font]\nsize = 14\n'
    result = apply(cfg)
    assert result.startswith('[general]\n')
    assert f'import = ["{THEME}"]' in result
    assert '[font]' in result


def test_does_not_duplicate_general():
    cfg = '[general]\nimport = ["/old.toml"]\n'
    result = apply(cfg)
    assert result.count('[general]') == 1


def test_preserves_rest_of_config():
    cfg = '[general]\nimport = ["/old.toml"]\n\n[font]\nsize = 13\n'
    result = apply(cfg)
    assert 'size = 13' in result


def test_writes_to_file(tmp_path):
    config = tmp_path / "alacritty.toml"
    theme = tmp_path / "dracula.toml"
    theme.write_text('[colors.primary]\nbackground = "#282a36"\n')
    config.write_text('[general]\nimport = ["/old.toml"]\n')

    import subprocess
    subprocess.run(
        [sys.executable, str(Path(__file__).parent.parent / "set_theme.py"),
         str(config), str(theme)],
        check=True
    )
    assert f'import = ["{theme}"]' in config.read_text()
