local handle = require("metabuffer.handle")
local util = require("metabuffer.util")
local M = {}
M["new-buffer"] = function()
  return vim.api.nvim_create_buf(false, false)
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
  local base = handle.new(nvim, target, model, {}, (opts["default-opts"] or {}))
  local self = base
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
  self["run-filter"] = function(matcher, query, ignorecase, run_clean)
    if run_clean then
      self["reset-filter"]()
    else
    end
    self.indices = matcher.filter(matcher, query, self.indices, self.content, ignorecase)
    if (#self.indices < 1000) then
      return matcher.highlight(matcher, query, ignorecase)
    else
      return matcher["remove-highlight"](matcher)
    end
  end
  self.update = function()
    local view = vim.fn.winsaveview()
    vim.bo[self.buffer]["modifiable"] = true
    local out = {}
    for _, idx in ipairs(self.indices) do
      table.insert(out, self.content[idx])
    end
    vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, out)
    vim.bo[self.buffer]["modifiable"] = false
    return vim.fn.winrestview(view)
  end
  self.activate = function(target_buf)
    return M["switch-buf"]((target_buf or self.buffer))
  end
  self["set-name"] = function(buf_name)
    local curr = vim.api.nvim_get_current_buf()
    if (curr ~= self.buffer) then
      self.activate(self.buffer)
    else
    end
    vim.cmd(("silent keepalt file! " .. buf_name))
    self.name = buf_name
    if (curr ~= self.buffer) then
      return self.activate(curr)
    else
      return nil
    end
  end
  return self
end
return M
