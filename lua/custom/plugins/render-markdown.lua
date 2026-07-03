return {
  'MeanderingProgrammer/render-markdown.nvim',
  ft = { 'markdown' },
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
  opts = {},
  keys = {
    {
      '<leader>m',
      function()
        require('render-markdown').toggle()
      end,
      desc = 'Toggle [M]arkdown render',
    },
  },
}
