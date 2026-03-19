-- [nfnl] fnl/metabuffer/source/init.fnl
local text = require("metabuffer.source.text")
local file = require("metabuffer.source.file")
local M = {}
M["provider-for-ref"] = function(ref)
  if (((ref and ref.kind) or "") == "file-entry") then
    return file
  else
    return text
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
M["info-suffix"] = function(session, ref, mode, read_file_lines_cached)
  local provider = M["provider-for-ref"](ref)
  return provider["info-suffix"](session, ref, mode, read_file_lines_cached)
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
  if (type(f) == "function") then
    return f(session, ref, ctx)
  else
    return {path = M["info-path"](ref, false), ["icon-path"] = M["info-path"](ref, false), ["show-icon"] = true, ["highlight-dir"] = true, ["highlight-file"] = true, sign = {text = "  ", hl = "LineNr"}, suffix = M["info-suffix"](session, ref, mode, read_file_lines_cached), ["suffix-prefix"] = "  ", ["suffix-highlights"] = {}}
  end
end
M["preview-filetype"] = function(ref)
  local provider = M["provider-for-ref"](ref)
  return provider["preview-filetype"](ref)
end
M["preview-lines"] = function(session, ref, height, read_file_lines_cached)
  local provider = M["provider-for-ref"](ref)
  return provider["preview-lines"](session, ref, height, read_file_lines_cached)
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
