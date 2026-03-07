-- [nfnl] fnl/metabuffer/prompt/util.fnl
local M = {}
M.ESCAPE_ECHO = {[{"\\"}] = "\\\\", [{"\""}] = "\\\""}
M.get_encoding = function()
  return (vim.o.encoding or "utf-8")
end
M.ensure_bytes = function(seed)
  if (type(seed) == "string") then
    return seed
  else
    return tostring(seed)
  end
end
M.ensure_str = function(seed)
  if (type(seed) == "string") then
    return seed
  else
    return tostring(seed)
  end
end
M.int2char = function(code)
  return vim.fn.nr2char(code)
end
M.int2repr = function(code)
  if (type(code) == "number") then
    return M.int2char(code)
  else
    return tostring(code)
  end
end
M.getchar = function(...)
  local args = {...}
  local unpack_fn = (table.unpack or unpack)
  local packed = {pcall(vim.fn.getchar, unpack_fn(args))}
  local ok = packed[1]
  local ret = packed[2]
  if not ok then
    return 0
  else
    if (type(ret) == "number") then
      if (ret == 3) then
        error("Keyboard interrupt")
      else
      end
      return ret
    else
      return M.ensure_str(ret)
    end
  end
end
M.build_echon_expr = function(text, hl)
  local safe = string.gsub(string.gsub((text or ""), "\\\\", "\\\\\\\\"), "\"", "\\\\\"")
  return string.format("echohl %s|echon \"%s\"", (hl or "None"), safe)
end
M.build_keyword_pattern_set = function(_)
  return {pattern = "[%w_]", inverse = "[^%w_]"}
end
M.build_keywords_regex = function(_)
  return vim.regex("\\k\\+")
end
return M
