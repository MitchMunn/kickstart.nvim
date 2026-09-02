-- Local LSP-attach keymaps and per-server tweaks.
-- The language servers themselves (clangd/pyright/ruff) are declared in the
-- `servers` table in init.lua SECTION 6, since that table feeds both
-- mason-tool-installer and the vim.lsp.config/enable loop.

-- Extra buffer-local maps whenever any language server attaches.
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('local-lsp-attach', { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc, mode) vim.keymap.set(mode or 'n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc }) end

    -- Apply all available quick fixes (source.fixAll, then quickfix for all diagnostics).
    map('grX', function() require('custom.lsp_quickfix').apply_all() end, 'Apply All Quickfi[x]es')

    -- Buffer-wide quickfix picker.
    map('grb', function() require('custom.lsp_quickfix').pick_buffer_quickfix() end, 'Buffer Quickfix Picker')

    -- VSCode-style straight-to-definition jump (see the <C-hjkl> note in local-options.lua).
    map('<C-k>', require('telescope.builtin').lsp_definitions, 'Go to Definition')

    -- Glance: peek in a floating window without leaving the current buffer.
    map('<C-S-k>', function() require('glance').open 'definitions' end, 'Peek Definition (Glance)')
    map('<leader>gd', function() require('glance').open 'definitions' end, '[G]lance [D]efinitions')
    map('<leader>gr', function() require('glance').open 'references' end, '[G]lance [R]eferences')
    map('<leader>gy', function() require('glance').open 'type_definitions' end, '[G]lance t[Y]pe definitions')
    map('<leader>gm', function() require('glance').open 'implementations' end, '[G]lance i[M]plementations')
  end,
})

-- Let Pyright own hover for Python; Ruff only provides lint diagnostics + code actions.
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('local-disable-ruff-hover', { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == 'ruff' then client.server_capabilities.hoverProvider = false end
  end,
  desc = 'LSP: Disable hover capability from Ruff',
})
