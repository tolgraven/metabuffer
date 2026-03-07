-- [nfnl] fnl/metabuffer/prompt/caret.fnl
local M = {}
M.new = function(prompt, locus)
  local self = {prompt = prompt, _locus = (locus or 0)}
  self.head = function()
    return 0
  end
  self.tail = function()
    return #self.prompt.text
  end
  self["get-locus"] = function()
    return self._locus
  end
  self["set-locus"] = function(value)
    if (value < self.head()) then
      self._locus = self.head()
      return nil
    else
      if (value > self.tail()) then
        self._locus = self.tail()
        return nil
      else
        self._locus = value
        return nil
      end
    end
  end
  self["get-backward-text"] = function()
    if (self["get-locus"]() == 0) then
      return ""
    else
      return string.sub(self.prompt.text, 1, self["get-locus"]())
    end
  end
  self["get-selected-text"] = function()
    if (self["get-locus"]() >= self.tail()) then
      return ""
    else
      return string.sub(self.prompt.text, (self["get-locus"]() + 1), (self["get-locus"]() + 1))
    end
  end
  self["get-forward-text"] = function()
    if (self["get-locus"]() >= (self.tail() - 1)) then
      return ""
    else
      return string.sub(self.prompt.text, (self["get-locus"]() + 2))
    end
  end
  return self
end
return M
