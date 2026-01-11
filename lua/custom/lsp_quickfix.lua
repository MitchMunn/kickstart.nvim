local M = {}

local function notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO, { title = 'LSP Quickfix' })
  end)
end

local function supports(client, method)
  if vim.fn.has 'nvim-0.11' == 1 then
    return client:supports_method(method)
  else
    -- 0.10 API
    return client.supports_method and client.supports_method(method)
  end
end

-- Apply a single resolved code action: apply edit then execute command if present
local function apply_resolved_action(client, action, done)
  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
  end
  if action.command then
    local cmd = action.command
    if type(cmd) == 'table' then
      local params = { command = cmd.command, arguments = cmd.arguments }
      client.request('workspace/executeCommand', params, function()
        if done then done() end
      end)
      return
    elseif type(cmd) == 'string' then
      -- Fallback if a simple string command is returned
      client.request('workspace/executeCommand', { command = cmd }, function()
        if done then done() end
      end)
      return
    end
  end
  if done then done() end
end

-- Resolve a code action if needed, then apply it
local function resolve_then_apply(client, action, done)
  if action.edit or type(action.command) == 'table' then
    return apply_resolved_action(client, action, done)
  end
  if supports(client, vim.lsp.protocol.Methods.codeAction_resolve) then
    client.request('codeAction/resolve', action, function(err, resolved)
      if err then
        return done and done()
      end
      apply_resolved_action(client, resolved or action, done)
    end)
  else
    apply_resolved_action(client, action, done)
  end
end

-- Determine if an action kind matches a prefix (e.g., 'quickfix' or 'source.fixAll')
local function kind_matches(action, prefix)
  local k = action.kind or ''
  return k == prefix or vim.startswith(k, prefix .. '.')
end

local function full_doc_range_params(bufnr, client)
  local last = vim.api.nvim_buf_line_count(bufnr)
  local last_idx = math.max(last - 1, 0)
  local line = vim.api.nvim_buf_get_lines(bufnr, last_idx, last_idx + 1, false)[1] or ''
  local last_col_bytes = #line
  local p = vim.lsp.util.make_given_range_params({ 0, 0 }, { last_idx, last_col_bytes }, bufnr, client.offset_encoding)
  p.textDocument = vim.lsp.util.make_text_document_params(bufnr)
  return p
end

local function range_for_diag(d, bufnr, client)
  -- Prefer original LSP range if available
  local lsp = d.user_data and (d.user_data.lsp or d.user_data) or nil
  if lsp and lsp.range and lsp.range.start and lsp.range["end"] then
    return lsp.range
  end
  if d.range and d.range.start and d.range["end"] then
    return d.range
  end
  -- Build from lnum/col using utility to convert to correct character units
  local sl = d.lnum or 0
  local sc = d.col or 0
  local el = (type(d.end_lnum) == 'number') and d.end_lnum or sl
  local ec = (type(d.end_col) == 'number') and d.end_col or (sc + 1)
  local params = vim.lsp.util.make_given_range_params({ sl, sc }, { el, ec }, bufnr, client.offset_encoding)
  return params.range
end

-- Apply a list of { client_id, action } sequentially
local function apply_seq(items, final_cb)
  local i, applied = 1, 0
  local function step()
    if i > #items then
      if final_cb then final_cb(applied) end
      return
    end
    local it = items[i]
    i = i + 1
    local client = vim.lsp.get_client_by_id(it.client_id)
    if not client then
      return step()
    end
    resolve_then_apply(client, it.action, function()
      applied = applied + 1
      step()
    end)
  end
  step()
end

-- Apply all source.fixAll actions, then all quickfix actions for remaining diagnostics
function M.apply_all()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients { bufnr = bufnr }
  if #clients == 0 then
    notify('No LSP clients attached to buffer', vim.log.levels.WARN)
    return
  end

  -- Phase 1: source.fixAll across the full document

  local function request_fix_all(cb)
    local pending = 0
    local collected = {}
    for _, client in ipairs(clients) do
      if supports(client, vim.lsp.protocol.Methods.textDocument_codeAction) then
        local p = full_doc_range_params(bufnr, client)
        p.context = { only = { 'source.fixAll' } }
        pending = pending + 1
        client.request('textDocument/codeAction', p, function(err, result, ctx)
          pending = pending - 1
          if not err and result then
            for _, act in ipairs(result) do
              if not act.disabled and kind_matches(act, 'source.fixAll') then
                table.insert(collected, { client_id = ctx.client_id, action = act })
              end
            end
          end
          if pending == 0 then cb(collected) end
        end, bufnr)
      end
    end
    vim.defer_fn(function()
      if pending == 0 then cb(collected) end
    end, 100)
  end

  local function request_quickfix_all(cb)
    local diags = vim.diagnostic.get(bufnr)
    if #diags == 0 then return cb({}) end
    -- Build small worklist of (client, diag) pairs
    local jobs = {}
    for _, client in ipairs(clients) do
      if supports(client, vim.lsp.protocol.Methods.textDocument_codeAction) then
        for _, d in ipairs(diags) do
          table.insert(jobs, { client = client, d = d })
        end
      end
    end
    if #jobs == 0 then return cb({}) end
    local function is_quickfixish(action)
      if action.kind and kind_matches(action, 'quickfix') then return true end
      if action.isPreferred then return true end
      return false
    end

    local function request_jobs(only_quickfix, done)
      local pending = #jobs
      local out = {}
      if pending == 0 then return done(out) end
      for _, job in ipairs(jobs) do
        local client = job.client
        local d = job.d
        local rng = range_for_diag(d, bufnr, client)
        local lspdiag = (d.user_data and (d.user_data.lsp or d.user_data))
        local diaglist
        if lspdiag and lspdiag.range then
          diaglist = { lspdiag }
        else
          diaglist = { { range = rng, message = d.message or '' } }
        end
        local r = {
          range = rng,
          textDocument = vim.lsp.util.make_text_document_params(bufnr),
          context = only_quickfix and { diagnostics = diaglist, only = { 'quickfix' } }
            or { diagnostics = diaglist },
        }
        client.request('textDocument/codeAction', r, function(err, result, ctx)
          pending = pending - 1
          if not err and result then
            for _, act in ipairs(result) do
              if not act.disabled and (only_quickfix and true or is_quickfixish(act)) then
                table.insert(out, { client_id = ctx.client_id, action = act })
              end
            end
          end
          if pending == 0 then done(out) end
        end, bufnr)
      end
    end

    -- First try strict quickfix-only; fall back to best-effort quickfix-ish
    request_jobs(true, function(out)
      if #out > 0 then return cb(out) end
      request_jobs(false, cb)
    end)
  end

  request_fix_all(function(fixalls)
    if #fixalls > 0 then
      -- Dedup by client/title
      local seen, items = {}, {}
      for _, it in ipairs(fixalls) do
        local key = tostring(it.client_id) .. '|' .. (it.action.title or '')
        if not seen[key] then seen[key] = true table.insert(items, it) end
      end
      -- sort preferred first just in case
      table.sort(items, function(a, b)
        local ap, bp = (a.action.isPreferred and 1 or 0), (b.action.isPreferred and 1 or 0)
        if ap ~= bp then return ap > bp end
        return (a.action.title or '') < (b.action.title or '')
      end)
      apply_seq(items, function(n)
        -- After applying fixAll, fetch fresh diagnostics then quickfix
        vim.defer_fn(function()
          request_quickfix_all(function(qfs)
            if #qfs == 0 then
              notify(('Applied %d fixAll action(s); no quickfixes left.'):format(n))
              return
            end
            -- Prefer isPreferred quickfixes first; apply all (no dedup to avoid losing per-diagnostic fixes)
            table.sort(qfs, function(a, b)
              local ap, bp = (a.action.isPreferred and 1 or 0), (b.action.isPreferred and 1 or 0)
              if ap ~= bp then return ap > bp end
              return (a.action.title or '') < (b.action.title or '')
            end)
            apply_seq(qfs, function(m)
              notify(('Applied %d fixAll + %d quickfix action(s)'):format(n, m))
            end)
          end)
        end, 100)
      end)
    else
      -- No fixAll; go straight to quickfixes
      request_quickfix_all(function(qfs)
        if #qfs == 0 then
          notify('No quickfix actions found', vim.log.levels.INFO)
          return
        end
        table.sort(qfs, function(a, b)
          local ap, bp = (a.action.isPreferred and 1 or 0), (b.action.isPreferred and 1 or 0)
          if ap ~= bp then return ap > bp end
          return (a.action.title or '') < (b.action.title or '')
        end)
        apply_seq(qfs, function(m)
          notify(('Applied %d quickfix action(s)'):format(m))
        end)
      end)
    end
  end)
end

-- Show a picker of all quickfix actions across the buffer
function M.pick_buffer_quickfix()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients { bufnr = bufnr }
  if #clients == 0 then
    notify('No LSP clients attached to buffer', vim.log.levels.WARN)
    return
  end

  -- Collect quickfix actions similarly to apply_all(), but don't execute
  local diags = vim.diagnostic.get(bufnr)
  if #diags == 0 then
    notify('No diagnostics in buffer', vim.log.levels.INFO)
    return
  end

  local jobs = {}
  for _, client in ipairs(clients) do
    if supports(client, vim.lsp.protocol.Methods.textDocument_codeAction) then
      for _, d in ipairs(diags) do
        table.insert(jobs, { client = client, d = d })
      end
    end
  end
  if #jobs == 0 then
    notify('No clients support code actions', vim.log.levels.WARN)
    return
  end

  local function request_jobs(only_quickfix, done)
    local pending = #jobs
    local out = {}
    if pending == 0 then return done(out) end
    for _, job in ipairs(jobs) do
      local client = job.client
      local d = job.d
      local rng = range_for_diag(d, bufnr, client)
      local lspdiag = (d.user_data and (d.user_data.lsp or d.user_data))
      local diaglist
      if lspdiag and lspdiag.range then
        diaglist = { lspdiag }
      else
        diaglist = { { range = rng, message = d.message or '' } }
      end
      local r = {
        range = rng,
        textDocument = vim.lsp.util.make_text_document_params(bufnr),
        context = only_quickfix and { diagnostics = diaglist, only = { 'quickfix' } } or { diagnostics = diaglist },
      }
      client.request('textDocument/codeAction', r, function(err, result, ctx)
        pending = pending - 1
        if not err and result then
          for _, act in ipairs(result) do
            if not act.disabled then
              table.insert(out, { client_id = ctx.client_id, client_name = client.name, action = act, range = rng })
            end
          end
        end
        if pending == 0 then done(out) end
      end, bufnr)
    end
  end

  local function present(items)
    if #items == 0 then
      notify('No quickfix actions found', vim.log.levels.INFO)
      return
    end
    -- Build display strings
    local entries = {}
    for _, it in ipairs(items) do
      local start = it.range and it.range.start or { line = 0, character = 0 }
      local display = string.format('[%s] %s  @%d:%d', it.client_name or 'lsp', it.action.title or '(untitled)', start.line + 1, start.character + 1)
      table.insert(entries, { display = display, data = it })
    end

    local function do_apply(choice)
      if not choice then return end
      local it = choice.data
      local client = vim.lsp.get_client_by_id(it.client_id)
      if not client then return end
      resolve_then_apply(client, it.action)
    end

    local ok, telescope = pcall(require, 'telescope')
    if ok and telescope and telescope.pickers and telescope.finders and telescope.config then
      local pickers = require 'telescope.pickers'
      local finders = require 'telescope.finders'
      local conf = require('telescope.config').values
      local actions = require 'telescope.actions'
      local action_state = require 'telescope.actions.state'

      pickers
        .new({}, {
          prompt_title = 'Buffer Quickfixes',
          finder = finders.new_table {
            results = entries,
            entry_maker = function(e)
              return {
                value = e,
                display = e.display,
                ordinal = e.display,
              }
            end,
          },
          sorter = conf.generic_sorter({}),
          attach_mappings = function(prompt_bufnr, map)
            local apply_selected = function()
              local picker = action_state.get_current_picker(prompt_bufnr)
              local multi = picker:get_multi_selection()
              local to_apply = {}
              if type(multi) == 'table' then
                for _, sel in ipairs(multi) do
                  local val = (type(sel) == 'table' and sel.value) or sel
                  if val and val.data then
                    table.insert(to_apply, val.data)
                  end
                end
              end
              if #to_apply == 0 then
                local sel = action_state.get_selected_entry()
                if sel and sel.value and sel.value.data then
                  table.insert(to_apply, sel.value.data)
                end
              end

              actions.close(prompt_bufnr)
              if #to_apply == 0 then return end
              apply_seq(to_apply, function(_) end)
            end
            actions.select_default:replace(apply_selected)
            -- Ensure Tab multi-select mappings exist
            map('i', '<Tab>', function()
              actions.toggle_selection(prompt_bufnr)
              actions.move_selection_next(prompt_bufnr)
            end)
            map('n', '<Tab>', function()
              actions.toggle_selection(prompt_bufnr)
              actions.move_selection_next(prompt_bufnr)
            end)
            map('i', '<S-Tab>', function()
              actions.toggle_selection(prompt_bufnr)
              actions.move_selection_previous(prompt_bufnr)
            end)
            map('n', '<S-Tab>', function()
              actions.toggle_selection(prompt_bufnr)
              actions.move_selection_previous(prompt_bufnr)
            end)
            return true
          end,
        })
        :find()
    else
      -- Fallback to vim.ui.select (uses telescope-ui-select in this config)
      vim.ui.select(entries, {
        prompt = 'Buffer Quickfixes',
        format_item = function(item)
          return item.display
        end,
      }, do_apply)
    end
  end

  -- First strict quickfix-only, then fallback best-effort
  request_jobs(true, function(results)
    if #results > 0 then return present(results) end
    request_jobs(false, present)
  end)
end

return M
