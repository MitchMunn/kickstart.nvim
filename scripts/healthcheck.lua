-- Fast post-sync smoke test for this config.
--
-- Run:   nvim --headless -c 'luafile scripts/healthcheck.lua'
--   (`nvim -l` does NOT source init.lua, so the plugins wouldn't be loaded.)
--
-- Exits non-zero (and prints FAIL lines) if anything is wrong. Because it loads
-- the real init.lua, it catches vim.pack's quiet "plugin didn't load" failure
-- mode that `nvim --headless +qa` returning 0 does not.
--
-- It does NOT cover anything that needs a UI (Glance's float, the which-key
-- popup, render-markdown's visuals, toggleterm) -- see
-- docs/tickets/001-lazy-to-vim-pack-migration.md for the interactive checklist.

local fails = {}
local function check(ok, msg)
  if not ok then fails[#fails + 1] = msg end
end

-- Give async plugin/LSP setup a moment to settle.
vim.wait(3000, function() return false end)

-- 1. Core + custom plugin modules actually loaded.
for _, m in ipairs {
  'telescope',
  'gitsigns',
  'which-key',
  'conform',
  'blink.cmp',
  'fidget',
  'lazydev',
  'nvim-treesitter',
  'lint',
  'glance',
  'grug-far',
  'harpoon',
  'render-markdown',
  'toggleterm',
  'trouble',
  'undotree',
  'zen-mode',
} do
  check(package.loaded[m] ~= nil, 'module not loaded: ' .. m)
end

-- 2. Global keymaps we rely on.
for _, k in ipairs {
  '<leader>td',
  '<C-h>',
  '<C-l>',
  '<C-j>',
  '<C-S-f>',
  '<leader>sR',
  '<leader>m',
  '<leader>u',
  '<leader>xx',
  '<leader>tt',
  '<leader>zz',
  '<leader>a',
  '<C-e>',
  '\\',
} do
  local has = vim.fn.maparg(k, 'n') ~= '' or vim.fn.maparg(k, 'v') ~= ''
  check(has, 'missing normal/visual map: ' .. k)
end

-- 3. <C-k> must be free globally (local-lsp.lua binds it per-buffer on LspAttach).
check(vim.fn.maparg('<C-k>', 'n') == '', '<C-k> should be unmapped globally (was: ' .. vim.fn.maparg('<C-k>', 'n') .. ')')

-- 4. LSP servers configured.
for _, s in ipairs { 'clangd', 'pyright', 'ruff', 'lua_ls' } do
  check(vim.lsp.config[s] ~= nil, 'missing vim.lsp.config: ' .. s)
end

-- 5. conform: our formatter mappings + prettierd env override are in place.
local conform = require 'conform'
check(vim.deep_equal(conform.formatters_by_ft.lua, { 'stylua' }), 'conform lua formatter not set')
check(conform.formatters_by_ft.markdown ~= nil, 'conform markdown formatter not set')
check(
  conform.formatters and conform.formatters.prettierd and conform.formatters.prettierd.env and conform.formatters.prettierd.env.PRETTIERD_DEFAULT_CONFIG ~= nil,
  'prettierd PRETTIERD_DEFAULT_CONFIG override missing'
)

-- 6. blink.cmp lazydev source wired.
check(vim.tbl_contains(require('blink.cmp.config').sources.default, 'lazydev'), 'blink lazydev source not in defaults')

-- 7. nvim-treesitter is the `main` branch (has the modern API), parsers present.
check(type(require('nvim-treesitter').install) == 'function', 'nvim-treesitter looks like the old `master` branch (no .install)')
check(#require('nvim-treesitter').get_installed 'parsers' > 0, 'no treesitter parsers installed')

-- 8. markdown parses without the 0.12 `range` crash.
do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '# Title', '', '`code` and _em_ and [link](x).' })
  vim.bo[buf].filetype = 'markdown'
  local ok, err = pcall(function()
    local p = vim.treesitter.get_parser(buf, 'markdown')
    p:parse(true)
  end)
  check(ok, 'markdown treesitter parse failed: ' .. tostring(err))
end

if #fails == 0 then
  print 'healthcheck: PASS'
  os.exit(0)
else
  print('healthcheck: FAIL (' .. #fails .. ')')
  for _, f in ipairs(fails) do
    print('  - ' .. f)
  end
  os.exit(1)
end
