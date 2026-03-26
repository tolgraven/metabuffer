local directive = require("metabuffer.query.directive")

local order = { option = 1, scope = 2, transform = 3, source = 4 }

local function field(tbl, key)
  return tbl[key] or tbl[key:gsub("_", "-")]
end

local function sort_items(items)
  table.sort(items, function(a, b)
    local ao = order[a.provider_type or "source"] or 99
    local bo = order[b.provider_type or "source"] or 99
    if ao == bo then
      return (a.long or "") < (b.long or "")
    end
    return ao < bo
  end)
  return items
end

local function disable_forms(prefix, spec)
  if field(spec, "kind") ~= "toggle" then
    return nil
  end
  local forms = {}
  local long = field(spec, "long") or ""
  local short = field(spec, "short") or ""
  if long ~= "" then
    table.insert(forms, prefix .. "-" .. long)
    table.insert(forms, prefix .. "no" .. long)
  end
  if short ~= "" then
    table.insert(forms, prefix .. "-" .. short)
  end
  return table.concat(forms, ", ")
end

local function read_file(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local function write_file(path, content)
  local f = assert(io.open(path, "wb"))
  f:write(content)
  f:close()
end

local function replace_between(content, start_marker, end_marker, body)
  local pattern = vim.pesc(start_marker) .. ".-" .. vim.pesc(end_marker)
  local replacement = start_marker .. "\n" .. body .. "\n" .. end_marker
  local out, n = content:gsub(pattern, replacement, 1)
  assert(n == 1, "marker block not found: " .. start_marker)
  return out
end

local function catalog()
  local items = directive.catalog("#")
  local out = {}
  for _, item in ipairs(items) do
    out[#out + 1] = {
      long = field(item, "long"),
      short = field(item, "short"),
      kind = field(item, "kind"),
      arg = field(item, "arg"),
      doc = field(item, "doc"),
      literal = field(item, "literal"),
      prefix = field(item, "prefix"),
      provider_type = field(item, "provider_type"),
    }
  end
  return sort_items(out)
end

local function readme_line(prefix, spec)
  local kind = field(spec, "kind") or ""
  local left
  if kind == "literal" then
    left = "`" .. (field(spec, "literal") or "") .. "`"
  elseif kind == "prefix-value" then
    left = "`" .. (field(spec, "prefix") or "") .. (field(spec, "arg") or "{value}") .. "`"
  else
    left = "`#" .. (field(spec, "long") or "") .. "`"
    if (field(spec, "short") or "") ~= "" then
      left = left .. " / `#" .. field(spec, "short") .. "`"
    end
    if (field(spec, "arg") or "") ~= "" then
      left = left .. " `" .. field(spec, "arg") .. "`"
    end
  end
  local lines = { "- " .. left .. " " .. (field(spec, "doc") or "") }
  local disable = disable_forms(prefix, spec)
  if disable then
    lines[#lines + 1] = "  - disable with `" .. disable:gsub(", ", "`, `") .. "`"
  end
  return table.concat(lines, "\n")
end

local function help_line(prefix, spec)
  local kind = field(spec, "kind") or ""
  local left
  if kind == "literal" then
    left = "\t" .. (field(spec, "literal") or "")
  elseif kind == "prefix-value" then
    left = "\t" .. (field(spec, "prefix") or "") .. (field(spec, "arg") or "{value}")
  else
    left = "\t#" .. (field(spec, "long") or "")
    if (field(spec, "short") or "") ~= "" then
      left = left .. " / #" .. field(spec, "short")
    end
    if (field(spec, "arg") or "") ~= "" then
      left = left .. " " .. field(spec, "arg")
    end
  end
  left = left .. "\t" .. (field(spec, "doc") or "")
  local disable = disable_forms(prefix, spec)
  if disable then
    return left .. "\n\t\tDisable with " .. disable .. "."
  end
  return left
end

local function grouped_lines(renderer)
  local groups = {
    { key = "option", title = "Options" },
    { key = "scope", title = "Scope" },
    { key = "transform", title = "Transforms" },
    { key = "source", title = "Sources" },
  }
  local items = catalog()
  local out = {}
  for _, group in ipairs(groups) do
    local first = true
    for _, spec in ipairs(items) do
      if field(spec, "provider_type") == group.key then
        if first then
          out[#out + 1] = "- " .. group.title .. ":" 
          first = false
        end
        out[#out + 1] = renderer("#", spec)
      end
    end
  end
  return table.concat(out, "\n")
end

local function grouped_help_lines(renderer)
  local groups = {
    { key = "option", title = "Options:" },
    { key = "scope", title = "Scope:" },
    { key = "transform", title = "Transforms:" },
    { key = "source", title = "Sources:" },
  }
  local items = catalog()
  local out = {}
  for _, group in ipairs(groups) do
    local first = true
    for _, spec in ipairs(items) do
      if field(spec, "provider_type") == group.key then
        if first then
          out[#out + 1] = "\t" .. group.title
          first = false
        end
        out[#out + 1] = renderer("#", spec)
      end
    end
  end
  return table.concat(out, "\n")
end

local root = vim.fn.getcwd()
local readme_path = root .. "/README.md"
local help_path = root .. "/doc/metabuffer.txt"

local readme = read_file(readme_path)
readme = replace_between(
  readme,
  "### All #toggles",
  "### End #toggles",
  grouped_lines(readme_line)
)
write_file(readme_path, readme)

local help = read_file(help_path)
help = replace_between(
  help,
  "All #toggles",
  "End #toggles",
  grouped_help_lines(help_line)
)
write_file(help_path, help)
