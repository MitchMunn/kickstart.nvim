-- Local conform.nvim tweaks, applied after kickstart's conform.setup (SECTION 7).
-- conform reads these module tables live at format time, so poking them here works.

local conform = require 'conform'

conform.formatters_by_ft.lua = { 'stylua' }
conform.formatters_by_ft.markdown = { 'prettierd', 'prettier', stop_after_first = true }

-- Hard-wrap Markdown prose to printWidth so it satisfies markdownlint's MD013
-- line-length rule (see local-lint.lua). PRETTIERD_DEFAULT_CONFIG only applies
-- as a fallback when the file's own project has no .prettierrc; a project-local
-- config always wins. See CHANGELOG 2026-08-18.
conform.formatters = conform.formatters or {}
conform.formatters.prettierd = vim.tbl_deep_extend('force', conform.formatters.prettierd or {}, {
  env = {
    PRETTIERD_DEFAULT_CONFIG = vim.fn.stdpath 'config' .. '/.prettierrc.json',
  },
})

-- Format on save for every filetype *except* those without a well standardized
-- style, where LSP formatting tends to do more harm than good. (Kickstart's own
-- `format_on_save` is opt-in with an empty list; this restores our opt-out
-- behaviour without editing init.lua.)
vim.api.nvim_create_autocmd('BufWritePre', {
  group = vim.api.nvim_create_augroup('local-format-on-save', { clear = true }),
  callback = function(args)
    local disable_filetypes = { c = true, cpp = true }
    if disable_filetypes[vim.bo[args.buf].filetype] then return end
    conform.format { bufnr = args.buf, timeout_ms = 500, lsp_format = 'fallback' }
  end,
  desc = 'Format buffer on save (conform, LSP fallback)',
})
