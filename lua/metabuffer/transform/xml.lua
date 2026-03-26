-- [nfnl] fnl/metabuffer/transform/xml.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
M["transform-key"] = "xml"
M["query-directive-specs"] = {{kind = "toggle", long = "xml", ["token-key"] = "include-xml", doc = "Pretty-print minified XML lines.", ["compat-key"] = "xml"}}
local function _repeat(s, n)
  return string.rep((s or ""), math.max(0, (n or 0)))
end
local function tokenize_xml(txt)
  local spaced = string.gsub((txt or ""), "><", ">\n<")
  return vim.split(spaced, "\n", {plain = true, trimempty = true})
end
local function pretty_xml_lines(line)
  local tokens = tokenize_xml(vim.trim((line or "")))
  local out = {}
  local depth0 = 0
  local depth = depth0
  for _, token in ipairs(tokens) do
    local trimmed = vim.trim(token)
    local close_3f = vim.startswith(trimmed, "</")
    local self_close_3f = (vim.endswith(trimmed, "/>") or vim.startswith(trimmed, "<?") or vim.startswith(trimmed, "<!"))
    local open_3f = (vim.startswith(trimmed, "<") and not close_3f and not self_close_3f)
    if close_3f then
      depth = math.max(0, (depth - 1))
    else
    end
    table.insert(out, (_repeat("  ", depth) .. trimmed))
    if open_3f then
      depth = (depth + 1)
    else
    end
  end
  return out
end
M["should-apply-line?"] = function(line, _ctx)
  local trimmed = vim.trim((line or ""))
  return ((#trimmed > 40) and vim.startswith(trimmed, "<") and (nil ~= string.find(trimmed, "><", 1, true)))
end
M["apply-line"] = function(line, _ctx)
  return pretty_xml_lines(line)
end
M["reverse-line"] = function(lines, _ctx)
  return {table.concat(vim.tbl_map(vim.trim, (lines or {})), "")}
end
return M
