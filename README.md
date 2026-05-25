# tpick

> Pick your terminal theme without leaving the terminal.

You know the drill: you want a new theme for your terminal, spend 30 minutes googling, find a repo with 174 themes, manually edit your config, restart the terminal, hate the color, repeat. **tpick fixes that.**

Navigate themes with arrow keys and the terminal updates *live* as you move — no config editing, no restarts. Press Esc if you don't like anything and your original theme comes right back.

```
tpick fetch   # grab 174 themes from the official alacritty-theme repo
tpick         # open the picker, arrow keys, done
```

---

## How it works

tpick updates the `import = [...]` line in your `alacritty.toml` as you navigate. Alacritty watches the config file and reloads it instantly (that's what `live_config_reload = true` does). Press Enter to confirm, Esc to undo — simple as that.

The installer takes care of enabling `live_config_reload` automatically if it's not set yet.

---

## Install

**One-liner (recommended):**
```bash
curl -fsSL https://raw.githubusercontent.com/HenryKun55/tpick/main/install.sh | bash
```

The installer will:
- Check and install `fzf` if missing (macOS, Ubuntu, Arch)
- Detect your terminal config automatically
- Enable `live_config_reload` in Alacritty if needed
- Add one line to your `.zshrc` / `.bashrc`
- Optionally download all 174 themes right away

**Already have dotfiles? Just add one line:**
```bash
git clone https://github.com/HenryKun55/tpick ~/.tpick
echo 'source ~/.tpick/tpick.sh' >> ~/.zshrc
source ~/.zshrc
```

---

## Usage

```bash
tpick              # auto-detect terminal and open picker
tpick fetch        # download 174 themes from alacritty/alacritty-theme
tpick --alacritty  # force Alacritty mode
tpick --help       # show all options
```

**Controls inside the picker:**

| Key | Action |
|---|---|
| `↑` / `↓` | Navigate — theme applies live |
| `Enter` | Confirm and keep the theme |
| `Esc` | Cancel and restore your original theme |
| `/` | Search by name |

---

## Requirements

- `python3` (pre-installed on macOS and most Linux distros)
- [`fzf`](https://github.com/junegunn/fzf) — the installer offers to get this for you

---

## Supported terminals

| Terminal | Status |
|---|---|
| **Alacritty** | ✅ Full support with live reload |
| Kitty | 🔜 Coming soon |
| Ghostty | 🔜 Coming soon |
| WezTerm | 🔜 Coming soon |

Works on macOS and Linux (including WSL).

---

## Adding your own themes

Drop any `.toml` file with Alacritty color definitions next to your `alacritty.toml` and tpick picks it up automatically — no config needed.

---

## Custom paths

```bash
export ALACRITTY_CONFIG="$HOME/.config/alacritty/alacritty.toml"
export TPICK_THEMES_DIR="$HOME/.local/share/tpick/themes"
```

---

## License

MIT
