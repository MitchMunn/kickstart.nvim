# Changelog

Notable config changes and the reasoning behind them, kept for when we need to
revisit or rewrite a piece of this setup. Not every commit gets an entry — only
changes non-obvious enough that we'd otherwise have to re-derive the reasoning
from scratch.

## 2026-09-03 — Shrink the `init.lua` footprint for cheaper upstream syncs

**Ask:** After the `vim.pack` migration, make future upstream syncs low-effort
and add guardrails against regressions.

**What we did:** the migration pain was entirely in files upstream owns and
rewrites (`init.lua`, `lua/kickstart/**`). So we moved our customizations out:

- New `lua/custom/plugins/local-*.lua` files, `require`d by the existing
  directory-iterator loader _after_ all of `init.lua` has run — which means they
  can append to already-configured plugins:
  - `local-options.lua` — indent defaults, `<leader>td`, `<C-hjkl>` buffer-nav
    rebind (+ `vim.keymap.del` of the global `<C-k>` so the LSP map owns it),
    which-key group labels via `require('which-key').add`.
  - `local-lsp.lua` — the `LspAttach` autocmd (grX/grb quickfix, `<C-k>` /
    `<C-S-k>` / `<leader>g*` Glance) and the Ruff-hover-disable autocmd.
  - `local-format.lua` — pokes `require('conform').formatters_by_ft` /
    `.formatters.prettierd.env`, and its own `BufWritePre` autocmd for the
    format-on-save opt-out (kickstart's built-in `format_on_save` is an opt-_in_
    closure we can't extend after setup).
  - `local-lint.lua` — the markdownlint `--config` override. `lint.lua` is now
    byte-identical to upstream.
- What genuinely can't move (marked `-- LOCAL:` in `init.lua` so
  `git grep 'LOCAL:'` finds the whole merge surface): the `servers` table
  entries (feed mason-tool-installer + the `vim.lsp` loop), `lazydev` (must be
  added before blink's setup), the blink `lazydev` source (set at setup time).
- `scripts/healthcheck.lua` — headless smoke test asserting every module loaded,
  keymaps bound, LSP configs resolve, markdown parses. Run it after a sync
  (`nvim --headless -c 'luafile scripts/healthcheck.lua'`); catches `vim.pack`'s
  silent "didn't load" failures.
- Added an `upstream` git remote and enabled `rerere`. Sync workflow is in
  `CLAUDE.md`.

Net: `init.lua` now differs from upstream by ~1 small block plus the SECTION 10
`require` uncomments — a 15-minute merge instead of a day.

## 2026-09-03 — Catch up to kickstart upstream: `lazy.nvim` → `vim.pack`

**Ask:** Opening any Markdown file crashed on every `BufEnter` with
`attempt to call method 'range' (a nil value)` from
`nvim-treesitter/query_predicates.lua`. Root cause: `nvim-treesitter`'s `master`
branch is frozen (one docs commit since May 2025) and its README declares
**Neovim 0.12 not supported**; under 0.12 its injection-query predicate handlers
hit a treesitter API that changed and blow up. We run Neovim 0.12 (Homebrew
stable). The fix on the plugin side is its `main` branch — a full incompatible
rewrite.

Upstream kickstart already solved this, but as part of a larger move: it
**dropped `lazy.nvim` for `vim.pack`** (Neovim 0.12's built-in plugin manager)
and reorganized `init.lua` into ten numbered `SECTION` blocks. Rather than carry
a local one-off treesitter patch that diverges from upstream's structure, we
took the whole modernization.

**What was done** (3 commits — see
`docs/tickets/001-lazy-to-vim-pack-migration.md` for the full scoping):

1. Adopted upstream (`nvim-lua/kickstart.nvim@626c660`) verbatim for `init.lua`,
   `lua/kickstart/plugins/*`, `lua/kickstart/health.lua`,
   `lua/custom/plugins/init.lua` (now a directory iterator, no
   `{ import = ... }`), `.gitignore`, `.stylua.toml`. Deleted `lazy-lock.json`;
   track `nvim-pack-lock.json` instead (personal fork).
2. Ported the 8 `lua/custom/plugins/*` specs from lazy tables to `vim.pack`
   form: `vim.pack.add` + `require(x).setup` + explicit `vim.keymap.set` as
   top-level code. Lazy-loading (`cmd`/`keys`/`ft`/`event`) is gone — `vim.pack`
   has none; deps (`plenary`) are added explicitly first.
3. Re-applied our `init.lua` customizations into the new sections
   (diagnostics-toggle, buffer-nav `<C-hjkl>`, which-key groups, LSP quickfix +
   Glance maps, Ruff hover-disable, clangd/pyright/ruff configs, Mason
   `prettierd`/`markdownlint`, conform markdown wrap + `<leader>f`), plus the
   `lint.lua` markdownlint `--config` override.

**Deliberate deviations from upstream:**

- **`lazydev.nvim` re-added.** Upstream removed it; we keep it (Lua-LS types for
  the Neovim API while editing this config) and re-wire the `blink.cmp`
  `lazydev` source.
- **conform `format_on_save` stays opt-_out_**
  (`disable_filetypes = { c, cpp }`, on everywhere else). Upstream switched to
  opt-_in_ with an empty list, which would have silently turned off
  format-on-save for Lua and Markdown — the exact workflow CHANGELOG 2026-08-18
  exists for.
- **`nvim-web-devicons` dropped, not replaced.** Upstream's `mini.icons`
  devicons shim is gated on `vim.g.have_nerd_font`, which is `false` here, so
  there is no shim — matching that our old devicons spec was already gated the
  same way and thus inert.
- `nvim-pack-lock.json` is tracked (upstream ignores it to avoid PR conflicts; a
  personal fork wants reproducible installs).

**New toolchain dependency:** `nvim-treesitter@main` needs the `tree-sitter` CLI
≥ 0.26.1 from a package manager (not npm) —
`brew install tree-sitter tree-sitter-cli` (installed 0.27.0).

## 2026-09-02 — Let Mason install `markdownlint`

**Ask:** Opening any file (via Neo-tree) threw
`Error running markdownlint: ENOENT: no such file or directory` on every
`BufEnter`. `lua/kickstart/plugins/lint.lua` runs the `markdownlint` linter on
markdown buffers, but the binary was never installed — nothing in the config
told Mason to fetch it, so it only worked on machines where it happened to be on
`$PATH`.

**What we landed on:** added `'markdownlint'` to the `ensure_installed` list
that feeds `mason-tool-installer` in `init.lua` (next to `stylua` and
`prettierd`). Fresh clones now get the binary automatically on first startup.
Installed it on this machine with
`nvim --headless -c "lua require('mason-tool-installer').run_on_start()"`.

## 2026-08-18 — Auto-wrap markdown prose to satisfy markdownlint MD013

**Ask:** Markdown files were showing `MD013/line-length` warnings ("Expected 80:
Actual 205") from nvim-lint's `markdownlint` linter
(`lua/kickstart/plugins/lint.lua`). Wanted format-on-write to fix this
automatically instead of hand-wrapping prose.

**What didn't work:**

- Passing `--prose-wrap always --print-width 80` to `prettierd` via conform's
  `prepend_args`. `prettierd` is a daemon that only accepts a single file path
  on its command line — it silently rejected the extra flags ("Only a single
  file path is supported"), and `notify_on_error = false` swallowed the failure,
  so formatting just silently did nothing.
- Putting the config in `~/.prettierrc` / `~/.markdownlintrc`. This worked
  locally but doesn't travel with the repo — cloning this config on another
  machine wouldn't reproduce it, and there's nothing to `git diff` when it
  changes.

**What we landed on:** bundle the config _inside this repo_ and point tools at
it explicitly, so cloning the repo is self-sufficient.

- Added `.prettierrc.json` (repo root) — `proseWrap: always`, `printWidth: 80`.
- Added `.markdownlint.jsonc` (repo root) — disables `MD013` for code blocks and
  tables, since prettier deliberately never reflows those (would break code or
  misalign table columns), so flagging their length is just noise.
- `init.lua` (conform.nvim formatters): set
  `formatters.prettierd.env.PRETTIERD_DEFAULT_CONFIG` to
  `vim.fn.stdpath('config') .. '/.prettierrc.json'`. This is `prettierd`'s
  built-in fallback mechanism — verified empirically that it only applies when
  the file being formatted has no `.prettierrc` of its own closer by; a
  project-local config always wins over this default.
- `lua/kickstart/plugins/lint.lua`: overrode the `markdownlint` linter's `args`
  to add `--config <path>`, pointing at the bundled `.markdownlint.jsonc` via
  `vim.fn.stdpath('config')`. Necessary because markdownlint-cli does **not**
  search upward through parent directories for
  `.markdownlint.jsonc`/`.json`/`.yaml` — only the exact cwd it's invoked from
  (only the extensionless `.markdownlintrc` gets upward `rc`-style search, and
  that format is JSON/INI only).
- `vim.fn.stdpath('config')` (not a hardcoded `~/.config/nvim` path) keeps this
  working regardless of where the repo is cloned — respects `$XDG_CONFIG_HOME` /
  `NVIM_APPNAME`.
- Reformatted `README.md` against the new config to verify end-to-end; one line
  inside a raw `<details>` HTML block needed a manual wrap since prettier treats
  HTML blocks as opaque and won't reflow prose inside them.

**Result:** any markdown prose paragraph auto-wraps to 80 columns on save or
`<leader>f`. Code fences and tables are left alone and no longer flagged. Works
immediately after cloning the repo, no machine-local setup required.

## 2026-08-18 — Toggle diagnostics on/off

**Ask:** A way to turn diagnostic warnings/errors on and off in the editor.

**What we did:** added `<leader>td` in `init.lua`, next to the existing
`<leader>q` diagnostic loclist keymap:

```lua
vim.keymap.set('n', '<leader>td', function()
  vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end, { desc = '[T]oggle [D]iagnostics' })
```

This is the pattern Neovim's own `:help vim.diagnostic.enable()` docs recommend
for toggling. It affects all buffers and all diagnostic sources — both LSP
diagnostics and nvim-lint's (e.g. `markdownlint`) — since no namespace/buffer
filter is passed. It slots into the existing `<leader>t` "[T]oggle" which-key
group (alongside `<leader>th` for inlay hints). Documented in `WORKFLOW.md`
under "Diagnostics".
