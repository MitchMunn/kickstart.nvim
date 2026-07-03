# Workflow reference

A living cheat sheet for the bindings and commands in this config. Update this
alongside `init.lua`/`lua/custom/plugins/*.lua` whenever a keymap changes —
treat it as documentation, not a source of truth (the code always wins if
they disagree).

`<leader>` is `<space>`.

## Buffers, windows, panes

| Key | Action |
|---|---|
| `<C-h>` | Previous buffer (`:bprevious`) |
| `<C-l>` | Next buffer (`:bnext`) |
| `<C-w>h/j/k/l` | Move focus between Neovim splits (native) |
| `Alt+h/j/k/l` | Move focus between Zellij panes (Zellij default, not Neovim) |
| `<leader><leader>` | Find existing buffers (Telescope) |
| `\` | Reveal current file in Neotree / close Neotree if already open |

`<C-h>` only works if Zellij's default `Ctrl h` (its "Move pane" mode) has been
unbound in `~/.config/zellij/config.kdl` — see the Zellij section below.

## LSP navigation

| Key | Action |
|---|---|
| `<C-k>` | Go to definition (jumps away) |
| `<C-j>` | Jump back (`<C-o>`, native jumplist) |
| `<C-S-k>` or `<leader>gd` | Peek definition in a floating window (Glance), without leaving the buffer |
| `<leader>gr` | Glance: peek references |
| `<leader>gy` | Glance: peek type definitions |
| `<leader>gm` | Glance: peek implementations |
| `grd` | Go to definition (Telescope list) |
| `grD` | Go to *declaration* (not definition — e.g. C headers) |
| `gri` | Go to implementation |
| `grr` | Find references |
| `grt` | Go to type definition |
| `grn` | Rename symbol |
| `gra` | Code action |
| `grX` | Apply all available quickfixes in the buffer |
| `grb` | Buffer-wide quickfix picker |
| `gO` | Document symbols |
| `gW` | Workspace symbols |
| `<leader>th` | Toggle inlay hints (only when the LSP supports them) |

Inside Glance's floating window: `<C-v>`/`<C-x>`/`<C-t>` open the result in a
vsplit/split/tab, `q`/`<Esc>` closes it.

## Search (Telescope)

| Key | Action |
|---|---|
| `<leader>sf` | Search files |
| `<leader>sg` | Live grep |
| `<leader>sw` | Search current word |
| `<leader>sd` | Search diagnostics |
| `<leader>sh` | Search help |
| `<leader>sk` | Search keymaps |
| `<leader>ss` | Search Telescope pickers themselves |
| `<leader>sr` | Resume last search |
| `<leader>s.` | Recent files |
| `<leader>sn` | Search Neovim config files |
| `<leader>s/` | Live grep in currently open files only |
| `<leader>/` | Fuzzy search in current buffer |

### Search-and-replace across files (project-wide)

**`<C-S-f>` or `<leader>sR`** opens grug-far — a VSCode `Ctrl+Shift+F`-style
panel: live regex search and replace, per-match toggles, include/exclude glob
filters, and a preview before applying. This is the go-to for anything beyond
a quick one-off substitution. `<C-S-f>` depends on your terminal/multiplexer
passing through the extended Ctrl+Shift keycode (same caveat as `<C-S-k>`
above) — `<leader>sR` always works regardless.

For quick one-off substitutions without leaving the quickfix flow (formerly
in `reminder_commands.md`):

```
<leader>sg              " search for 'my_search_string' via live grep
<C-q>                   " send all results to the quickfix list
:cdo %s/old/new/g | update   " run the substitution across every file in the list, saving each
```

## Diagnostics

| Key | Action |
|---|---|
| `<leader>q` | Native diagnostic loclist |
| `<leader>xx` | Trouble: workspace diagnostics |
| `<leader>xw` | Trouble: current-buffer diagnostics |
| `<leader>xq` | Trouble: quickfix list |
| `<leader>xl` | Trouble: location list |

## Git (gitsigns)

| Key | Action |
|---|---|
| `]c` / `[c` | Next/previous hunk |
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk |
| `<leader>hS` | Stage buffer |
| `<leader>hR` | Reset buffer |
| `<leader>hu` | Undo stage hunk |
| `<leader>hp` | Preview hunk |
| `<leader>hb` | Blame line |
| `<leader>hd` | Diff against index |
| `<leader>hD` | Diff against last commit |
| `<leader>tb` | Toggle current-line blame |
| `<leader>tD` | Toggle deleted-lines preview |

## Terminal (toggleterm)

| Key | Action |
|---|---|
| `<C-\>` or `<leader>tt` | Toggle a floating terminal |
| `<leader>tv` | Open a vertical split terminal |
| `<Esc><Esc>` (in terminal mode) | Exit terminal mode |

## Harpoon (pinned files)

| Key | Action |
|---|---|
| `<leader>a` | Add current file to Harpoon |
| `<C-e>` | Toggle the Harpoon quick-menu |
| `<C-1>` .. `<C-4>` or `<leader>1` .. `<leader>4` | Jump straight to marked file 1-4 |

## Formatting / editing tools

| Key | Action |
|---|---|
| `<leader>f` | Format buffer (conform.nvim) |
| `<leader>u` | Toggle Undotree |
| `<leader>m` | Toggle rendered Markdown view |
| `<leader>zz` or `<C-0>` (best-effort) | Toggle Zen Mode |

## Debugging (DAP)

| Key | Action |
|---|---|
| `<F5>` | Start/continue |
| `<F1>` | Step into |
| `<F2>` | Step over |
| `<F3>` | Step out |
| `<F7>` | Toggle the last debug session's UI |
| `<leader>b` | Toggle breakpoint |
| `<leader>B` | Set conditional breakpoint |

## Zellij (outside Neovim)

Zellij handles all pane/tab management for this setup — Neovim is run as one
full-window instance per pane, no `:split`/`:vsplit`.

| Key | Action |
|---|---|
| `Alt+h/j/k/l` | Move focus between panes |
| `Alt+f` | Toggle floating panes |
| `Alt+n` | New pane |
| `Ctrl+q` | Quit (with confirmation, via the `zj-quit` plugin) |
| `Ctrl+g` | Toggle locked mode (disables all Zellij shortcuts, passes keys straight to the app) |

`~/.config/zellij/config.kdl` also unbinds the stock `Ctrl h` ("Move pane"
mode) and rebinds it to `Alt+m`, freeing `Ctrl+h` so it reaches Neovim as
"previous buffer" instead.
