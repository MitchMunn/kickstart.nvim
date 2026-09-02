# CLAUDE.md

## What this repo is

A fork of [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim),
customized for personal use. `README.md` is still the original upstream
kickstart doc (installation instructions for anyone starting fresh) — it is
**not** a record of what's been customized here.

## Structure

- `init.lua` — the main config. Since 2026-09-03 it follows upstream's
  `vim.pack` rewrite: ten numbered `SECTION` blocks, each plugin added with
  `vim.pack.add` + an explicit `require(x).setup(...)`. No `lazy.nvim`.
- `lua/kickstart/plugins/*.lua` — base kickstart plugin files, kept
  byte-identical to upstream so syncs stay clean.
- `lua/custom/plugins/*.lua` — everything local. The loader
  (`lua/custom/plugins/init.lua`) `require`s every file here after all of
  `init.lua` has run, so a file can add plugins _or_ just set options, keymaps
  and autocmds. `local-*.lua` files hold customizations that used to live in
  `init.lua`.
- `scripts/healthcheck.lua` — fast post-sync smoke test. Run with
  `nvim --headless -c 'luafile scripts/healthcheck.lua'`; exits non-zero on any
  failure.
- `docs/tickets/*.md` — scoped work items.
- `WORKFLOW.md` — living cheat sheet of keymaps/commands. Update it whenever a
  keymap changes.
- `CHANGELOG.md` — log of notable config changes and the reasoning behind them.
  See below.

## Keep customizations out of upstream-owned files

Editing `init.lua` / `lua/kickstart/**` is what makes upstream syncs painful.
Prefer a new `lua/custom/plugins/local-*.lua` file — by the time it loads,
which-key, conform, LSP, telescope, treesitter etc. are all set up, so you can
append to them (`require('conform').formatters_by_ft.x = ...`,
`require('which-key').add {...}`, an extra `LspAttach` autocmd, …).

A few things genuinely can't move (they must run at a specific point in
`init.lua`): the `servers` table entries, `lazydev` (before blink's setup), and
the blink `lazydev` source. Mark every such spot with a `-- LOCAL:` comment so
`git grep 'LOCAL:'` lists the entire merge surface before a sync.

The `lua/custom/plugins/` loader is fail-fast and iterates in
filesystem-nondeterministic order: an error in one `local-*.lua` aborts the loop
and silently skips whatever hadn't loaded yet. So **run
`scripts/healthcheck.lua` after touching any `local-*.lua`** — a stray typo in
one file can take out unrelated plugins with no obvious link.

## Syncing with upstream kickstart

```sh
git remote add upstream https://github.com/nvim-lua/kickstart.nvim.git   # once
git fetch upstream && git log --oneline master..upstream/master           # review
git merge upstream/master                                                 # resolve the small init.lua conflict
```

Do it every month or two (small batches), not once a year. After merging: run
`scripts/healthcheck.lua`, then the interactive checklist in
`docs/tickets/001-*.md`. `git config rerere.enabled true` makes repeated
conflict resolutions automatic.

## Update CHANGELOG.md for important config changes

When you make a change to this config that's non-obvious enough that we'd
otherwise have to re-derive the reasoning later — a new plugin, a workaround for
a tool limitation, a non-default config choice, anything where "why did we do it
this way" isn't obvious from the diff alone — add an entry to `CHANGELOG.md`.

Skip it for trivial/self-explanatory changes (typo fixes, version bumps,
formatting). Follow the existing entry format: a dated `##` heading, an **Ask**
describing what was requested, and what was done — including approaches that
were tried and rejected, and why, if that's part of the story. Don't back-fill
history for changes made before this file existed.

If the change also affects a keymap, update `WORKFLOW.md` too.
