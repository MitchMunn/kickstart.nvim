-- grug-far: project-wide search and replace, VSCode-style
-- https://github.com/MagicDuck/grug-far.nvim

vim.pack.add { 'https://github.com/MagicDuck/grug-far.nvim' }

require('grug-far').setup {}

vim.keymap.set({ 'n', 'v' }, '<C-S-f>', function() require('grug-far').open() end, { desc = 'Search and Replace (grug-far)' })
vim.keymap.set({ 'n', 'v' }, '<leader>sR', function() require('grug-far').open() end, { desc = '[S]earch and [R]eplace (grug-far)' })
