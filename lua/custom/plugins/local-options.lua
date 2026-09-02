-- Local editor options and keymaps that don't belong to any one plugin.
-- Kept here (rather than in init.lua) so upstream kickstart syncs stay clean.

-- Indentation defaults: 2-space, spaces-not-tabs. `guess-indent.nvim` still
-- adjusts these per-buffer when a file's own style differs.
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.tabstop = 2
vim.o.softtabstop = 2

-- Toggle all diagnostics (LSP + nvim-lint) on/off.
vim.keymap.set('n', '<leader>td', function() vim.diagnostic.enable(not vim.diagnostic.is_enabled()) end, { desc = '[T]oggle [D]iagnostics' })

-- Buffer navigation and jumplist, VSCode-style, over the top of kickstart's
-- <C-hjkl> window-nav maps (SECTION 2). `<C-w> hjkl` still moves between
-- windows natively; Zellij's Alt+hjkl handles panes for this setup.
vim.keymap.set('n', '<C-h>', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<C-l>', '<cmd>bnext<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<C-j>', '<C-o>', { desc = 'Jump back (previous location)' })
-- Free <C-k> globally so the LSP-attach "go to definition" map (local-lsp.lua)
-- owns it in code buffers and it does nothing elsewhere.
pcall(vim.keymap.del, 'n', '<C-k>')

-- which-key group labels for our custom <leader> prefixes.
require('which-key').add {
  { '<leader>g', group = '[G]lance (peek)' },
  { '<leader>m', group = '[M]arkdown' },
  { '<leader>x', group = 'Trouble/diagnostics' },
  { '<leader>z', group = 'Zen mode' },
}
