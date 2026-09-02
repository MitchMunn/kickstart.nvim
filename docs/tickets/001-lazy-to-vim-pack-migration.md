# Ticket 001 — Catch up to kickstart upstream (lazy.nvim → vim.pack)

<!-- markdownlint-disable MD013 -->
<!-- Reference doc: many lines are unbreakable inline-code spans. -->

- **Status:** done — implemented 2026-09-03 on branch `vim-pack-migration` (3
  commits: upstream base → custom plugin ports → local customizations). See
  CHANGELOG 2026-09-03.
- **Created:** 2026-09-03
- **Owner:** —

---

## Problem that triggered this

Opening any Markdown file (README included) throws, on every `BufEnter`:

```text
vim.schedule callback: .../vim/treesitter.lua:197: attempt to call method 'range' (a nil value)
  ...nvim-treesitter/lua/nvim-treesitter/query_predicates.lua:141: in function 'handler'
  ...render-markdown.nvim/lua/render-markdown/request/view.lua:62: in function 'parse'
```

### Root cause

`nvim-treesitter` is pinned to its **`master` branch**, which upstream **froze
in May 2025** and explicitly marks **"Neovim 0.12 not supported"** (`git log` on
that branch: one docs-only commit in 16 months; README _Requirements_ section
says "Neovim 0.10 or 0.11 (Neovim 0.12 is **not supported**)").

We run Neovim **0.12.3** (Homebrew stable is already 0.12.5). Under 0.12 the
treesitter core calls a query **directive handler that the frozen
`nvim-treesitter` registers** (`query_predicates.lua:141`), and that handler
uses a treesitter API shape that changed in 0.12 → `node:range()` is nil →
crash. It fires through `render-markdown.nvim`'s parse cycle but is not
render-markdown's fault; any injection-query path hits it.

The fix on the `nvim-treesitter` side is to move to its **`main` branch** — a
full, intentionally-incompatible rewrite that is the only version supporting
current Neovim.

### Why this became a full upstream catch-up

Upstream kickstart already solved this — but as part of a **much larger change:
it dropped `lazy.nvim` and moved the whole config to `vim.pack`** (Neovim 0.12's
built-in plugin manager). Treesitter-on-`main` is one section of that rewrite.
We decided to take the whole upstream modernization in one deliberate pass
rather than carry a local one-off treesitter patch that diverges from upstream's
structure.

---

## Reference points

| Thing                                                          | Value                                                             |
| -------------------------------------------------------------- | ----------------------------------------------------------------- |
| Our `HEAD` at scoping time                                     | `ee20db4` (`added markdownlint to Mason's ensure_installed list`) |
| Fork point (merge-base with upstream)                          | `3338d39` (`Update remaining Mason's old address (#1530)`)        |
| Upstream `nvim-lua/kickstart.nvim@master` tip used for scoping | `626c660` (`Update the CI actions`, 2026-08-07)                   |
| Divergence                                                     | upstream +85 commits, us +12 commits since `3338d39`              |

Fetch upstream for implementation with:

```sh
git fetch https://github.com/nvim-lua/kickstart.nvim.git master
# upstream tree is then FETCH_HEAD
```

Reference material for `vim.pack`: `:help vim.pack`, `:help vim.pack-examples`,
and <https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack>

---

## Scope

### What upstream changed (the delta we're adopting)

`git diff 3338d39..FETCH_HEAD --stat` highlights:

| File                                     | Churn                            | Nature                                                                                                                                                                                                                                                                                   |
| ---------------------------------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `init.lua`                               | **+840 / −870** (~half the file) | `require('lazy').setup({...})` removed; reorganized into 10 numbered `SECTION` blocks; every plugin spec rewritten as `vim.pack.add{...}` + explicit `require(x).setup(...)`; lazy conventions (`opts` / `config` / `event` / `cmd` / `ft` / `keys` / `dependencies` / `build`) all gone |
| `lua/kickstart/plugins/debug.lua`        | −207                             | rewritten for `vim.pack`                                                                                                                                                                                                                                                                 |
| `lua/kickstart/plugins/gitsigns.lua`     | ~100                             | rewritten for `vim.pack`                                                                                                                                                                                                                                                                 |
| `lua/kickstart/plugins/lint.lua`         | −107                             | rewritten for `vim.pack` (now `vim.pack.add{...}` + top-level code, no returned spec)                                                                                                                                                                                                    |
| `lua/kickstart/plugins/neo-tree.lua`     | ~31                              | rewritten for `vim.pack`                                                                                                                                                                                                                                                                 |
| `lua/kickstart/plugins/autopairs.lua`    | ~7                               | rewritten for `vim.pack`                                                                                                                                                                                                                                                                 |
| `lua/kickstart/plugins/indent_line.lua`  | ~15                              | rewritten for `vim.pack`                                                                                                                                                                                                                                                                 |
| `lua/custom/plugins/init.lua`            | ~10                              | now auto-iterates and `require`s every `*.lua` in `lua/custom/plugins/` (except `init.lua`) — no more `{ import = ... }`                                                                                                                                                                 |
| `README.md`                              | +163                             | doc updates                                                                                                                                                                                                                                                                              |
| `.github/`, `.gitignore`, `.stylua.toml` | small                            | CI + ignore tweaks                                                                                                                                                                                                                                                                       |

Key structural facts about upstream's new `init.lua`:

- **Sections:** `1 OPTIONS`, `2 KEYMAPS & AUTOCMDS`, `3 PLUGIN MANAGER INTRO`,
  `4 UI / CORE UX PLUGINS`, `5 SEARCH & NAVIGATION`, `6 LSP`, `7 FORMATTING`,
  `8 AUTOCOMPLETE & SNIPPETS`, `9 TREESITTER`,
  `10 OPTIONAL EXAMPLES / NEXT STEPS`.
- A `gh` helper builds GitHub URLs: `local function gh(repo) ... end`, used as
  `vim.pack.add { { src = gh 'owner/repo', version = 'main' } }`.
- **Build steps** are handled by one `PackChanged` autocmd in SECTION 3 with a
  `run_build(name, cmd, cwd)` helper. It already covers
  `telescope-fzf-native.nvim` (`make`), `LuaSnip` (`make install_jsregexp`), and
  `nvim-treesitter` (`packadd` + `TSUpdate`). New plugins needing a build get
  another `if name == ... then` branch here.
- **Treesitter (SECTION 9)** is exactly the shape we want:
  `vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }`,
  `require('nvim-treesitter').install(parsers)`, then a `FileType` autocmd:
  resolve `vim.treesitter.language.get_lang(ft)`, and
  - if installed → `treesitter_try_attach(buf, lang)`
  - elseif in `get_available()` → `install(lang):await(...)` then attach
  - else → best-effort attach `treesitter_try_attach` does
    `vim.treesitter.language.add`, `vim.treesitter.start`, and sets `indentexpr`
    only when `vim.treesitter.query.get(lang, 'indents')` exists.
- **`mini.nvim` moved org:** upstream now uses `nvim-mini/mini.nvim` (not
  `echasnovski/mini.nvim`) and calls `require('mini.icons').setup()` +
  `mini.icons.mock_nvim_web_devicons()` — this **replaces `nvim-web-devicons`**
  as a dependency for anything that wants devicons.
- **`blink.cmp`** is already the completion engine both upstream and in our fork
  (`saghen/blink.cmp`), pinned `version = vim.version.range '1.*'`. No cmp
  migration needed.
- **`lazydev.nvim` was removed upstream** (merge-base kickstart had it; upstream
  `626c660` has zero references). We use it and want it back — see task 6.
- Upstream `lua/` no longer contains `lazy` bootstrap; `lazy-lock.json` is
  obsolete (vim.pack keeps its own state; see `:help vim.pack`).

### What we changed (our +12 commits — everything that must be re-applied)

`git diff 3338d39..HEAD --stat`:

```text
 .markdownlint.jsonc                    |  10 +   new, no conflict
 .prettierrc.json                       |   4 +   new, no conflict
 CHANGELOG.md                           |  91 +   append-only, no conflict
 CLAUDE.md                              |  36 +   ours, no conflict
 WORKFLOW.md                            | 165 +   ours, no conflict
 init.lua                               | 129 +   << MUST RE-APPLY (12 hunks, see below)
 lua/custom/lsp_quickfix.lua            | 437 +   manager-agnostic, drops in as-is
 lua/custom/plugins/glance.lua          |   7 +   << PORT to vim.pack
 lua/custom/plugins/grug-far.lua        |  23 +   << PORT
 lua/custom/plugins/harpoon.lua         |  26 +   << PORT
 lua/custom/plugins/render-markdown.lua |  15 +   << PORT
 lua/custom/plugins/toggleterm.lua      |  20 +   << PORT
 lua/custom/plugins/trouble.lua         |  27 +   << PORT
 lua/custom/plugins/undotree.lua        |  14 +   << PORT
 lua/custom/plugins/zen-mode.lua        |  13 +   << PORT
 lua/kickstart/plugins/lint.lua         |   7 +   << RE-APPLY onto upstream rewrite
```

This is **not a `git merge`** — both sides rewrote overlapping regions of 7
files; a merge would be a conflict slog and a fragile result. The plan is:
**take upstream's `init.lua` + `lua/kickstart/` + `lua/custom/plugins/init.lua`
wholesale, then re-apply our deltas translated to `vim.pack` idiom.**

---

## Implementation plan

### 1. Adopt upstream files wholesale

Copy from `FETCH_HEAD` verbatim, then make ours again in later steps:

- `init.lua`
- `lua/kickstart/plugins/{debug,gitsigns,lint,neo-tree,autopairs,indent_line}.lua`
- `lua/kickstart/health.lua`
- `lua/custom/plugins/init.lua` (the new auto-iterating loader)
- `.gitignore`, `.stylua.toml`, `.github/**`, `README.md`

Do **not** take upstream's `CHANGELOG.md` / `WORKFLOW.md` / `CLAUDE.md` /
`.markdownlint.jsonc` / `.prettierrc.json` — those are ours or append-only.

Delete `lazy-lock.json` (obsolete under vim.pack). Remove any lazy.nvim
bootstrap remnants. After first launch, `~/.local/share/nvim/lazy/` can be
deleted once vim.pack has populated `~/.local/share/nvim/site/pack/`.

### 2. Port the 8 custom plugin specs to `vim.pack`

Each file currently `return {...}` a lazy spec. Under the new loader, each file
is just `require`d for side effects — so each becomes: `vim.pack.add {...}`,
then `require(mod).setup(opts)`, then `vim.keymap.set(...)` for every former
`keys` entry, and **lazy-loading is dropped** (or replaced with a `FileType` /
`User` / `CmdUndefined` autocmd only if startup cost actually matters — measure
first, most of these are cheap). Add dependencies with their own `vim.pack.add`
**before** the dependent's `setup()`.

| File                  | Repo                                         | Former lazy keys                                                                                                        | Port notes                                                                                                                                                                                                                                                                                                           |
| --------------------- | -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `glance.lua`          | `DNLHC/glance.nvim`                          | `cmd`, `opts = { detached = true }`                                                                                     | `vim.pack.add`; `require('glance').setup { detached = true }`. No keymaps in this file — Glance maps live in `init.lua` LSP section (task 3). Drop `cmd` lazy-load.                                                                                                                                                  |
| `grug-far.lua`        | `MagicDuck/grug-far.nvim`                    | `cmd`, `keys` (`<C-S-f>`, `<leader>sR` — n+v), `opts = {}`                                                              | `setup {}`; set both maps for `mode = { 'n', 'v' }` calling `require('grug-far').open`.                                                                                                                                                                                                                              |
| `harpoon.lua`         | `ThePrimeagen/harpoon` **branch `harpoon2`** | `dependencies = { plenary }`, `config` already sets maps                                                                | `vim.pack.add { { src = gh 'ThePrimeagen/harpoon', version = 'harpoon2' } }`. Ensure `plenary` added first (it will already be present from telescope/gitsigns, but add explicitly to be safe). Body of current `config` moves out as-is. Maps: `<leader>a`, `<C-e>`, `<C-1..4>`, `<leader>1..4`.                    |
| `render-markdown.lua` | `MeanderingProgrammer/render-markdown.nvim`  | `ft = { markdown }`, `dependencies = { nvim-treesitter, nvim-web-devicons }`, `opts = {}`, `keys` (`<leader>m` toggle)  | treesitter is added in SECTION 9 already; **devicons is now `mini.icons` mock** — no separate devicons plugin needed. `setup {}` then `<leader>m` → `require('render-markdown').toggle`. Loading unconditionally is fine; if we want to keep it markdown-only, wrap `setup` in a `FileType markdown` autocmd (once). |
| `toggleterm.lua`      | `akinsho/toggleterm.nvim`                    | `opts = { open_mapping = [[<c-\>]], direction = 'float', shade_terminals = true }`, `keys` (`<leader>tt`, `<leader>tv`) | **`open_mapping` collides with upstream's terminal-mode `<Esc><Esc>` / kickstart's `<C-\>` nothing — but note SECTION 2 already maps things; verify no clash.** `setup(opts)`, then the two `<leader>t*` maps.                                                                                                       |
| `trouble.lua`         | `folke/trouble.nvim`                         | `cmd`, `opts = {}`, `keys` (`<leader>xx`, `<leader>xw`, `<leader>xq`, `<leader>xl`)                                     | `setup {}`; four `<cmd>Trouble ...<CR>` maps.                                                                                                                                                                                                                                                                        |
| `undotree.lua`        | `jiaoshijie/undotree`                        | `dependencies = { plenary }`, `opts = {}`, `keys` (`<leader>u`)                                                         | `setup {}`; `<leader>u` → `require('undotree').toggle`. (Note: this is the `jiaoshijie/undotree` Lua one, not `mbbill/undotree`.)                                                                                                                                                                                    |
| `zen-mode.lua`        | `folke/zen-mode.nvim`                        | `cmd`, `opts = { window = { width = 0.85 } }`, `keys` (`<leader>zz`, `<C-0>`)                                           | `setup { window = { width = 0.85 } }`; two maps to `<cmd>ZenMode<CR>`.                                                                                                                                                                                                                                               |

`lua/custom/lsp_quickfix.lua` (437 lines) is plugin-manager-agnostic — no
changes. It is `require`d lazily from the `init.lua` LSP keymaps (task 3).

### 3. Re-apply our 12 `init.lua` deltas into the new sectioned structure

From `git diff 3338d39..HEAD -- init.lua` (hunk anchors are pre-migration line
numbers — locate by content in the new file):

1. **`<leader>td` toggle-diagnostics keymap** — after the `<leader>q` diagnostic
   keymap. → SECTION 2.
2. **`<C-h>/<C-l>/<C-j>` rebind** to `bprevious` / `bnext` / `<C-o>` (jumplist
   back), replacing the default window-nav `<C-hjkl>`. Keep the "Custom
   Bindings!" comment marker. → SECTION 2. **Check upstream didn't add its own
   `<C-hjkl>` elsewhere.**
3. **which-key group labels** `<leader>g` `[G]lance (peek)`, `<leader>x`
   `Trouble/diagnostics`, `<leader>z` `Zen mode` — into which-key's `spec` /
   groups config. → SECTION 4.
4. **`grX` + `grb` LSP quickfix maps** in the `LspAttach` `map(...)` block:
   `grX` → `require('custom.lsp_quickfix').apply_all()`, `grb` →
   `require('custom.lsp_quickfix').pick_buffer_quickfix()`. → SECTION 6.
5. **Glance maps** in the same `LspAttach` block: `<C-k>` →
   `telescope.builtin.lsp_definitions`; `<C-S-k>`, `<leader>gd`, `<leader>gr`,
   `<leader>gy`, `<leader>gm` →
   `require('glance').open('definitions' / 'references' / 'type_definitions' / 'implementations')`.
   → SECTION 6. **Note `<C-k>` conflict:** blink.cmp uses `<C-k>` for signature
   toggle in insert mode; ours is normal-mode LSP — fine, but double-check.
6. **Ruff hover-disable autocmd** — `LspAttach` autocmd, group
   `kickstart-disable-ruff-hover`: if `client.name == 'ruff'` set
   `client.server_capabilities.hoverProvider = false` (so Pyright owns hover). →
   SECTION 6.
7. **`servers` table** — remove the commented `clangd`/`pyright` stubs and add
   real entries:
   - `clangd = { cmd = { 'clangd', '--background-index', '--clang-tidy', '--completion-style=detailed', '--header-insertion=iwyu' } }`
   - `pyright = { settings = { pyright = { disableOrganizeImports = true }, python = { analysis = { ignore = { '*' } } } } }`
   - `ruff = { init_options = { settings = {} } }` → SECTION 6.
8. **Mason `ensure_installed`** — add `'prettierd'` and `'markdownlint'`
   alongside `'stylua'`. → SECTION 6 (mason-tool-installer) or SECTION 7,
   wherever upstream keeps it.
9. **conform `formatters_by_ft`** —
   `markdown = { 'prettierd', 'prettier', stop_after_first = true }`. →
   SECTION 7.
10. **conform `formatters` override** —
    `prettierd = { env = { PRETTIERD_DEFAULT_CONFIG = vim.fn.stdpath('config') .. '/.prettierrc.json' } }`
    (repo-bundled prettier config as fallback; see CHANGELOG 2026-08-18). →
    SECTION 7.
11. **Enable the kickstart example plugins** — upstream SECTION 10 has the
    `require 'kickstart.plugins.*'` lines commented out. Uncomment `debug`,
    `indent_line`, `lint`, `autopairs`, `neo-tree`, `gitsigns`, and
    `require 'custom.plugins'` (or whatever the new loader entrypoint is).
12. **Tab/indent options appended at EOF** — `expandtab = true`,
    `shiftwidth = 2`, `tabstop = 2`, `softtabstop = 2`. Move these into SECTION
    1 OPTIONS rather than trailing the file. **Cross-check against
    `guess-indent.nvim`** (upstream ships it) — it may override these per-buffer
    anyway; keep as the global default.

### 4. Re-apply the `lint.lua` markdownlint delta

Upstream's new `lint.lua` is top-level code (no returned spec). Re-add, right
after `lint.linters_by_ft` is set:

```lua
-- Always lint against the config bundled with this repo, regardless of the cwd
-- markdownlint is invoked from (it has no upward-search for `.markdownlint.jsonc`,
-- only the exact cwd). See ../../.markdownlint.jsonc.
lint.linters.markdownlint = vim.tbl_deep_extend('force', lint.linters.markdownlint, {
  args = { '--stdin', '--config', vim.fn.stdpath 'config' .. '/.markdownlint.jsonc' },
})
```

### 5. Toolchain prerequisites

- `nvim-treesitter@main` needs the **`tree-sitter` CLI ≥ 0.26.1 from a package
  manager (NOT npm)**. Already installed during scoping:
  `brew install tree-sitter tree-sitter-cli` → `tree-sitter 0.27.0`, only one on
  `$PATH`. Verify `which -a tree-sitter` stays clean (an npm-installed one
  earlier on `$PATH` would shadow it and fail cryptically).
- `markdownlint` + `prettierd` come from Mason via task 8. `markdownlint` is
  currently installed (Mason). `make` is needed for `telescope-fzf-native` and
  `LuaSnip` build hooks — already present on this machine.

### 6. Re-add `lazydev.nvim` (upstream dropped it)

`folke/lazydev.nvim` gives lua_ls the Neovim API library while editing this
config. Add it in SECTION 6 near lua_ls:
`vim.pack.add { gh 'folke/lazydev.nvim' }` +
`require('lazydev').setup { library = { { path = '${3rd}/luv/library', words = { 'vim%.uv' } } } }`.
Confirm blink.cmp still picks up the `lazydev` completion source (merge-base
config wired it into cmp sources).

### 7. Clean rebuild

1. `git checkout -- .` / land the new tree.
2. `rm -rf ~/.local/share/nvim/lazy ~/.local/share/nvim/site` (fresh vim.pack
   state).
3. `nvim --headless "+qa"` once to let `vim.pack.add` clone everything +
   `PackChanged` run builds; watch for notify errors.
4. `nvim --headless "+lua vim.cmd 'TSUpdate'" ...` (or let SECTION 9 install)
   and confirm parsers land in `~/.local/share/nvim/site/` (main's install dir).

---

## Risks / gotchas

- **`vim.pack` has no lazy-loading and no dependency graph.** Order of
  `vim.pack.add` + `setup()` calls is load-bearing. Symptoms of getting it
  wrong: `module 'x' not found` at startup, or a plugin silently not configured.
  Dependencies (plenary, treesitter) must be `add`ed before dependents'
  `setup()`.
- **Quieter failures than lazy.** lazy surfaces load errors in `:Lazy`; vim.pack
  mostly just... doesn't load the thing. Testing must be behavioural, not "it
  started".
- **Build hooks.** `telescope-fzf-native` (`make`) and `LuaSnip`
  (`make install_jsregexp`) run via the `PackChanged` autocmd — verify they
  actually fire and succeed on this machine on the fresh clone. If `fzf-native`
  doesn't build, telescope silently falls back to the Lua sorter.
- **`mini.icons` vs `nvim-web-devicons`.** After migration there is no
  `nvim-web-devicons` plugin; anything expecting it must go through
  `mini.icons.mock_nvim_web_devicons()`. Check Glance and render-markdown icon
  rendering specifically.
- **Keymap collisions** introduced by upstream's reorg: re-verify `<C-k>`,
  `<C-e>`, `<C-\>`, `<C-hjkl>`, `<C-1..4>` against both upstream SECTION 2 and
  blink.cmp's insert-mode maps.
- **`harpoon` branch** must be `harpoon2` — easy to lose in translation.
- **`guess-indent.nvim`** (upstream) may fight our explicit `shiftwidth=2`
  defaults. Decide which wins per-filetype.
- **Neovim version.** `main` supports "latest stable + latest nightly" only.
  We're on 0.12.3; Homebrew stable is 0.12.5 — bump Neovim as part of this so
  we're on a supported combo.

## Testing checklist

- [ ] `nvim` starts with no errors (`:messages` clean, `:checkhealth` sane).
- [ ] Open `README.md` — **no `range` crash**, render-markdown renders,
      `:lua print(vim.b.ts_highlight)` is truthy.
- [ ] Open a `.lua`, a `.sh`, a `.py`, a `.c` — treesitter highlight on,
      auto-install fires for any missing parser (this is where a hardcoded
      filetype list would show itself).
- [ ] `grX` / `grb` (LSP quickfix) work in a file with diagnostics.
- [ ] Glance: `<leader>gd` / `<leader>gr` / `<C-S-k>` open the peek window.
- [ ] Harpoon: `<leader>a` add, `<C-e>` menu, `<C-1>` jump.
- [ ] grug-far: `<C-S-f>` opens; do a real search/replace.
- [ ] Trouble: `<leader>xx` toggles diagnostics list.
- [ ] toggleterm: `<C-\>` float, `<leader>tv` vertical.
- [ ] zen-mode: `<leader>zz`.
- [ ] undotree: `<leader>u`.
- [ ] `<C-h>` / `<C-l>` cycle buffers; `<C-j>` jumps back.
- [ ] `<leader>td` toggles diagnostics.
- [ ] Format-on-save a Markdown file → prettier wraps to 80 cols; markdownlint
      shows no `MD013`.
- [ ] Python file: Pyright provides hover, Ruff provides diagnostics, no double
      hover.
- [ ] clangd starts on a `.c` file with the configured flags.
- [ ] which-key popup shows the `<leader>g` / `<leader>x` / `<leader>z` groups.
- [ ] `nvim +checkhealth` — treesitter, mason, telescope, blink all green.

## Rollback

The migration lands as its own commit(s) on a branch. To abandon:
`git checkout master && git branch -D <migration-branch>`, then
`rm -rf ~/.local/share/nvim/site && nvim --headless "+Lazy! restore" +qa` to
restore lazy.nvim state from `lazy-lock.json`.

## Follow-ups

- [x] `CHANGELOG.md` entry (2026-09-03).
- [x] `WORKFLOW.md` checked — the buffer/window/LSP-nav table already matched
      the re-applied keymaps; no change needed.
- [x] Shrink the `init.lua` footprint: local customizations moved into
      `lua/custom/plugins/local-{options,lsp,format,lint}.lua`; `lint.lua`
      restored to byte-identical-with-upstream. Remaining `init.lua` deltas
      (servers table, lazydev, blink source) are marked `-- LOCAL:`.
      Convention + sync workflow documented in `CLAUDE.md`.
- [x] `scripts/healthcheck.lua` added; `upstream` remote + `rerere` configured.
- [ ] Interactive checklist below (UI bits headless can't reach) — for the user
      to run before merging to `master`.
