# CLAUDE.md

## What this repo is

A fork of [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim),
customized for personal use. `README.md` is still the original upstream
kickstart doc (installation instructions for anyone starting fresh) — it is
**not** a record of what's been customized here.

## Structure

- `init.lua` — the main config, kickstart-style (mostly one file).
- `lua/kickstart/plugins/*.lua` — base kickstart plugin specs, some modified
  in place for this fork's needs (e.g. `lint.lua`).
- `lua/custom/plugins/*.lua` — plugins added on top of kickstart, not part of
  upstream.
- `WORKFLOW.md` — living cheat sheet of keymaps/commands. Update it whenever
  a keymap changes.
- `CHANGELOG.md` — log of notable config changes and the reasoning behind
  them. See below.

## Update CHANGELOG.md for important config changes

When you make a change to this config that's non-obvious enough that we'd
otherwise have to re-derive the reasoning later — a new plugin, a workaround
for a tool limitation, a non-default config choice, anything where "why did
we do it this way" isn't obvious from the diff alone — add an entry to
`CHANGELOG.md`.

Skip it for trivial/self-explanatory changes (typo fixes, version bumps,
formatting). Follow the existing entry format: a dated `##` heading, an
**Ask** describing what was requested, and what was done — including
approaches that were tried and rejected, and why, if that's part of the
story. Don't back-fill history for changes made before this file existed.

If the change also affects a keymap, update `WORKFLOW.md` too.
