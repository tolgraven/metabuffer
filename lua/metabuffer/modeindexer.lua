local M = {}
M.new = function(candidates, index, opts)
  local self = {candidates = candidates, index = (index or 1), ["on-leave"] = (opts and opts["on-leave"]), ["on-active"] = (opts and opts["on-active"])}
  self.current = function()
    return self.candidates[self.index]
  end
  self._call = function(f)
    if f then
      if (type(f) == "string") then
        local obj = self.current()
        local m = obj[f]
        if m then
          return m(obj)
        else
          return nil
        end
      else
        return f(self)
      end
    else
      return nil
    end
  end
  self["set-index"] = function(value)
    if (value ~= self.index) then
      self._call(self["on-leave"])
      self.index = (((value - 1) % #self.candidates) + 1)
      return self._call(self["on-active"])
    else
      return nil
    end
  end
  self.next = function(offset)
    self["set-index"]((self.index + (offset or 1)))
    return self.current()
  end
  self.previous = function(offset)
    self["set-index"]((self.index - (offset or 1)))
    return self.current()
  end
  return self
end
return M
