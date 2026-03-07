-- [nfnl] fnl/metabuffer/prompt/keystroke.fnl
local key = require("metabuffer.prompt.key")
local M = {}
local mt = {}
mt.__tostring = function(self)
  local out = {}
  for _, k in ipairs(self) do
    table.insert(out, (k.char or ""))
  end
  return table.concat(out, "")
end
local function tokenise(expr)
  if not (type(expr) == "string") then
    return expr
  else
    if (string.find(expr, "\128", 1, true) or vim.startswith(expr, "<80>")) then
      return {expr}
    else
      local out = {}
      local len = #expr
      local i = 1
      while (i <= len) do
        if (string.sub(expr, i, i) == "<") then
          local j = string.find(expr, ">", i, true)
          if j then
            table.insert(out, string.sub(expr, i, j))
            i = (j + 1)
          else
            table.insert(out, string.sub(expr, i, i))
            i = (i + 1)
          end
        else
          table.insert(out, string.sub(expr, i, i))
          i = (i + 1)
        end
      end
      return out
    end
  end
end
M.startswith = function(lhs, rhs)
  if (#lhs < #rhs) then
    return false
  else
    local ok = true
    for i = 1, #rhs do
      if (ok and (lhs[i].code ~= rhs[i].code)) then
        ok = false
      else
      end
    end
    return ok
  end
end
M.parse = function(nvim, expr)
  if (type(expr) == "table") then
    return setmetatable(expr, mt)
  else
    local tokens = tokenise(expr)
    local out = {}
    for _, t in ipairs(tokens) do
      table.insert(out, key.parse(nvim, t))
    end
    return setmetatable(out, mt)
  end
end
M.concat = function(a, b)
  local out = {}
  for _, x in ipairs(a) do
    table.insert(out, x)
  end
  for _, x in ipairs(b) do
    table.insert(out, x)
  end
  return setmetatable(out, mt)
end
return M
