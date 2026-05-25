# tpick

> Pick your terminal theme without leaving the terminal.

You know the drill: you want a new theme for your terminal, spend 30 minutes googling, find a repo with hundreds of themes, manually edit your config, restart the terminal, hate the color, repeat. **tpick fixes that.**

Navigate themes with arrow keys and the terminal updates *live* as you move — no config editing, no restarts. Press Esc if you don't like anything and your original theme comes right back.

```
tpick fetch   # grab themes from the official alacritty-theme repo
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
- Optionally download all themes right away

**Already have dotfiles? Just add one line:**
```bash
git clone https://github.com/HenryKun55/tpick ~/.tpick
echo 'source ~/.tpick/tpick.sh' >> ~/.zshrc
source ~/.zshrc
```

---

## Usage

```bash
tpick                  # auto-detect terminal and open picker
tpick --dark           # show only dark themes
tpick --light          # show only light themes
tpick --favorites      # show only your starred themes
tpick random           # apply a random theme
tpick random --dark    # apply a random dark theme
tpick random --light   # apply a random light theme
tpick fav              # list your favorites
tpick fetch            # download themes from alacritty/alacritty-theme
tpick update           # update tpick itself and download new themes
tpick --alacritty      # force Alacritty mode
tpick --claude         # Claude Code theme picker
tpick --help           # show all options
```

**Controls inside the picker:**

| Key | Action |
|---|---|
| `↑` / `↓` or `Tab` / `Shift-Tab` | Navigate — theme applies live |
| `Ctrl-D` / `Ctrl-U` | Scroll half-page down/up (fast browsing) |
| `Ctrl-F` | Toggle ★ favorite (list updates instantly) |
| `Enter` | Confirm and keep the theme |
| `Esc` | Cancel and restore your original theme |
| `/` + type | Search by name |

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

## Sync

After you confirm a theme, tpick automatically syncs it everywhere:

- **Neovim** — sends `:colorscheme` to every running instance via `--server` (works with catppuccin, dracula, nord, gruvbox, tokyonight, onedark, everforest, rose-pine, kanagawa, nightfox and more)
- **tmux** — updates the status bar background, foreground, and active border to match the new palette

**Custom hook:** define `tpick_on_change()` in `~/.tpick/hooks.sh` and it'll be called after every theme change with the theme name and path as arguments:

```bash
# ~/.tpick/hooks.sh
tpick_on_change() {
  local theme_name="$1"   # e.g. "catppuccin_mocha"
  local theme_path="$2"   # e.g. "/path/to/catppuccin_mocha.toml"
  # do whatever you want here
}
```

---

## Claude Code themes

```bash
tpick --claude
```

Picks from Claude Code's built-in themes (`dark`, `light`, `dark-daltonism`, `light-daltonism`) plus any custom themes you have in `~/.claude/themes/`. The preview shows how the diff colors and accent palette will look.

> Claude Code doesn't live-reload themes — you need to restart it after changing. The picker updates `~/.claude/settings.json` for you.

**Creating a custom theme:**

Drop a `.json` file in `~/.claude/themes/`:

```json
{
  "name": "my-theme",
  "base": "dark",
  "overrides": {
    "green_FOR_SUBAGENTS_ONLY": "rgb(34, 197, 94)",
    "red_FOR_SUBAGENTS_ONLY": "rgb(239, 68, 68)"
  }
}
```

Then run `tpick --claude` and select `custom:my-theme`.

---

## Adding your own themes

Drop any `.toml` file with Alacritty color definitions next to your `alacritty.toml` and tpick picks it up automatically — no config needed.

---

## Environment variables

```bash
export TPICK_DIR="$HOME/.tpick"                            # install location
export TPICK_THEMES_DIR="$HOME/.local/share/tpick/themes"  # downloaded themes
export TPICK_FAVORITES="$HOME/.local/share/tpick/favorites" # favorites list
export ALACRITTY_CONFIG="$HOME/.config/alacritty/alacritty.toml"
```

---

## License

MIT
