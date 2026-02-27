local base = require("metabuffer.buffer.base")
local ui = require("metabuffer.buffer.ui")
local M = {}
M["default-opts"] = {bufhidden = "hide", buftype = "nofile", buflisted = false}
M.new = function(nvim, model)
  local self = base.new(nvim, {model = model, name = "meta", ["default-opts"] = M["default-opts"]})
  self["syntax-type"] = "buffer"
  self.indexbuf = ui.new(nvim, self, "indexes")
  self.syntax = function()
    if ((self["syntax-type"] == "buffer") and (vim.bo[self.model].syntax ~= "")) then
      return vim.bo[self.model].syntax
    else
      return "metabuffer"
    end
  end
  self["apply-syntax"] = function(syntax_type)
    if syntax_type then
      self["syntax-type"] = syntax_type
    else
    end
    vim.bo[self.buffer]["syntax"] = self.syntax()
    return nil
  end
  self.update = function()
    return self.render()
  end
  self.render = function()
    local view = vim.fn.winsaveview()
    vim.bo[self.buffer]["modifiable"] = true
    local out = {}
    for _, idx in ipairs(self.indices) do
      table.insert(out, self.content[idx])
    end
    vim.api.nvim_buf_set_lines(self.buffer, 0, -1, false, out)
    vim.bo[self.buffer]["modifiable"] = false
    vim.fn.winrestview(view)
    return self.indexbuf.update()
  end
  self["push-visible-lines"] = function(visible)
    local n = math.min(#visible, #self.indices)
    for i = 1, n do
      local src = self.indices[i]
      local old = vim.api.nvim_buf_get_lines(self.model, (src - 1), src, false)
      local old_line = old[1]
      local new_line = visible[i]
      if (old_line ~= new_line) then
        vim.api.nvim_buf_set_lines(self.model, (src - 1), src, false, {new_line})
        self.content[src] = new_line
      else
      end
    end
    return nil
  end
  return self
end
return M
