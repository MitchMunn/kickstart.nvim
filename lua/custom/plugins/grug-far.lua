return {
  'MagicDuck/grug-far.nvim',
  cmd = 'GrugFar',
  keys = {
    {
      '<C-S-f>',
      function()
        require('grug-far').open()
      end,
      mode = { 'n', 'v' },
      desc = 'Search and Replace (grug-far)',
    },
    {
      '<leader>sR',
      function()
        require('grug-far').open()
      end,
      mode = { 'n', 'v' },
      desc = '[S]earch and [R]eplace (grug-far)',
    },
  },
  opts = {},
}
