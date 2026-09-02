# Changelog

Notable config changes and the reasoning behind them, kept for when we need to
revisit or rewrite a piece of this setup. Not every commit gets an entry —
only changes non-obvious enough that we'd otherwise have to re-derive the
reasoning from scratch.

## 2026-09-02 — Let Mason install `markdownlint`

**Ask:** Opening any file (via Neo-tree) threw
`Error running markdownlint: ENOENT: no such file or directory` on every
`BufEnter`. `lua/kickstart/plugins/lint.lua` runs the `markdownlint` linter
on markdown buffers, but the binary was never installed — nothing in the
config told Mason to fetch it, so it only worked on machines where it
happened to be on `$PATH`.

**What we landed on:** added `'markdownlint'` to the `ensure_installed` list
that feeds `mason-tool-installer` in `init.lua` (next to `stylua` and
`prettierd`). Fresh clones now get the binary automatically on first
startup. Installed it on this machine with
`nvim --headless -c "lua require('mason-tool-installer').run_on_start()"`.

## 2026-08-18 — Auto-wrap markdown prose to satisfy markdownlint MD013

**Ask:** Markdown files were showing `MD013/line-length` warnings ("Expected
80: Actual 205") from nvim-lint's `markdownlint` linter
(`lua/kickstart/plugins/lint.lua`). Wanted format-on-write to fix this
automatically instead of hand-wrapping prose.

**What didn't work:**

- Passing `--prose-wrap always --print-width 80` to `prettierd` via conform's
  `prepend_args`. `prettierd` is a daemon that only accepts a single file
  path on its command line — it silently rejected the extra flags
  ("Only a single file path is supported"), and `notify_on_error = false`
  swallowed the failure, so formatting just silently did nothing.
- Putting the config in `~/.prettierrc` / `~/.markdownlintrc`. This worked
  locally but doesn't travel with the repo — cloning this config on another
  machine wouldn't reproduce it, and there's nothing to `git diff` when it
  changes.

**What we landed on:** bundle the config *inside this repo* and point tools
at it explicitly, so cloning the repo is self-sufficient.

- Added `.prettierrc.json` (repo root) — `proseWrap: always`, `printWidth: 80`.
- Added `.markdownlint.jsonc` (repo root) — disables `MD013` for code blocks
  and tables, since prettier deliberately never reflows those (would break
  code or misalign table columns), so flagging their length is just noise.
- `init.lua` (conform.nvim formatters): set
  `formatters.prettierd.env.PRETTIERD_DEFAULT_CONFIG` to
  `vim.fn.stdpath('config') .. '/.prettierrc.json'`. This is `prettierd`'s
  built-in fallback mechanism — verified empirically that it only applies
  when the file being formatted has no `.prettierrc` of its own closer by; a
  project-local config always wins over this default.
- `lua/kickstart/plugins/lint.lua`: overrode the `markdownlint` linter's
  `args` to add `--config <path>`, pointing at the bundled
  `.markdownlint.jsonc` via `vim.fn.stdpath('config')`. Necessary because
  markdownlint-cli does **not** search upward through parent directories for
  `.markdownlint.jsonc`/`.json`/`.yaml` — only the exact cwd it's invoked
  from (only the extensionless `.markdownlintrc` gets upward `rc`-style
  search, and that format is JSON/INI only).
- `vim.fn.stdpath('config')` (not a hardcoded `~/.config/nvim` path) keeps
  this working regardless of where the repo is cloned — respects
  `$XDG_CONFIG_HOME` / `NVIM_APPNAME`.
- Reformatted `README.md` against the new config to verify end-to-end; one
  line inside a raw `<details>` HTML block needed a manual wrap since
  prettier treats HTML blocks as opaque and won't reflow prose inside them.

**Result:** any markdown prose paragraph auto-wraps to 80 columns on save or
`<leader>f`. Code fences and tables are left alone and no longer flagged.
Works immediately after cloning the repo, no machine-local setup required.

## 2026-08-18 — Toggle diagnostics on/off

**Ask:** A way to turn diagnostic warnings/errors on and off in the editor.

**What we did:** added `<leader>td` in `init.lua`, next to the existing
`<leader>q` diagnostic loclist keymap:

```lua
vim.keymap.set('n', '<leader>td', function()
  vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end, { desc = '[T]oggle [D]iagnostics' })
```

This is the pattern Neovim's own `:help vim.diagnostic.enable()` docs
recommend for toggling. It affects all buffers and all diagnostic sources —
both LSP diagnostics and nvim-lint's (e.g. `markdownlint`) — since no
namespace/buffer filter is passed. It slots into the existing `<leader>t`
"[T]oggle" which-key group (alongside `<leader>th` for inlay hints).
Documented in `WORKFLOW.md` under "Diagnostics".
