-- zen-mode: distraction-free single-window editing
-- https://github.com/folke/zen-mode.nvim

vim.pack.add { 'https://github.com/folke/zen-mode.nvim' }

require('zen-mode').setup {
  window = {
    width = 0.85,
  },
}

vim.keymap.set('n', '<leader>zz', '<cmd>ZenMode<CR>', { desc = 'Toggle [Z]en Mode' })
vim.keymap.set('n', '<C-0>', '<cmd>ZenMode<CR>', { desc = 'Toggle Zen Mode (best-effort)' })
