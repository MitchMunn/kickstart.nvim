return {
  'folke/zen-mode.nvim',
  cmd = 'ZenMode',
  keys = {
    { '<leader>zz', '<cmd>ZenMode<CR>', desc = 'Toggle [Z]en Mode' },
    { '<C-0>', '<cmd>ZenMode<CR>', desc = 'Toggle Zen Mode (best-effort)' },
  },
  opts = {
    window = {
      width = 0.85,
    },
  },
}
