-- Glance: peek definitions / references / implementations in a floating window
-- https://github.com/DNLHC/glance.nvim
--
-- Keymaps live in the LspAttach handler in init.lua (SECTION 6), since they
-- only make sense once a language server is attached.

vim.pack.add { 'https://github.com/DNLHC/glance.nvim' }

require('glance').setup {
  detached = true,
}
