local M = {}
M.new = function(prompt)
  local self = {prompt = prompt, index = 0, cached = prompt.text, backward = "", threshold = 0}
  self.current = function()
    if (self.index == 0) then
      return self.cached
    else
      return vim.fn.histget("input", (0 - self.index))
    end
  end
  self.previous = function()
    if (self.index == 0) then
      self.cached = self.prompt.text
      self.threshold = vim.fn.histnr("input")
    else
    end
    if (self.index < self.threshold) then
      self.index = (self.index + 1)
    else
    end
    return self.current()
  end
  self.next = function()
    if (self.index == 0) then
      self.cached = self.prompt.text
      self.threshold = vim.fn.histnr("input")
    else
    end
    if (self.index > 0) then
      self.index = (self.index - 1)
    else
    end
    return self.current()
  end
  self["previous-match"] = function()
    if (self.index == 0) then
      self.backward = self.prompt.caret["get-backward-text"]()
    else
    end
    local i = self.index
    local out = nil
    while not out do
      local c = self.previous()
      if ((self.index == i) or vim.startswith(c, self.backward)) then
        out = c
      else
        i = self.index
      end
    end
    return out
  end
  self["next-match"] = function()
    if (self.index == 0) then
      return self.cached
    else
      local i = self.index
      local out = nil
      while not out do
        local c = self.next()
        if ((self.index == i) or vim.startswith(c, self.backward)) then
          out = c
        else
          i = self.index
        end
      end
      return out
    end
  end
  return self
end
return M
