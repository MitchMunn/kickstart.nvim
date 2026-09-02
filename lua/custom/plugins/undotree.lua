-- undotree: visualise and walk the undo history
-- https://github.com/jiaoshijie/undotree

vim.pack.add {
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/jiaoshijie/undotree',
}

require('undotree').setup {}

vim.keymap.set('n', '<leader>u', function() require('undotree').toggle() end, { desc = 'Toggle UndoTree' })
