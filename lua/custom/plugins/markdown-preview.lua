-- markdown-preview.nvim: full GitHub-style render in a live browser tab
-- (mermaid, KaTeX, images, scroll-synced). Complements the in-buffer
-- render-markdown.nvim; toggle with <leader>mp from any Markdown buffer.
-- https://github.com/iamcco/markdown-preview.nvim

-- Fetch the prebuilt preview-server binary after install/update (downloads from
-- the plugin's GitHub releases into app/bin/; no Node toolchain needed).
-- Mirrors kickstart's PackChanged build-hook pattern in init.lua SECTION 3.
-- Manual fallback if this ever doesn't run: `:call mkdp#util#install()`.
--
-- Must be registered *before* vim.pack.add() below: PackChanged fires
-- synchronously during add() on a fresh install, so an autocmd created after
-- the call misses that first "install" event entirely (see `:help
-- vim.pack-events`) and app/bin/ is left empty on a brand-new machine.
vim.api.nvim_create_autocmd('PackChanged', {
  group = vim.api.nvim_create_augroup('local-mkdp-build', { clear = true }),
  callback = function(ev)
    if ev.data.spec.name ~= 'markdown-preview.nvim' then return end
    if ev.data.kind ~= 'install' and ev.data.kind ~= 'update' then return end
    local res = vim.system({ './install.sh' }, { cwd = ev.data.path .. '/app' }):wait()
    if res.code ~= 0 then vim.notify('markdown-preview build failed:\n' .. (res.stderr or res.stdout or ''), vim.log.levels.ERROR) end
  end,
})

vim.pack.add { 'https://github.com/iamcco/markdown-preview.nvim' }

-- Keep the preview tab open when you move away from the Markdown buffer; the
-- toggle keymap is the only thing that opens/closes it.
vim.g.mkdp_auto_close = 0

-- markdown-preview only defines its `:MarkdownPreview*` commands buffer-locally
-- in Markdown buffers, so scope the keymap the same way.
local function set_keymap(buf) vim.keymap.set('n', '<leader>mp', '<cmd>MarkdownPreviewToggle<CR>', { buffer = buf, desc = '[M]arkdown [P]review (browser)' }) end
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('local-mkdp-keymap', { clear = true }),
  pattern = 'markdown',
  callback = function(ev) set_keymap(ev.buf) end,
})
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[buf].filetype == 'markdown' then set_keymap(buf) end
end
