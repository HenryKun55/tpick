# tpick

Interactive terminal theme picker with live preview.

Navigate themes with arrow keys and see changes applied instantly in your terminal — no config editing required.

## Features

- Live preview as you navigate — terminal updates on every keystroke
- Color swatches showing background, foreground, and the full 8-color palette
- 174 themes available via `tpick fetch` (sourced from [alacritty/alacritty-theme](https://github.com/alacritty/alacritty-theme))
- Restores your original theme if you press Esc
- Works on macOS and Linux (including WSL)

## Supported terminals

| Terminal | Status |
|---|---|
| Alacritty | ✅ Full support (live reload) |
| Kitty | 🔜 Coming soon |
| Ghostty | 🔜 Coming soon |

## Requirements

- `python3`
- [`fzf`](https://github.com/junegunn/fzf)

## Install

**One-liner:**
```bash
curl -fsSL https://raw.githubusercontent.com/HenryKun55/tpick/main/install.sh | bash
```

**Manual (for dotfiles users):**
```bash
git clone https://github.com/HenryKun55/tpick ~/.tpick
# Add to your .zshrc or .bashrc:
echo 'source ~/.tpick/tpick.sh' >> ~/.zshrc
source ~/.zshrc
```

## Usage

```bash
# Download 174 themes from alacritty/alacritty-theme
tpick fetch

# Open the picker (auto-detects terminal)
tpick

# Force Alacritty mode
tpick --alacritty
```

**Controls:**

| Key | Action |
|---|---|
| `↑` / `↓` | Navigate (theme applies live) |
| `Enter` | Confirm selection |
| `Esc` | Cancel and restore original theme |
| `/` | Search by name |

## How it works

tpick updates the `import = [...]` line in your `alacritty.toml` as you navigate. Alacritty watches the config file and reloads instantly (`live_config_reload = true`). On Esc, the original import is restored.

## Custom config path

```bash
export ALACRITTY_CONFIG="$HOME/.config/alacritty/alacritty.toml"
export TPICK_THEMES_DIR="$HOME/.local/share/tpick/themes"
```

## Adding your own themes

Drop any `.toml` file with valid Alacritty color definitions next to your `alacritty.toml` — tpick picks them up automatically.

## License

MIT
