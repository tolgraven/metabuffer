-- [nfnl] fnl/metabuffer/source/lgrep.fnl
local text = require("metabuffer.source.text")
local util = require("metabuffer.util")
local M = {}
M["provider-key"] = "lgrep"
M["query-directive-specs"] = {{kind = "flag", long = "lgrep", ["token-key"] = "source-mode", arg = "{query}", doc = "Switch the source set to lgrep semantic search hits.", value = "search", await = {kind = "query-source", ["source-key"] = "lgrep", mode = "search"}}, {kind = "flag", long = "lgrep:u", ["token-key"] = "source-mode", arg = "{symbol}", doc = "Switch the source set to lgrep usages for a symbol.", value = "usages", await = {kind = "query-source", ["source-key"] = "lgrep", mode = "usages"}}, {kind = "flag", long = "lgrep:d", ["token-key"] = "source-mode", arg = "{symbol}", doc = "Switch the source set to lgrep definitions for a symbol.", value = "definition", await = {kind = "query-source", ["source-key"] = "lgrep", mode = "definition"}}}
local function active_specs(parsed)
  local source_lines = (parsed["source-lines"] or parsed["lgrep-lines"] or {})
  local out = {}
  for _, spec in ipairs(source_lines) do
    if (spec and (type(spec) == "table") and ((spec.key or "lgrep") == "lgrep") and (vim.trim((spec.query or "")) ~= "")) then
      table.insert(out, {kind = (spec.kind or "search"), query = vim.trim((spec.query or ""))})
    else
    end
  end
  return out
end
M["active?"] = function(parsed)
  return (#active_specs(parsed) > 0)
end
M.signature = function(parsed)
  local parts = {}
  for _, spec in ipairs(active_specs(parsed)) do
    table.insert(parts, ((spec.kind or "search") .. ":" .. (spec.query or "")))
  end
  return table.concat(parts, "|")
end
M["debounce-ms"] = function(settings, _parsed)
  return math.max(0, (settings["lgrep-debounce-ms"] or 260))
end
M["hit-prefix"] = function(ref)
  return text["hit-prefix"](ref)
end
M["info-path"] = function(ref, full_path_3f)
  return text["info-path"](ref, full_path_3f)
end
M["info-suffix"] = function(session, ref, mode, read_file_lines_cached, read_file_view_cached)
  return text["info-suffix"](session, ref, mode, read_file_lines_cached, read_file_view_cached)
end
M["info-meta"] = function(session, ref)
  return text["info-meta"](session, ref)
end
local function source_sign(ref)
  local lgrep_kind = ((ref and ref["lgrep-kind"]) or "")
  if (lgrep_kind == "usages") then
    return util["icon-sign"]({category = "lsp", name = "reference", fallback = "\238\172\182", hl = "MiniIconsCyan"})
  elseif (lgrep_kind == "definition") then
    return util["icon-sign"]({category = "lsp", name = "function", fallback = "\238\170\140", hl = "MiniIconsPurple"})
  else
    return util["icon-sign"]({category = "filetype", name = "telescopeprompt", fallback = "\243\176\141\137", hl = "MiniIconsGreen"})
  end
end
M["info-view"] = function(session, ref, ctx)
  local view = text["info-view"](session, ref, ctx)
  view["sign"] = source_sign(ref)
  return view
end
M["preview-filetype"] = function(ref)
  return text["preview-filetype"](ref)
end
M["preview-lines"] = function(session, ref, height, read_file_lines_cached, read_file_view_cached)
  return text["preview-lines"](session, ref, height, read_file_lines_cached, read_file_view_cached)
end
local function absolute_path(root, path, canonical_path)
  local p = (path or "")
  if (p == "") then
    return nil
  else
    if vim.startswith(p, "/") then
      return canonical_path(p)
    else
      return canonical_path((root .. "/" .. p))
    end
  end
end
local function run_command(settings, spec)
  local bin = (settings["lgrep-bin"] or "lgrep")
  local limit = tostring((settings["lgrep-limit"] or 80))
  local cmd
  if (spec.kind == "usages") then
    cmd = {bin, "search", "--usages", spec.query, "-j", "-l", limit}
  elseif (spec.kind == "definition") then
    cmd = {bin, "search", "--definition", spec.query, "-j", "-l", limit}
  else
    cmd = {bin, "search", spec.query, "-j", "-l", limit}
  end
  local out = vim.fn.system(cmd)
  if not (vim.v.shell_error == 0) then
    return {count = 0, results = {}}
  else
    local ok,decoded = pcall(vim.json.decode, out)
    if (ok and (type(decoded) == "table")) then
      return decoded
    else
      return {count = 0, results = {}}
    end
  end
end
local function resolve_runner(settings)
  return (((type(settings["lgrep-runner"]) == "function") and settings["lgrep-runner"]) or ((type(_G.__meta_test_lgrep_runner) == "function") and _G.__meta_test_lgrep_runner) or run_command)
end
local function add_result_21(groups, root, canonical_path, spec, result)
  local path = absolute_path(root, (result.file or ""), canonical_path)
  local line0 = (tonumber(result.line) or 1)
  local score = (tonumber(result.score) or 0)
  local chunk = (result.chunk or "")
  local bucket_key = (path or "")
  if path then
    local bucket = (groups[bucket_key] or {path = path, ["best-score"] = score, items = {}})
    bucket["best-score"] = math.max((bucket["best-score"] or score), score)
    table.insert(bucket.items, {path = path, line = line0, score = score, chunk = chunk, kind = spec.kind, query = spec.query})
    groups[bucket_key] = bucket
    return nil
  else
    return nil
  end
end
local function sort_groups(groups)
  local out = {}
  for _, bucket in pairs(groups) do
    table.insert(out, bucket)
  end
  local function _9_(a, b)
    if ((a["best-score"] or 0) == (b["best-score"] or 0)) then
      return ((a.path or "") < (b.path or ""))
    else
      return ((a["best-score"] or 0) > (b["best-score"] or 0))
    end
  end
  table.sort(out, _9_)
  return out
end
local function sort_items_21(items)
  local function _11_(a, b)
    if ((a.line or 0) == (b.line or 0)) then
      return ((a.score or 0) > (b.score or 0))
    else
      return ((a.line or 0) < (b.line or 0))
    end
  end
  return table.sort(items, _11_)
end
local function append_item_21(content, refs, item)
  local chunk_lines = vim.split((item.chunk or ""), "\n", {plain = true, trimempty = false})
  local lines
  if (#chunk_lines > 0) then
    lines = chunk_lines
  else
    lines = {""}
  end
  local line0 = math.max(1, (item.line or 1))
  for idx, line in ipairs(lines) do
    local lnum = (line0 + idx + -1)
    local text0 = (line or "")
    table.insert(content, text0)
    table.insert(refs, {path = item.path, lnum = lnum, ["open-lnum"] = lnum, ["preview-lnum"] = lnum, line = text0, kind = "lgrep-hit", ["lgrep-kind"] = item.kind, ["lgrep-query"] = item.query, ["lgrep-score"] = item.score})
  end
  return nil
end
M["collect-source-set"] = function(settings, parsed, canonical_path)
  local specs = active_specs(parsed)
  if (#specs == 0) then
    return nil
  else
    local runner = resolve_runner(settings)
    local root = vim.fn.getcwd()
    local groups = {}
    for _, spec in ipairs(specs) do
      local decoded = (runner(settings, spec) or {count = 0, results = {}})
      for _0, result in ipairs((decoded.results or {})) do
        add_result_21(groups, root, canonical_path, spec, result)
      end
    end
    local content = {}
    local refs = {}
    for _, bucket in ipairs(sort_groups(groups)) do
      sort_items_21(bucket.items)
      for _0, item in ipairs((bucket.items or {})) do
        append_item_21(content, refs, item)
      end
    end
    return {content = content, refs = refs}
  end
end
return M
