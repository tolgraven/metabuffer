-- [nfnl] fnl/metabuffer/context/expand.fnl
local M = {}
local function buf_for_ref(ref)
  if (ref and ref.buf and vim.api.nvim_buf_is_valid(ref.buf)) then
    return ref.buf
  else
    return nil
  end
end
local function filetype_for_ref(ref)
  local val_111_auto = buf_for_ref(ref)
  if val_111_auto then
    local buf = val_111_auto
    return vim.bo[buf].filetype
  else
    local val_111_auto0 = (ref and ref.path)
    if val_111_auto0 then
      local path = val_111_auto0
      local ok,ft = pcall(vim.filetype.match, {filename = path})
      if (ok and (type(ft) == "string")) then
        return ft
      else
        return ""
      end
    else
      return ""
    end
  end
end
local function lines_for_ref(session, ref, read_file_lines_cached)
  local val_111_auto = buf_for_ref(ref)
  if val_111_auto then
    local buf = val_111_auto
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  else
    if (ref and ref.path and (1 == vim.fn.filereadable(ref.path))) then
      local lines = read_file_lines_cached(ref.path, {["include-binary"] = (session and session["effective-include-binary"]), ["hex-view"] = (session and session["effective-include-hex"])})
      if (type(lines) == "table") then
        return lines
      else
        return {}
      end
    else
      return {}
    end
  end
end
local function ensure_ts_buf(ref)
  local val_111_auto = buf_for_ref(ref)
  if val_111_auto then
    local buf = val_111_auto
    return buf
  else
    if (ref and ref.path and (1 == vim.fn.filereadable(ref.path))) then
      local buf = vim.fn.bufadd(ref.path)
      pcall(vim.fn.bufload, buf)
      if vim.api.nvim_buf_is_valid(buf) then
        return buf
      else
        return nil
      end
    else
      return nil
    end
  end
end
local function node_type_matches_3f(mode, node_type)
  local t = string.lower((node_type or ""))
  if (mode == "fn") then
    return (not not string.find(t, "function", 1, true) or not not string.find(t, "method", 1, true) or not not string.find(t, "func", 1, true))
  elseif (mode == "class") then
    return (not not string.find(t, "class", 1, true) or not not string.find(t, "interface", 1, true) or not not string.find(t, "struct", 1, true) or not not string.find(t, "impl", 1, true) or not not string.find(t, "module", 1, true))
  elseif (mode == "scope") then
    return (node_type_matches_3f("fn", t) or node_type_matches_3f("class", t) or not not string.find(t, "block", 1, true) or (t == "chunk") or (t == "program") or (t == "source_file"))
  else
    return false
  end
end
local function ts_range_for_mode(ref, mode)
  local val_111_auto = ensure_ts_buf(ref)
  if val_111_auto then
    local buf = val_111_auto
    local parser = vim.treesitter.get_parser(buf)
    local trees = (parser and parser.parse(parser))
    local tree = (trees and trees[1])
    local root = (tree and tree.root(tree))
    local row = math.max(0, ((ref.lnum or 1) - 1))
    local node = (root and root.named_descendant_for_range(root, row, 0, row, 0))
    if node then
      local cur = node
      local found = nil
      while (cur and not found) do
        if node_type_matches_3f(mode, cur.type(cur)) then
          found = cur
        else
        end
        cur = cur.parent(cur)
      end
      if found then
        local sr,_,er,_0 = found.range(found)
        return {start = (sr + 1), ["end"] = (er + 1)}
      else
        return nil
      end
    else
      return nil
    end
  else
    return nil
  end
end
local function identifier_at_ref(session, ref, read_file_lines_cached)
  local lines = lines_for_ref(session, ref, read_file_lines_cached)
  local line = (lines[(ref.lnum or 1)] or (ref.line or ""))
  return (string.match(line, "[%a_][%w_%.:]*") or "")
end
local function exact_word_find_3f(line, word)
  local pat = ("%f[%w_]" .. vim.pesc((word or "")) .. "%f[^%w_]")
  return (((word or "") ~= "") and not not string.find((line or ""), pat))
end
local function around_range(ref, total, around)
  local lnum = math.max(1, (ref.lnum or 1))
  return {start = math.max(1, (lnum - around)), ["end"] = math.min(total, (lnum + around))}
end
local function fallback_range(ref, mode, total, around)
  if (mode == "line") then
    return {start = math.max(1, (ref.lnum or 1)), ["end"] = math.max(1, (ref.lnum or 1))}
  elseif (mode == "file") then
    return {start = 1, ["end"] = math.max(1, total)}
  else
    return around_range(ref, total, around)
  end
end
local function normalized_mode(mode)
  local m = string.lower(vim.trim((mode or "")))
  if ((m == "") or (m == "none") or (m == "off")) then
    return "none"
  elseif ((m == "line") or (m == "lines")) then
    return "line"
  elseif ((m == "around") or (m == "ctx") or (m == "context")) then
    return "around"
  elseif ((m == "fn") or (m == "function") or (m == "method")) then
    return "fn"
  elseif ((m == "class") or (m == "type")) then
    return "class"
  elseif ((m == "scope") or (m == "block")) then
    return "scope"
  elseif ((m == "file") or (m == "buffer")) then
    return "file"
  elseif ((m == "usage") or (m == "usages") or (m == "refs") or (m == "references")) then
    return "usage"
  elseif (m == "env") then
    return "env"
  else
    return m
  end
end
local function expansion_range(session, ref, mode, read_file_lines_cached, around)
  local lines = lines_for_ref(session, ref, read_file_lines_cached)
  local total = #lines
  local norm = normalized_mode(mode)
  if (norm == "none") then
    return nil
  elseif (norm == "usage") then
    return nil
  elseif (norm == "env") then
    return (ts_range_for_mode(ref, "scope") or fallback_range(ref, "around", total, around))
  elseif ((norm == "fn") or (norm == "class") or (norm == "scope")) then
    return (ts_range_for_mode(ref, norm) or fallback_range(ref, "around", total, around))
  else
    return fallback_range(ref, norm, total, around)
  end
end
local function block_key(ref, start_lnum, end_lnum, mode)
  return ((ref.path or "") .. "|" .. tostring(start_lnum) .. "|" .. tostring(end_lnum) .. "|" .. (mode or ""))
end
local function append_usage_blocks_21(session, blocks, seen, refs, read_file_lines_cached, around, max_blocks)
  if (#blocks < max_blocks) then
    local needle = identifier_at_ref(session, refs[1], read_file_lines_cached)
    if (needle ~= "") then
      for _, ref in ipairs(((session and session.meta and session.meta.buf and session.meta.buf["source-refs"]) or refs)) do
        if (#blocks < max_blocks) then
          local lines = lines_for_ref(session, ref, read_file_lines_cached)
          local total = #lines
          if (ref and ((ref.kind or "") ~= "file-entry") and (total > 0) and exact_word_find_3f((lines[(ref.lnum or 1)] or ""), needle)) then
            local rng = around_range(ref, total, around)
            local key = block_key(ref, rng.start, rng["end"], "usage")
            if not seen[key] then
              seen[key] = true
              table.insert(blocks, {ref = ref, mode = "usage", path = (ref.path or ""), ["start-lnum"] = rng.start, ["end-lnum"] = rng["end"], ["focus-lnum"] = (ref.lnum or 1), lines = vim.list_slice(lines, rng.start, rng["end"]), label = ("usage:" .. needle)})
            else
            end
          else
          end
        else
        end
      end
      return nil
    else
      return nil
    end
  else
    return nil
  end
end
local function append_env_blocks_21(session, blocks, seen, refs, read_file_lines_cached, around, max_blocks)
  if (#blocks < max_blocks) then
    for _, ref in ipairs(refs) do
      if (#blocks < max_blocks) then
        local val_110_auto = expansion_range(session, ref, "env", read_file_lines_cached, around)
        if val_110_auto then
          local rng = val_110_auto
          local lines = lines_for_ref(session, ref, read_file_lines_cached)
          local key = block_key(ref, rng.start, rng["end"], "env")
          if not seen[key] then
            seen[key] = true
            table.insert(blocks, {ref = ref, mode = "env", path = (ref.path or ""), ["start-lnum"] = rng.start, ["end-lnum"] = rng["end"], ["focus-lnum"] = (ref.lnum or 1), lines = vim.list_slice(lines, rng.start, rng["end"]), label = "env"})
          else
          end
        else
        end
      else
      end
    end
    return nil
  else
    return nil
  end
end
M["normalized-mode"] = function(mode)
  return normalized_mode(mode)
end
M["context-blocks"] = function(session, refs, opts)
  local mode = normalized_mode(opts.mode)
  local read_file_lines_cached = opts["read-file-lines-cached"]
  local around = (opts["around-lines"] or 3)
  local max_blocks = math.max(1, (opts["max-blocks"] or 24))
  local blocks = {}
  local seen = {}
  if (mode == "none") then
    do local _ = {} end
  elseif (mode == "usage") then
    append_usage_blocks_21(session, blocks, seen, refs, read_file_lines_cached, around, max_blocks)
  elseif (mode == "env") then
    append_env_blocks_21(session, blocks, seen, refs, read_file_lines_cached, around, max_blocks)
  else
    for _, ref in ipairs((refs or {})) do
      if (#blocks < max_blocks) then
        local val_110_auto = expansion_range(session, ref, mode, read_file_lines_cached, around)
        if val_110_auto then
          local rng = val_110_auto
          local lines = lines_for_ref(session, ref, read_file_lines_cached)
          local key = block_key(ref, rng.start, rng["end"], mode)
          if not seen[key] then
            seen[key] = true
            table.insert(blocks, {ref = ref, mode = mode, path = (ref.path or ""), ["start-lnum"] = rng.start, ["end-lnum"] = rng["end"], ["focus-lnum"] = (ref.lnum or 1), lines = vim.list_slice(lines, rng.start, rng["end"]), label = mode})
          else
          end
        else
        end
      else
      end
    end
  end
  return blocks
end
return M
