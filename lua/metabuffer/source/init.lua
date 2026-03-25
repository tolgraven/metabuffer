-- [nfnl] fnl/metabuffer/source/init.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local text = require("metabuffer.source.text")
local file = require("metabuffer.source.file")
local lgrep = require("metabuffer.source.lgrep")
local M = {}
local query_sources = {{key = "lgrep", provider = lgrep}}
local function query_source_provider(key)
  local found = nil
  local out = found
  for _, entry in ipairs(query_sources) do
    if (not out and (entry.key == key)) then
      out = entry.provider
    else
    end
  end
  return out
end
local function query_source_entry(parsed)
  if parsed then
    local found = nil
    local out = found
    for _, entry in ipairs(query_sources) do
      local provider = entry.provider
      local active_3f = provider["active?"]
      if (not out and (type(active_3f) == "function") and active_3f(parsed)) then
        out = entry
      else
      end
    end
    return out
  else
    return nil
  end
end
M["provider-for-ref"] = function(ref)
  if (((ref and ref.kind) or "") == "file-entry") then
    return file
  elseif (((ref and ref.kind) or "") == "lgrep-hit") then
    return lgrep
  else
    return text
  end
end
M["query-state-init"] = function()
  return {["source-lines"] = {}, ["lgrep-lines"] = {}, ["include-files"] = nil, files = nil, ["file-lines"] = {}, ["line-source"] = nil, ["await-directive"] = nil, ["file-await-token"] = false}
end
M["parse-bare-token"] = function(state, tok, unquote_token)
  local f = file["parse-bare-token"]
  if (type(f) == "function") then
    return f(state, tok, unquote_token)
  else
    return nil
  end
end
M["apply-parsed-directive"] = function(state, key, value, await)
  local next = vim.deepcopy(state)
  next[key] = value
  if (await and not (value == false)) then
    next["await-directive"] = await
    if (await.kind == "file") then
      next["file-await-token"] = true
    else
    end
  else
  end
  return next
end
M["apply-awaited-directive"] = function(state, directive, arg)
  local next = vim.deepcopy(state)
  local kind = (directive and directive.kind)
  if (kind == "file") then
    table.insert(next["file-lines"], arg)
    next["file-await-token"] = false
  elseif (kind == "query-source") then
    next["line-source"] = {key = (directive["source-key"] or ""), kind = (directive.mode or "search"), query = arg}
  else
  end
  next["await-directive"] = nil
  return next
end
local function source_lines_for_key(parsed, key)
  local out = {}
  for _, spec in ipairs((parsed["source-lines"] or {})) do
    if (spec and ((spec.key or "") == key)) then
      table.insert(out, {kind = (spec.kind or "search"), query = (spec.query or "")})
    else
      table.insert(out, nil)
    end
  end
  return out
end
M["finalize-parsed!"] = function(parsed)
  parsed["files"] = parsed["include-files"]
  parsed["lgrep-lines"] = source_lines_for_key(parsed, "lgrep")
  return parsed
end
M["consume-pending-token"] = function(state, tok, unquote_token)
  if (state["file-await-token"] and (vim.trim((tok or "")) ~= "")) then
    local next = vim.deepcopy(state)
    table.insert(next["file-lines"], unquote_token(tok))
    next["file-await-token"] = false
    return next
  else
    return nil
  end
end
M["query-compat-view"] = function(parsed)
  return {["lgrep-lines"] = (parsed["lgrep-lines"] or {}), ["include-files"] = parsed["include-files"], ["file-lines"] = (parsed["file-lines"] or {})}
end
M["empty-query-compat-view"] = function()
  return {["lgrep-lines"] = {}, ["include-files"] = nil, ["file-lines"] = {}}
end
M["apply-default-query-source"] = function(parsed, enabled_3f, tokenize_line)
  local provider = query_source_provider("lgrep")
  local active_3f = provider["active?"]
  if (not enabled_3f or ((type(active_3f) == "function") and active_3f(parsed))) then
    return parsed
  else
    local next = vim.deepcopy((parsed or {}))
    local out_lines = {}
    local out_source = {}
    for _, line in ipairs((next.lines or {})) do
      local tokens = tokenize_line((line or ""))
      if (#tokens > 0) then
        local first = tokens[1]
        local rest = {}
        for i = 2, #tokens do
          table.insert(rest, tokens[i])
        end
        table.insert(out_source, {key = "lgrep", kind = "search", query = first})
        table.insert(out_lines, table.concat(rest, " "))
      else
        table.insert(out_source, nil)
        table.insert(out_lines, "")
      end
    end
    next["lines"] = out_lines
    next["source-lines"] = out_source
    return M["finalize-parsed!"](next)
  end
end
M["hit-prefix"] = function(ref)
  local provider = M["provider-for-ref"](ref)
  return provider["hit-prefix"](ref)
end
M["info-path"] = function(ref, full_path_3f)
  local provider = M["provider-for-ref"](ref)
  return provider["info-path"](ref, full_path_3f)
end
M["info-suffix"] = function(session, ref, mode, read_file_lines_cached, read_file_view_cached)
  local provider = M["provider-for-ref"](ref)
  return provider["info-suffix"](session, ref, mode, read_file_lines_cached, read_file_view_cached)
end
M["info-meta"] = function(session, ref)
  local provider = M["provider-for-ref"](ref)
  local f = provider["info-meta"]
  if (type(f) == "function") then
    return f(session, ref)
  else
    return nil
  end
end
M["info-view"] = function(session, ref, ctx)
  local provider = M["provider-for-ref"](ref)
  local f = provider["info-view"]
  local mode = ((ctx and ctx.mode) or "meta")
  local read_file_lines_cached = (ctx and ctx["read-file-lines-cached"])
  local read_file_view_cached = (ctx and ctx["read-file-view-cached"])
  if (type(f) == "function") then
    return f(session, ref, ctx)
  else
    return {path = M["info-path"](ref, false), ["icon-path"] = M["info-path"](ref, false), ["show-icon"] = true, ["highlight-dir"] = true, ["highlight-file"] = true, sign = {text = "  ", hl = "LineNr"}, suffix = M["info-suffix"](session, ref, mode, read_file_lines_cached, read_file_view_cached), ["suffix-prefix"] = "  ", ["suffix-highlights"] = {}}
  end
end
M["preview-filetype"] = function(ref)
  local provider = M["provider-for-ref"](ref)
  return provider["preview-filetype"](ref)
end
M["preview-lines"] = function(session, ref, height, read_file_lines_cached, read_file_view_cached)
  local provider = M["provider-for-ref"](ref)
  return provider["preview-lines"](session, ref, height, read_file_lines_cached, read_file_view_cached)
end
M["query-source-key"] = function(parsed)
  local entry = query_source_entry(parsed)
  return (entry and entry.key)
end
M["query-source-active?"] = function(parsed)
  return clj.boolean(M["query-source-key"](parsed))
end
M["query-source-signature"] = function(parsed)
  local val_111_auto = query_source_entry(parsed)
  if val_111_auto then
    local entry = val_111_auto
    local provider = entry.provider
    local f = provider.signature
    local sig
    if (type(f) == "function") then
      sig = f(parsed)
    else
      sig = ""
    end
    if (sig ~= "") then
      return (entry.key .. ":" .. sig)
    else
      return entry.key
    end
  else
    return ""
  end
end
M["query-source-debounce-ms"] = function(settings, parsed)
  local val_111_auto = query_source_entry(parsed)
  if val_111_auto then
    local entry = val_111_auto
    local provider = entry.provider
    local f = provider["debounce-ms"]
    if (type(f) == "function") then
      return f(settings, parsed)
    else
      return 0
    end
  else
    return 0
  end
end
M["collect-query-source-set"] = function(settings, parsed, canonical_path)
  local val_111_auto = query_source_entry(parsed)
  if val_111_auto then
    local entry = val_111_auto
    local provider = entry.provider
    local f = provider["collect-source-set"]
    if (type(f) == "function") then
      return f(settings, parsed, canonical_path)
    else
      return nil
    end
  else
    return nil
  end
end
M["provider-for-op"] = function(op)
  if (((op and op["ref-kind"]) or "") == "file-entry") then
    return file
  else
    return text
  end
end
M["apply-write-ops!"] = function(ops)
  local grouped = {}
  for _, op in ipairs((ops or {})) do
    local provider = M["provider-for-op"](op)
    local key = (provider["provider-key"] or "text")
    local bucket = (grouped[key] or {provider = provider, ops = {}})
    local bucket_ops = bucket.ops
    local path = (op.path or "")
    local per_path = (bucket_ops[path] or {})
    table.insert(per_path, op)
    bucket_ops[path] = per_path
    grouped[key] = bucket
  end
  local result = {changed = 0, ["post-lines"] = {}, paths = {}, renames = {}, wrote = false}
  local post_lines = result["post-lines"]
  local paths = result.paths
  local renames = result.renames
  for _, bucket in pairs(grouped) do
    local provider = bucket.provider
    local f = provider["apply-write-ops!"]
    local part
    if (type(f) == "function") then
      part = f(bucket.ops)
    else
      part = {changed = 0, ["post-lines"] = {}, paths = {}, renames = {}, wrote = false}
    end
    if part.wrote then
      result["wrote"] = true
    else
    end
    result["changed"] = (result.changed + (part.changed or 0))
    for path, lines in pairs((part["post-lines"] or {})) do
      post_lines[path] = lines
    end
    for path, v in pairs((part.paths or {})) do
      paths[path] = v
    end
    for old_path, new_path in pairs((part.renames or {})) do
      renames[old_path] = new_path
    end
  end
  return result
end
return M
