-- render-markdown: render Markdown (headings, code blocks, tables, ...) in the
-- buffer as you edit.
-- https://github.com/MeanderingProgrammer/render-markdown.nvim
--
-- Needs the `markdown` / `markdown_inline` treesitter parsers, which SECTION 9
-- of init.lua installs before this file is loaded.

vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

require('render-markdown').setup {}

vim.keymap.set('n', '<leader>m', function()
  require('render-markdown').toggle()
end, { desc = 'Toggle [M]arkdown render' })
