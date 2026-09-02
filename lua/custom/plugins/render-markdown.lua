-- render-markdown: render Markdown (headings, code blocks, tables, ...) in the
-- buffer as you edit.
-- https://github.com/MeanderingProgrammer/render-markdown.nvim
--
-- Needs the `markdown` / `markdown_inline` treesitter parsers, which SECTION 9
-- of init.lua installs before this file is loaded.

vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

require('render-markdown').setup {}

-- <leader>mr = in-buffer render toggle; <leader>mp = full browser preview
-- (lua/custom/plugins/markdown-preview.lua).
vim.keymap.set('n', '<leader>mr', function() require('render-markdown').toggle() end, { desc = '[M]arkdown in-buffer [r]ender toggle' })
