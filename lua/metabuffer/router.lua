local prompt_mod = require("metabuffer.prompt.prompt")
local meta_mod = require("metabuffer.meta")
local base_buffer = require("metabuffer.buffer.base")
local state = require("metabuffer.core.state")
local M = {}
M.instances = {}
local function setup_state(query, mode)
  if ((mode == "resume") and vim.b._meta_context) then
    local ctx = vim.deepcopy(vim.b._meta_context)
    if (query and (query ~= "")) then
      ctx["text"] = query
      ctx["caret-locus"] = #query
    else
    end
    return ctx
  else
    return state["default-condition"]((query or ""))
  end
end
M._store_vars = function(meta)
  vim.b._meta_context = meta.store()
  vim.b._meta_indexes = meta.buf.indices
  vim.b._meta_updates = meta.updates
  vim.b._meta_source_bufnr = meta.buf.model
  return meta
end
M._wrapup = function(meta)
  vim.cmd("redraw|redrawstatus")
  return M._store_vars(meta)
end
M.start = function(query, mode, meta)
  local condition = setup_state(query, mode)
  local curr = (meta or meta_mod.new(vim, condition))
  local _ = curr.on_init()
  local _0 = curr.on_update(prompt_mod.STATUS_PROGRESS)
  local _1 = curr.on_redraw()
  local status = prompt_mod.STATUS_PAUSE
  if ((status == prompt_mod.STATUS_ACCEPT) or (status == prompt_mod.STATUS_CANCEL)) then
    pcall(vim.cmd, ("sign unplace * buffer=" .. vim.api.nvim_get_current_buf()))
    base_buffer["switch-buf"](curr.buf.model)
  else
  end
  if (status == prompt_mod.STATUS_ACCEPT) then
    curr.win["set-row"](curr.selected_line(), true)
    vim.cmd("normal! zv")
    local vq = curr.vim_query()
    if (vq ~= "") then
      vim.fn.setreg("/", vq)
    else
    end
  else
  end
  if (status == prompt_mod.STATUS_PAUSE) then
    base_buffer["switch-buf"](curr.buf.model)
  else
  end
  M._wrapup(curr)
  return curr
end
M.sync = function(meta, query)
  if not meta then
    vim.notify("No Meta instance", vim.log.levels.WARN)
    return nil
  else
    meta.text = (query or "")
    meta.on_update(prompt_mod.STATUS_PROGRESS)
    M._store_vars(meta)
    return meta
  end
end
M.push = function(meta)
  if not meta then
    return vim.notify("No Meta instance", vim.log.levels.WARN)
  else
    local lines = vim.api.nvim_buf_get_lines(meta.buf.buffer, 0, -1, false)
    return meta.buf["push-visible-lines"](lines)
  end
end
M.entry_start = function(query, bang)
  local key = vim.api.nvim_get_current_buf()
  if (bang or not M.instances[key]) then
    M.instances[key] = meta_mod.new(vim, state["default-condition"](""))
  else
  end
  M.instances[key] = M.start(query, "start", M.instances[key])
  return nil
end
M.entry_resume = function(query)
  local key = vim.api.nvim_get_current_buf()
  M.instances[key] = M.start(query, "resume", M.instances[key])
  return nil
end
M.entry_sync = function(query)
  local key = vim.api.nvim_get_current_buf()
  M.instances[key] = M.sync(M.instances[key], query)
  return nil
end
M.entry_push = function()
  local key = vim.api.nvim_get_current_buf()
  return M.push(M.instances[key])
end
M.entry_cursor_word = function(resume)
  local w = vim.fn.expand("<cword>")
  if resume then
    return M.entry_resume(w)
  else
    return M.entry_start(w, false)
  end
end
return M
