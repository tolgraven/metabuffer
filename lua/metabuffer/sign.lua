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
local function current_lines(buf)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  else
    return {}
  end
end
local function place_sign_21(buf, id, name, lnum)
  if (buf and vim.api.nvim_buf_is_valid(buf) and (lnum > 0)) then
    return pcall(vim.fn.sign_place, id, change_sign_group, name, buf, {lnum = lnum, priority = 20})
  else
    return nil
  end
end
local function snapshot_rows(session)
  local meta = (session and session.meta)
  local idxs = ((meta and meta.buf and meta.buf.indices) or {})
  local refs = ((meta and meta.buf and meta.buf["source-refs"]) or {})
  local content = ((meta and meta.buf and meta.buf.content) or {})
  local rows = {}
  for _, src_idx in ipairs(idxs) do
    local ref = (src_idx and refs[src_idx])
    table.insert(rows, {["src-idx"] = src_idx, kind = ((ref and ref.kind) or ""), path = ((ref and ref.path) or ""), lnum = (ref and ref.lnum), text = ((ref and ref.line) or (src_idx and content[src_idx]) or "")})
  end
  return rows
end
local function hunk_indices(h)
  local a_start = (h[1] or 1)
  local a_count = (h[2] or 0)
  local b_start = (h[3] or 1)
  local b_count = (h[4] or 0)
  return {a_start, a_count, b_start, b_count}
end
local function diff_hunks(old_lines, new_lines)
  local old_text = table.concat((old_lines or {}), "\n")
  local new_text = table.concat((new_lines or {}), "\n")
  local ok,out = pcall(vim.diff, old_text, new_text, {result_type = "indices", algorithm = "histogram"})
  if (ok and (type(out) == "table")) then
    return out
  else
    return {}
  end
end
local function place_hunk_signs_21(buf, line_count, id_start, h)
  local _let_5_ = hunk_indices(h)
  local _a_start = _let_5_[1]
  local a_count = _let_5_[2]
  local b_start = _let_5_[3]
  local b_count = _let_5_[4]
  local common = math.min(a_count, b_count)
  local next_id = id_start
  for i = 0, (common - 1) do
    place_sign_21(buf, next_id, sign_modified, (b_start + i))
    next_id = (next_id + 1)
  end
  if (b_count > a_count) then
    for i = common, (b_count - 1) do
      place_sign_21(buf, next_id, sign_added, (b_start + i))
      next_id = (next_id + 1)
    end
  else
  end
  if (a_count > b_count) then
    local row = math.max(1, math.min(math.max(1, line_count), (b_start + common)))
    place_sign_21(buf, next_id, sign_removed, row)
    next_id = (next_id + 1)
  else
  end
  return next_id
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
    local manual_edit_3f = bvar(buf, "meta_manual_edit_active", false)
    if not manual_edit_3f then
      return M["clear-change-signs!"](buf)
    else
      ensure_change_signs_defined_21()
      M["clear-change-signs!"](buf)
      local old_lines = (session["edit-baseline-lines"] or {})
      local new_lines = current_lines(buf)
      local hunks = diff_hunks(old_lines, new_lines)
      local next_id = 1
      for _, h in ipairs(hunks) do
        next_id = place_hunk_signs_21(buf, #new_lines, next_id, h)
      end
      return nil
    end
  else
    return nil
  end
end
M["capture-baseline!"] = function(session)
  local meta = (session and session.meta)
  local buf = (meta and meta.buf and meta.buf.buffer)
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    session["edit-baseline-lines"] = vim.deepcopy(current_lines(buf))
    session["edit-baseline-rows"] = snapshot_rows(session)
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
