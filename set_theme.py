#!/usr/bin/env python3
"""Update (or add) the import line in an Alacritty TOML config to point to a new theme."""
import sys, re

if len(sys.argv) < 3:
    print("Usage: set_theme.py <alacritty.toml> <theme.toml>", file=sys.stderr)
    sys.exit(1)

config, theme = sys.argv[1], sys.argv[2]
try:
    content = open(config).read()
    new_import = f'import = ["{theme}"]'

    if re.search(r'import\s*=\s*\[', content):
        # Update existing import line
        content = re.sub(r'import\s*=\s*\[[^\]]*\]', new_import, content)
    elif '[general]' in content:
        # Add after [general] section header
        content = re.sub(r'(\[general\])', f'\\1\n{new_import}', content, count=1)
    else:
        # No [general] section — prepend one
        content = f'[general]\n{new_import}\n\n' + content

    open(config, 'w').write(content)
except Exception as e:
    print(e, file=sys.stderr)
    sys.exit(1)
