-- [nfnl] fnl/metabuffer/sign.fnl
local M = {}
local change_sign_group = "MetaBufferChanges"
local sign_added = "MetaBufLineAdded"
local sign_modified = "MetaBufLineModified"
local sign_removed = "MetaBufLineRemoved"
local function ensure_change_signs_defined_21()
  pcall(vim.fn.sign_define, sign_added, {text = "\226\156\154", texthl = "MetaBufSignAdded"})
  pcall(vim.fn.sign_define, sign_modified, {text = "\226\156\185", texthl = "MetaBufSignModified"})
  return pcall(vim.fn.sign_define, sign_removed, {text = "\239\131\157", texthl = "MetaBufSignRemoved"})
end
local function bvar(buf, name, default)
  local ok,v = pcall(vim.api.nvim_buf_get_var, buf, name)
  if ok then
    return v
  else
    return default
  end
end
local function place_sign_21(buf, id, name, lnum)
  if (buf and vim.api.nvim_buf_is_valid(buf) and (lnum > 0)) then
    return pcall(vim.fn.sign_place, id, change_sign_group, name, buf, {lnum = lnum, priority = 20})
  else
    return nil
  end
end
local function ref_baseline_line(session, src_idx)
  local refs = (session and session.meta and session.meta.buf and session.meta.buf["source-refs"])
  local ref = (refs and src_idx and refs[src_idx])
  local line = (ref and ref.line)
  if (type(line) == "string") then
    return line
  else
    local content = (session and session.meta and session.meta.buf and session.meta.buf.content)
    return ((content and src_idx and content[src_idx]) or "")
  end
end
local function diff_sign_events(session, buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local idxs = ((session and session.meta and session.meta.buf and session.meta.buf.indices) or {})
  local line_count = #lines
  local idx_count = #idxs
  local max_count = math.max(line_count, idx_count)
  local out = {}
  for i = 1, max_count do
    if (i > line_count) then
      if (line_count > 0) then
        table.insert(out, {kind = "removed", lnum = line_count})
      else
      end
    elseif (i > idx_count) then
      table.insert(out, {kind = "added", lnum = i})
    else
      local src_idx = idxs[i]
      local baseline = ref_baseline_line(session, src_idx)
      local shown = (lines[i] or "")
      if (shown ~= baseline) then
        table.insert(out, {kind = "modified", lnum = i})
      else
      end
    end
  end
  return out
end
M["buf-has-signs?"] = function(buf)
  local out = vim.fn.execute(("sign place group=* buffer=" .. buf))
  return (#out > 2)
end
M["clear-change-signs!"] = function(buf)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    return pcall(vim.fn.sign_unplace, change_sign_group, {buffer = buf})
  else
    return nil
  end
end
M["refresh-change-signs!"] = function(session)
  local meta = (session and session.meta)
  local buf = (meta and meta.buf and meta.buf.buffer)
  if (buf and vim.api.nvim_buf_is_valid(buf) and not bvar(buf, "meta_internal_render", false)) then
    ensure_change_signs_defined_21()
    M["clear-change-signs!"](buf)
    local events = diff_sign_events(session, buf)
    local id = 1
    local next_id = id
    for _, ev in ipairs(events) do
      if (ev.kind == "added") then
        place_sign_21(buf, next_id, sign_added, ev.lnum)
      elseif (ev.kind == "removed") then
        place_sign_21(buf, next_id, sign_removed, ev.lnum)
      else
        place_sign_21(buf, next_id, sign_modified, ev.lnum)
      end
      next_id = (next_id + 1)
    end
    return nil
  else
    return nil
  end
end
M["refresh-dummy"] = function(buf)
  pcall(vim.cmd, "sign define MetaDummy")
  pcall(vim.cmd, ("sign unplace 9999 buffer=" .. buf))
  return pcall(vim.cmd, ("sign place 9999 line=1 name=MetaDummy buffer=" .. buf))
end
return M
