-- [nfnl] fnl/metabuffer/window/lineno.fnl
local M = {}
M["digit-width-from-max-value"] = function(max_value)
  return math.max(3, #tostring(math.max(1, (max_value or 1))))
end
M["digit-width-from-max-len"] = function(max_len)
  return math.max(3, (max_len or 1))
end
M["field-width-from-max-value"] = function(max_value)
  return (M["digit-width-from-max-value"](max_value) + 1)
end
M["lnum-cell"] = function(lnum, digit_width)
  local s = tostring(lnum)
  local w = math.max(1, (digit_width or 2))
  local pad = math.max(0, (w - #s))
  return (string.rep(" ", pad) .. s .. " ")
end
return M
