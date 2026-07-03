return {
  'akinsho/toggleterm.nvim',
  opts = {
    open_mapping = [[<c-\>]],
    direction = 'float',
    shade_terminals = true,
  },
  keys = {
    {
      '<leader>tt',
      '<cmd>ToggleTerm<CR>',
      desc = '[T]oggle [T]erminal',
    },
    {
      '<leader>tv',
      '<cmd>ToggleTerm direction=vertical<CR>',
      desc = '[T]oggle [V]ertical terminal',
    },
  },
}
