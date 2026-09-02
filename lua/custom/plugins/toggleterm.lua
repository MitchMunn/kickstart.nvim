-- toggleterm: floating / split terminals on a keystroke
-- https://github.com/akinsho/toggleterm.nvim

vim.pack.add { 'https://github.com/akinsho/toggleterm.nvim' }

require('toggleterm').setup {
  open_mapping = [[<c-\>]],
  direction = 'float',
  shade_terminals = true,
}

vim.keymap.set('n', '<leader>tt', '<cmd>ToggleTerm<CR>', { desc = '[T]oggle [T]erminal' })
vim.keymap.set('n', '<leader>tv', '<cmd>ToggleTerm direction=vertical<CR>', { desc = '[T]oggle [V]ertical terminal' })
