-- Harpoon: pin a handful of files and jump between them instantly
-- https://github.com/ThePrimeagen/harpoon (harpoon2 branch)

vim.pack.add {
  'https://github.com/nvim-lua/plenary.nvim',
  { src = 'https://github.com/ThePrimeagen/harpoon', version = 'harpoon2' },
}

local harpoon = require 'harpoon'
harpoon:setup()

vim.keymap.set('n', '<leader>a', function()
  harpoon:list():add()
end, { desc = '[A]dd file to Harpoon' })

vim.keymap.set('n', '<C-e>', function()
  harpoon.ui:toggle_quick_menu(harpoon:list())
end, { desc = 'Toggle Harpoon quick menu' })

for i = 1, 4 do
  vim.keymap.set('n', '<C-' .. i .. '>', function()
    harpoon:list():select(i)
  end, { desc = 'Harpoon to file ' .. i })
  vim.keymap.set('n', '<leader>' .. i, function()
    harpoon:list():select(i)
  end, { desc = 'Harpoon to file ' .. i })
end
