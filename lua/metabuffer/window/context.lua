-- [nfnl] fnl/metabuffer/window/context.fnl
local expand_mod = require("metabuffer.context.expand")
local path_hl = require("metabuffer.path_highlight")
local M = {}
local function statusline_text(mode, total, shown)
  return ("%#StatusLine# Context " .. "%#MetaStatuslinePathFile#" .. string.upper((mode or "")) .. "%#StatusLine# " .. tostring(shown) .. "/" .. tostring(total) .. " ")
end
local function line_prefix(lnum)
  return string.format("%4d ", (lnum or 1))
end
local function render_block(block)
  local path = vim.fn.fnamemodify((block.path or ""), ":~:.")
  local header = (path .. ":" .. tostring(block["start-lnum"]) .. "-" .. tostring(block["end-lnum"]))
  local out = {{text = header, kind = "header", block = block}}
  for idx, line in ipairs((block.lines or {})) do
    local lnum = (block["start-lnum"] + idx + -1)
    table.insert(out, {text = (line_prefix(lnum) .. (line or "")), kind = "line", block = block, lnum = lnum})
  end
  return out
end
local function flatten_blocks(blocks)
  local out = {}
  for _, block in ipairs((blocks or {})) do
    for _0, line in ipairs(render_block(block)) do
      table.insert(out, line)
    end
    table.insert(out, {text = "", kind = "spacer"})
  end
  return out
end
local function apply_highlights_21(buf, ns, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for row, item in ipairs((lines or {})) do
    local row0 = (row - 1)
    local text = (item.text or "")
    if (item.kind == "header") then
      local prefix = line_prefix(item.block["start-lnum"])
      local prefix_len = 0
      local parts = vim.fn.fnamemodify((item.block.path or ""), ":~:.")
      local dir
      do
        local d = vim.fn.fnamemodify(parts, ":h")
        if ((d == ".") or (d == "")) then
          dir = ""
        else
          dir = (d .. "/")
        end
      end
      local file = vim.fn.fnamemodify(parts, ":t")
      local dir_ranges = path_hl["ranges-for-dir"](dir, 0)
      local file_start = #dir
      for _, dr in ipairs(dir_ranges) do
        vim.api.nvim_buf_add_highlight(buf, ns, dr.hl, row0, dr.start, dr["end"])
      end
      if (#file > 0) then
        vim.api.nvim_buf_add_highlight(buf, ns, "MetaSourceFile", row0, file_start, (file_start + #file))
      else
      end
    elseif (item.kind == "line") then
      vim.api.nvim_buf_add_highlight(buf, ns, "MetaSourceLineNr", row0, 0, 5)
    else
    end
  end
  return nil
end
local function ensure_window_21(session, height)
  if not (session["context-win"] and vim.api.nvim_win_is_valid(session["context-win"])) then
    local buf
    if (session["context-buf"] and vim.api.nvim_buf_is_valid(session["context-buf"])) then
      buf = session["context-buf"]
    else
      buf = vim.api.nvim_create_buf(false, true)
    end
    local win_id
    local function _5_()
      vim.cmd("belowright split")
      return vim.api.nvim_get_current_win()
    end
    win_id = vim.api.nvim_win_call(session.meta.win.window, _5_)
    session["context-buf"] = buf
    session["context-win"] = win_id
    pcall(vim.api.nvim_win_set_buf, win_id, buf)
    pcall(vim.api.nvim_win_set_height, win_id, height)
    do
      local bo = vim.bo[buf]
      bo["bufhidden"] = "hide"
      bo["buftype"] = "nofile"
      bo["swapfile"] = false
      bo["modifiable"] = false
      bo["filetype"] = "metabuffer"
    end
    pcall(vim.api.nvim_set_option_value, "number", false, {win = win_id})
    pcall(vim.api.nvim_set_option_value, "relativenumber", false, {win = win_id})
    pcall(vim.api.nvim_set_option_value, "wrap", false, {win = win_id})
    pcall(vim.api.nvim_set_option_value, "cursorline", true, {win = win_id})
    pcall(vim.api.nvim_set_option_value, "signcolumn", "no", {win = win_id})
    return pcall(vim.api.nvim_set_option_value, "statusline", "%#StatusLine# Context ", {win = win_id})
  else
    return nil
  end
end
local function close_window_21(session)
  if (session["context-win"] and vim.api.nvim_win_is_valid(session["context-win"])) then
    pcall(vim.api.nvim_win_close, session["context-win"], true)
  else
  end
  session["context-win"] = nil
  session["context-buf"] = nil
  return nil
end
local function visible_hit_refs(session)
  local meta = session.meta
  local refs = (meta.buf["source-refs"] or {})
  local idxs = (meta.buf.indices or {})
  local out = {}
  for _, idx in ipairs(idxs) do
    local ref = refs[idx]
    if (ref and ((ref.kind or "") ~= "file-entry")) then
      table.insert(out, ref)
    else
    end
  end
  return out
end
M.new = function(opts)
  local read_file_lines_cached = opts["read-file-lines-cached"]
  local height_fn = opts["height-fn"]
  local max_blocks = opts["max-blocks"]
  local around_lines = opts["around-lines"]
  local ns = vim.api.nvim_create_namespace("metabuffer_context")
  local function _9_(session)
    local mode = expand_mod["normalized-mode"]((session["expansion-mode"] or "none"))
    if (session["ui-hidden"] or (mode == "none")) then
      return close_window_21(session)
    else
      local refs = visible_hit_refs(session)
      local blocks = expand_mod["context-blocks"](session, refs, {mode = mode, ["read-file-lines-cached"] = read_file_lines_cached, ["around-lines"] = around_lines, ["max-blocks"] = max_blocks})
      local rendered = flatten_blocks(blocks)
      local lines
      do
        local out = {}
        for _, item in ipairs(rendered) do
          table.insert(out, (item.text or ""))
        end
        lines = out
      end
      if (#blocks == 0) then
        return close_window_21(session)
      else
        ensure_window_21(session, height_fn(session))
        if (session["context-buf"] and vim.api.nvim_buf_is_valid(session["context-buf"])) then
          do
            local bo = vim.bo[session["context-buf"]]
            bo["modifiable"] = true
          end
          vim.api.nvim_buf_set_lines(session["context-buf"], 0, -1, false, lines)
          do
            local bo = vim.bo[session["context-buf"]]
            bo["modifiable"] = false
          end
          apply_highlights_21(session["context-buf"], ns, rendered)
          return pcall(vim.api.nvim_set_option_value, "statusline", statusline_text(mode, #refs, #blocks), {win = session["context-win"]})
        else
          return nil
        end
      end
    end
  end
  return {["update!"] = _9_, ["close-window!"] = close_window_21}
end
return M
