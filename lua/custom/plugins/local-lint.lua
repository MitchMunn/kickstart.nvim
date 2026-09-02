-- Local nvim-lint tweaks, applied after kickstart's lint config
-- (`require 'kickstart.plugins.lint'` runs earlier in init.lua SECTION 10).

local lint = require 'lint'

-- Always lint against the config bundled with this repo, regardless of the cwd
-- markdownlint is invoked from (it has no upward-search for `.markdownlint.jsonc`,
-- only the exact cwd). See ../../../.markdownlint.jsonc.
lint.linters.markdownlint = vim.tbl_deep_extend('force', lint.linters.markdownlint, {
  args = { '--stdin', '--config', vim.fn.stdpath 'config' .. '/.markdownlint.jsonc' },
})
