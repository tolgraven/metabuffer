-- [nfnl] fnl/metabuffer/buffer/base.fnl
local handle = require("metabuffer.handle")
local util = require("metabuffer.util")
local events = require("metabuffer.events")
local M = {}
M["new-buffer"] = function()
  local buf = vim.api.nvim_create_buf(false, false)
  events.send("on-buf-create!", {buf = buf, role = "meta"})
  return buf
end
M["switch-buf"] = function(buf)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    vim.cmd(("noautocmd keepjumps buffer " .. buf))
  else
  end
  return vim.api.nvim_get_current_buf()
end
M.new = function(nvim, opts)
  local model = (opts.model or vim.api.nvim_get_current_buf())
  local target = (opts.buffer or M["new-buffer"]())
  local self = handle.new(nvim, target, model, {}, (opts["default-opts"] or {}))
  self.buffer = target
  self.model = model
  self.name = (opts.name or "buffer")
  self.content = util["buf-lines"](model)
  self.indices = {}
  for i = 1, #self.content do
    table.insert(self.indices, i)
  end
  self["all-indices"] = util.deepcopy(self.indices)
  self["line-count"] = function()
    return #self.content
  end
  self["source-line-nr"] = function(index)
    local line = self.indices[index]
    return (line and (line + 0))
  end
  self["closest-index"] = function(line_nr)
    local candidate = nil
    local dist = math.huge
    for i, v in ipairs(self.indices) do
      local d = math.abs((v - line_nr))
      if (d < dist) then
        dist = d
        candidate = i
      else
      end
    end
    return (candidate or 1)
  end
  self["reset-filter"] = function()
    self.indices = util.deepcopy(self["all-indices"])
    return nil
  end
  self["run-filter"] = function(matcher, query, ignorecase, run_clean, target_win)
    if run_clean then
      self["reset-filter"]()
    else
    end
    self.indices = matcher.filter(matcher, query, self.indices, self.content, ignorecase)
    if (#self.indices < 1000) then
      return matcher.highlight(matcher, query, ignorecase, target_win)
    else
      return matcher["remove-highlight"](matcher)
    end
  end
  self.update = function()
    local view = vim.fn.winsaveview()
    local out = {}
    do
      local bo = vim.bo[self.buffer]
      bo["modifiable"] = true
    end
    for _, idx in ipairs(self.indices) do
      table.insert(out, self.content[idx])
    end
    vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, out)
    do
      local bo = vim.bo[self.buffer]
      bo["modifiable"] = false
    end
    return vim.fn.winrestview(view)
  end
  self.activate = function(target_buf)
    return M["switch-buf"]((target_buf or self.buffer))
  end
  self["unique-name"] = function(base_name)
    local base = (base_name or "buffer")
    local n = 1
    local candidate = base
    while ((vim.fn.bufnr(candidate) > 0) and (vim.fn.bufnr(candidate) ~= self.buffer)) do
      n = (n + 1)
      candidate = (base .. " [" .. n .. "]")
    end
    return candidate
  end
  self["set-name"] = function(buf_name)
    local target_name = self["unique-name"](buf_name)
    local ok = pcall(vim.api.nvim_buf_set_name, self.buffer, target_name)
    if ok then
      self.name = target_name
      return nil
    else
      self.name = ((buf_name or "buffer") .. " [" .. self.buffer .. "]")
      return nil
    end
  end
  return self
end
return M
