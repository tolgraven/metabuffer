-- [nfnl] fnl/metabuffer/prompt/digraph.fnl
local util = require("metabuffer.prompt.util")
local M = {}
local _instance = nil
local function parse_digraph_output(output)
  local registry = {}
  for _, line in ipairs(vim.split((output or ""), "\n", {trimempty = true})) do
    local k = string.match(line, "(%S%S)%s+%S+%s+%d+")
    local v = string.match(line, "%S%S%s+(%S+)%s+%d+")
    if (k and v) then
      registry[k] = v
    else
    end
  end
  return registry
end
M.new = function()
  if _instance then
    return _instance
  else
    _instance = {registry = nil}
    _instance.find = function(_, ch1, ch2)
      if not _instance.registry then
        _instance.registry = parse_digraph_output(vim.fn.execute("digraphs"))
      else
      end
      return (_instance.registry[(ch1 .. ch2)] or _instance.registry[(ch2 .. ch1)] or ch2)
    end
    _instance.retrieve = function(_)
      local code1 = util.getchar()
      if ((type(code1) == "string") and vim.startswith(code1, "<")) then
        return code1
      else
        local code2 = util.getchar()
        if ((type(code2) == "string") and vim.startswith(code2, "<")) then
          return code2
        else
          local ch1
          if (type(code1) == "number") then
            ch1 = util.int2char(code1)
          else
            ch1 = tostring(code1)
          end
          local ch2
          if (type(code2) == "number") then
            ch2 = util.int2char(code2)
          else
            ch2 = tostring(code2)
          end
          return _instance.find(_instance, ch1, ch2)
        end
      end
    end
    return _instance
  end
end
return M
