-- [nfnl] fnl/metabuffer/transform/css.fnl
local M = {}
M["transform-key"] = "css"
M["query-directive-specs"] = {{kind = "toggle", long = "css", ["token-key"] = "include-css", doc = "Pretty-print minified CSS lines.", ["compat-key"] = "css"}}
local function _repeat(s, n)
  return string.rep((s or ""), math.max(0, (n or 0)))
end
local function pretty_css_lines(line)
  local txt = (line or "")
  local normalized = string.gsub(string.gsub(string.gsub(txt, "%s*{%s*", " {\n"), "%s*}%s*", "\n}\n"), "%s*;%s*", ";\n")
  local tokens = vim.split(normalized, "\n", {plain = true, trimempty = true})
  local out = {}
  local depth0 = 0
  local depth = depth0
  for _, token in ipairs(tokens) do
    local trimmed = vim.trim(token)
    if (trimmed == "}") then
      depth = math.max(0, (depth - 1))
    else
    end
    table.insert(out, (_repeat("  ", depth) .. trimmed))
    if vim.endswith(trimmed, "{") then
      depth = (depth + 1)
    else
    end
  end
  return out
end
M["should-apply-line?"] = function(line, _ctx)
  local trimmed = vim.trim((line or ""))
  return ((#trimmed > 40) and (nil ~= string.find(trimmed, "{", 1, true)) and (nil ~= string.find(trimmed, "}", 1, true)) and (nil ~= string.find(trimmed, ";", 1, true)))
end
M["apply-line"] = function(line, _ctx)
  return pretty_css_lines(line)
end
M["reverse-line"] = function(lines, _ctx)
  local parts = {}
  local prev_open_3f = false
  local prev_open = prev_open_3f
  for _, raw in ipairs((lines or {})) do
    local trimmed = vim.trim((raw or ""))
    if (trimmed ~= "") then
      if (trimmed == "}") then
        table.insert(parts, "}")
      else
        if ((#parts > 0) and not prev_open and not vim.endswith(parts[#parts], "{") and (trimmed ~= "}")) then
          local tail = parts[#parts]
          if (tail and not vim.endswith(tail, "{") and not vim.endswith(tail, ";")) then
            parts[#parts] = (tail .. " ")
          else
          end
        else
        end
        table.insert(parts, trimmed)
      end
      prev_open = vim.endswith(trimmed, "{")
    else
    end
  end
  return {table.concat(parts, "")}
end
return M
