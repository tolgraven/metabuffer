-- [nfnl] fnl/io/gitlab/andreyorst/cljlib/string.fnl
local join = function(separator, parts)
  return table.concat((parts or {}), (separator or ""))
end
local lower_case = function(text)
  return string.lower((text or ""))
end
local replace = function(text, match, replacement)
  local result = string.gsub((text or ""), match, (replacement or ""))
  return result
end
local starts_with_3f = function(text, prefix)
  return vim.startswith((text or ""), (prefix or ""))
end
local substring = function(text, start, finish)
  if (finish == nil) then
    return string.sub((text or ""), start)
  else
    return string.sub((text or ""), start, finish)
  end
end
local match = function(text, pattern)
  return string.match((text or ""), (pattern or ""))
end
return {join = join, ["lower-case"] = lower_case, replace = replace, ["starts-with?"] = starts_with_3f, substring = substring, match = match}
