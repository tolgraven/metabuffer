-- [nfnl] fnl/metabuffer/buffer/ui.fnl
local base = require("metabuffer.buffer.base")
local M = {}
local function role_buffer_name(role)
  local txt = (role or "Ui")
  local first = string.sub(txt, 1, 1)
  local rest = string.sub(txt, 2)
  return ("[Metabuffer " .. string.upper(first) .. rest .. "]")
end
M.new = function(nvim, parent, role)
  local self = base.new(nvim, {model = parent.buffer, name = (role or "ui"), ["default-opts"] = {bufhidden = "hide", buftype = "nofile", buflisted = false, swapfile = false}})
  self.parent = parent
  self["set-name"](role_buffer_name(role))
  self.update = function()
    local out = {}
    for _, src in ipairs(self.parent.indices) do
      table.insert(out, string.format("%d\t%s", src, self.parent.name))
    end
    do
      local bo = vim.bo[self.buffer]
      bo["modifiable"] = true
    end
    vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, out)
    local bo = vim.bo[self.buffer]
    bo["modifiable"] = false
    return nil
  end
  return self
end
return M
