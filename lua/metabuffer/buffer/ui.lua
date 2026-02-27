local base = require("metabuffer.buffer.base")
local M = {}
M.new = function(nvim, parent, role)
  local self = base.new(nvim, {model = parent.buffer, name = (role or "ui"), ["default-opts"] = {bufhidden = "hide", buftype = "nofile", buflisted = false}})
  self.parent = parent
  self.update = function()
    local out = {}
    for _, src in ipairs(self.parent.indices) do
      table.insert(out, string.format("%d\t%s", src, self.parent.name))
    end
    vim.bo[self.buffer]["modifiable"] = true
    vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, out)
    vim.bo[self.buffer]["modifiable"] = false
    return nil
  end
  return self
end
return M
