-- [nfnl] fnl/metabuffer/transform/json.fnl
local M = {}
M["transform-key"] = "json"
M["query-directive-specs"] = {{kind = "toggle", long = "json", ["token-key"] = "include-json", doc = "Pretty-print minified JSON lines.", ["compat-key"] = "json"}}
local function _repeat(s, n)
  return string.rep((s or ""), math.max(0, (n or 0)))
end
local function is_array_3f(v)
  return (vim.fn.type(v) == vim.v.t_list)
end
local function is_dict_3f(v)
  return (vim.fn.type(v) == vim.v.t_dict)
end
local function sorted_keys(tbl)
  local out = {}
  for k, _ in pairs(tbl) do
    table.insert(out, k)
  end
  table.sort(out)
  return out
end
local function format_json(v, indent)
  local n = (indent or 0)
  local pad = _repeat("  ", n)
  local inner = _repeat("  ", (n + 1))
  if is_array_3f(v) then
    local out = {"["}
    for i, x in ipairs(v) do
      local _1_
      if (i < #v) then
        _1_ = ","
      else
        _1_ = ""
      end
      table.insert(out, (inner .. format_json(x, (n + 1)) .. _1_))
    end
    table.insert(out, (pad .. "]"))
    return table.concat(out, "\n")
  else
    if is_dict_3f(v) then
      local keys = sorted_keys(v)
      local out = {"{"}
      for i, k in ipairs(keys) do
        local _3_
        if (i < #keys) then
          _3_ = ","
        else
          _3_ = ""
        end
        table.insert(out, (inner .. vim.json.encode(k) .. ": " .. format_json(v[k], (n + 1)) .. _3_))
      end
      table.insert(out, (pad .. "}"))
      return table.concat(out, "\n")
    else
      return vim.json.encode(v)
    end
  end
end
M["should-apply-line?"] = function(line, _ctx)
  local trimmed = vim.trim((line or ""))
  if ((#trimmed > 40) and (vim.startswith(trimmed, "{") or vim.startswith(trimmed, "[")) and (nil ~= string.find(trimmed, ":", 1, true))) then
    local ok,_ = pcall(vim.json.decode, trimmed)
    return ok
  else
    return false
  end
end
M["apply-line"] = function(line, _ctx)
  local trimmed = vim.trim((line or ""))
  local ok,decoded = pcall(vim.json.decode, trimmed)
  if ok then
    return vim.split(format_json(decoded, 0), "\n", {plain = true, trimempty = false})
  else
    return nil
  end
end
local function minify_json(txt)
  local s = (txt or "")
  local chars = {}
  local in_string_3f = false
  local escape_3f = false
  local in_string = in_string_3f
  local escape = escape_3f
  for i = 1, #s do
    local ch = string.sub(s, i, i)
    if in_string then
      table.insert(chars, ch)
      if escape then
        escape = false
      else
        if (ch == "\\") then
          escape = true
        else
          if (ch == "\"") then
            in_string = false
          else
          end
        end
      end
    else
      if (ch == "\"") then
        table.insert(chars, ch)
        in_string = true
        escape = false
      else
        if not string.match(ch, "%s") then
          table.insert(chars, ch)
        else
        end
      end
    end
  end
  return table.concat(chars, "")
end
M["reverse-line"] = function(lines, _ctx)
  local joined = table.concat((lines or {}), "\n")
  local compact = minify_json(joined)
  local ok,_ = pcall(vim.json.decode, compact)
  if ok then
    return {compact}
  else
    return nil
  end
end
return M
