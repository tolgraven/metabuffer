-- [nfnl] fnl/metabuffer/window/preview.fnl
local M = {}
local source_mod = require("metabuffer.source")
local lineno_mod = require("metabuffer.window.lineno")
local statusline_mod = require("metabuffer.window.statusline")
local function trim_or_pad_lines(lines, target)
  local out = {}
  for _, line in ipairs((lines or {})) do
    if (#out < target) then
      table.insert(out, (line or ""))
    else
    end
  end
  while (#out < target) do
    table.insert(out, "")
  end
  return out
end
local function leading_indent_width(line)
  local txt = (line or "")
  local ws = (string.match(txt, "^(%s*)") or "")
  return vim.fn.strdisplaywidth(ws)
end
local function preview_statusline_text_for_path(path)
  return statusline_mod["render-path"](path, {["default-text"] = "Preview", ["file-group"] = "MetaStatuslinePathFile"})
end
M.new = function(opts)
  local selected_ref = opts["selected-ref"]
  local read_file_lines_cached = opts["read-file-lines-cached"]
  local is_active_session = opts["is-active-session"]
  local debug_log = opts["debug-log"]
  local source_switch_debounce_ms = opts["source-switch-debounce-ms"]
  local function target_preview_width(session)
    local anchor_win
    if (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
      anchor_win = session.meta.win.window
    else
      anchor_win = session["prompt-win"]
    end
    local total_width = vim.api.nvim_win_get_width(anchor_win)
    return math.max(36, math.min(220, math.floor((total_width * 0.58))))
  end
  local function selected_preview_ref(session)
    return (session and session.meta and selected_ref(session.meta))
  end
  local function refresh_preview_statusline_21(session)
    if (session and session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
      local ref = selected_preview_ref(session)
      local path = (ref and ref.path)
      local text = preview_statusline_text_for_path(path)
      session["preview-statusline-text"] = text
      return pcall(vim.api.nvim_set_option_value, "statusline", text, {win = session["preview-win"]})
    else
      return nil
    end
  end
  local function ensure_preview_statusline_autocmds_21(session)
    if (session and session["preview-buf"] and vim.api.nvim_buf_is_valid(session["preview-buf"]) and not session["preview-statusline-aug"]) then
      local aug_name = ("metabuffer.preview.statusline." .. tostring(session["preview-buf"]))
      local aug = vim.api.nvim_create_augroup(aug_name, {clear = true})
      session["preview-statusline-aug"] = aug
      local function _4_(_)
        local function _5_()
          if (is_active_session(session) and session["preview-buf"] and vim.api.nvim_buf_is_valid(session["preview-buf"])) then
            return refresh_preview_statusline_21(session)
          else
            return nil
          end
        end
        return vim.schedule(_5_)
      end
      return vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {group = aug, buffer = session["preview-buf"], callback = _4_})
    else
      return nil
    end
  end
  local function mark_preview_buffer_21(buf)
    if (buf and vim.api.nvim_buf_is_valid(buf)) then
      pcall(vim.api.nvim_buf_set_var, buf, "conjure_disable", true)
      pcall(vim.api.nvim_buf_set_var, buf, "lsp_disabled", 1)
      pcall(vim.api.nvim_buf_set_var, buf, "gitgutter_enabled", 0)
      pcall(vim.api.nvim_buf_set_var, buf, "gitsigns_disable", true)
      pcall(vim.api.nvim_buf_set_var, buf, "meta_preview", true)
      return pcall(vim.diagnostic.enable, false, {bufnr = buf})
    else
      return nil
    end
  end
  local function apply_preview_window_opts_21(session, win)
    if (win and vim.api.nvim_win_is_valid(win)) then
      pcall(vim.api.nvim_set_option_value, "number", false, {win = win})
      pcall(vim.api.nvim_set_option_value, "relativenumber", false, {win = win})
      pcall(vim.api.nvim_set_option_value, "wrap", false, {win = win})
      pcall(vim.api.nvim_set_option_value, "linebreak", false, {win = win})
      pcall(vim.api.nvim_set_option_value, "signcolumn", "no", {win = win})
      pcall(vim.api.nvim_set_option_value, "foldcolumn", "0", {win = win})
      pcall(vim.api.nvim_set_option_value, "statuscolumn", "", {win = win})
      pcall(vim.api.nvim_set_option_value, "spell", false, {win = win})
      pcall(vim.api.nvim_set_option_value, "cursorline", true, {win = win})
      pcall(vim.api.nvim_set_option_value, "winblend", 0, {win = win})
      pcall(vim.api.nvim_set_option_value, "winhighlight", "NormalFloat:Normal,Normal:Normal,NormalNC:Normal,CursorLine:CursorLine,SignColumn:SignColumn,FloatBorder:Normal,StatusLine:Normal,StatusLineNC:Normal", {win = win})
      if (session and (type(session["preview-statusline-text"]) == "string")) then
        return pcall(vim.api.nvim_set_option_value, "statusline", session["preview-statusline-text"], {win = win})
      else
        return nil
      end
    else
      return nil
    end
  end
  local function ensure_preview_window_21(session)
    if not (session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
      do
        local buf
        if (session["preview-buf"] and vim.api.nvim_buf_is_valid(session["preview-buf"])) then
          buf = session["preview-buf"]
        else
          buf = vim.api.nvim_create_buf(false, true)
        end
        local width = target_preview_width(session)
        local win_id
        local function _12_()
          vim.cmd("rightbelow vsplit")
          return vim.api.nvim_get_current_win()
        end
        win_id = vim.api.nvim_win_call(session["prompt-win"], _12_)
        session["preview-buf"] = buf
        session["preview-win"] = win_id
        session["preview-layout"] = nil
        session["preview-last-path"] = nil
        pcall(vim.api.nvim_win_set_buf, win_id, buf)
        pcall(vim.api.nvim_win_set_width, win_id, width)
        do
          local bo = vim.bo[buf]
          bo["bufhidden"] = "hide"
          bo["buftype"] = "nofile"
          bo["swapfile"] = false
          bo["modifiable"] = false
          bo["filetype"] = "text"
        end
        do
          local wo = vim.wo[win_id]
          wo["number"] = false
          wo["relativenumber"] = false
          wo["wrap"] = false
          wo["linebreak"] = false
          wo["cursorline"] = true
          wo["signcolumn"] = "no"
        end
        mark_preview_buffer_21(buf)
      end
      ensure_preview_statusline_autocmds_21(session)
      return apply_preview_window_opts_21(session, session["preview-win"])
    else
      return nil
    end
  end
  local function close_preview_window_21(session)
    if (session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
      pcall(vim.api.nvim_win_close, session["preview-win"], true)
    else
    end
    if session["preview-statusline-aug"] then
      pcall(vim.api.nvim_del_augroup_by_id, session["preview-statusline-aug"])
    else
    end
    session["preview-statusline-aug"] = nil
    session["preview-win"] = nil
    session["preview-buf"] = nil
    return nil
  end
  local function ensure_preview_scratch_buf_21(session)
    if (not session["preview-buf"] or not vim.api.nvim_buf_is_valid(session["preview-buf"])) then
      session["preview-buf"] = vim.api.nvim_create_buf(false, true)
      do
        local bo = vim.bo[session["preview-buf"]]
        bo["bufhidden"] = "hide"
        bo["buftype"] = "nofile"
        bo["swapfile"] = false
        bo["modifiable"] = false
        bo["filetype"] = "text"
      end
      return mark_preview_buffer_21(session["preview-buf"])
    else
      return nil
    end
  end
  local function preview_context(session)
    local ref = selected_ref(session.meta)
    local p_height
    if (session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
      p_height = vim.api.nvim_win_get_height(session["preview-win"])
    else
      p_height = vim.api.nvim_win_get_height(session.meta.win.window)
    end
    local width = target_preview_width(session)
    local preview_data = source_mod["preview-lines"](session, ref, p_height, read_file_lines_cached)
    local ft = source_mod["preview-filetype"](ref)
    local lines = (preview_data.lines or trim_or_pad_lines({}, p_height))
    local src_lnum = math.max(1, (preview_data["focus-lnum"] or (ref and (ref["preview-lnum"] or ref.lnum)) or 1))
    local start_lnum
    local or_18_ = preview_data["start-lnum"]
    if not or_18_ then
      if ref then
        or_18_ = (src_lnum - 1)
      else
        or_18_ = 1
      end
    end
    start_lnum = math.max(1, or_18_)
    local focus_row
    if ref then
      local row = ((src_lnum - start_lnum) + 1)
      focus_row = math.max(1, math.min(row, p_height))
    else
      focus_row = 1
    end
    return {ref = ref, ["p-height"] = p_height, width = width, ft = ft, lines = lines, ["start-lnum"] = start_lnum, ["focus-row"] = focus_row}
  end
  local function ensure_preview_width_21(session, ctx)
    local width = ctx.width
    if (session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
      if (width ~= (session["preview-width"] or 0)) then
        session["preview-width"] = width
        return pcall(vim.api.nvim_win_set_width, session["preview-win"], width)
      else
        return nil
      end
    else
      return nil
    end
  end
  local function render_preview_scratch_21(session, ctx)
    if (vim.api.nvim_win_get_buf(session["preview-win"]) ~= session["preview-buf"]) then
      pcall(vim.api.nvim_win_set_buf, session["preview-win"], session["preview-buf"])
    else
    end
    do
      local bo = vim.bo[session["preview-buf"]]
      bo["modifiable"] = true
    end
    do
      local start = (ctx["start-lnum"] or 1)
      local stop = (start + math.max(0, (#ctx.lines - 1)))
      local digit_width = math.max(2, #tostring(math.max(1, stop)))
      local field_width = (digit_width + 1)
      local focus_row = math.max(1, (ctx["focus-row"] or 1))
      local focus_line = (ctx.lines[focus_row] or "")
      local indent = leading_indent_width(focus_line)
      local base_target = math.max(0, ((field_width + indent) - 8))
      local target_leftcol = math.max(0, math.min(base_target, math.max(0, (field_width - 1))))
      local rendered = {}
      for i, line in ipairs(ctx.lines) do
        local lnum = (start + (i - 1))
        local lnum_cell = lineno_mod["lnum-cell"](lnum, digit_width)
        table.insert(rendered, (lnum_cell .. (line or "")))
      end
      vim.api.nvim_buf_set_lines(session["preview-buf"], 0, -1, false, rendered)
      local ns = (session["preview-hl-ns"] or vim.api.nvim_create_namespace("metabuffer.preview"))
      session["preview-hl-ns"] = ns
      vim.api.nvim_buf_clear_namespace(session["preview-buf"], ns, 0, -1)
      for row, _ in ipairs(rendered) do
        pcall(vim.api.nvim_buf_add_highlight, session["preview-buf"], ns, "LineNr", (row - 1), 0, field_width)
      end
      pcall(vim.api.nvim_win_set_cursor, session["preview-win"], {ctx["focus-row"], 0})
      local function _24_()
        return vim.fn.winrestview({leftcol = target_leftcol})
      end
      pcall(vim.api.nvim_win_call, session["preview-win"], _24_)
    end
    local bo = vim.bo[session["preview-buf"]]
    local ft = ctx.ft
    bo["modifiable"] = false
    local next_ft
    if ((type(ft) == "string") and (ft ~= "")) then
      next_ft = ft
    else
      next_ft = "text"
    end
    if (bo.filetype ~= next_ft) then
      bo["filetype"] = next_ft
      return nil
    else
      return nil
    end
  end
  local function update_preview_window_21(session)
    ensure_preview_window_21(session)
    if (session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
      ensure_preview_scratch_buf_21(session)
      if (session["preview-buf"] and vim.api.nvim_buf_is_valid(session["preview-buf"])) then
        local ctx = preview_context(session)
        debug_log(("preview idx=" .. tostring(session.meta.selected_index) .. " path=" .. tostring((ctx.ref and ctx.ref.path)) .. " lnum=" .. tostring((ctx.ref and ctx.ref.lnum))))
        ensure_preview_width_21(session, ctx)
        apply_preview_window_opts_21(session, session["preview-win"])
        refresh_preview_statusline_21(session)
        render_preview_scratch_21(session, ctx)
        session["preview-last-path"] = (ctx.ref and ctx.ref.path)
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  local function selected_preview_path(session)
    local ref = (session and session.meta and selected_ref(session.meta))
    return ((ref and ref.path) or "")
  end
  local function cancel_preview_update_21(session)
    if session then
      session["preview-update-token"] = (1 + (session["preview-update-token"] or 0))
      if session["preview-update-timer"] then
        local timer = session["preview-update-timer"]
        local stopf = timer.stop
        local closef = timer.close
        if stopf then
          pcall(stopf, timer)
        else
        end
        if closef then
          pcall(closef, timer)
        else
        end
        session["preview-update-timer"] = nil
      else
      end
      session["preview-update-pending"] = false
      return nil
    else
      return nil
    end
  end
  local function schedule_preview_update_21(session, wait_ms)
    if session then
      cancel_preview_update_21(session)
      session["preview-update-pending"] = true
      session["preview-update-token"] = (1 + (session["preview-update-token"] or 0))
      local token = session["preview-update-token"]
      local target_path = selected_preview_path(session)
      local timer = vim.loop.new_timer()
      session["preview-update-timer"] = timer
      local function _33_()
        if (session["preview-update-timer"] and (session["preview-update-timer"] == timer)) then
          local stopf = timer.stop
          local closef = timer.close
          if stopf then
            pcall(stopf, timer)
          else
          end
          if closef then
            pcall(closef, timer)
          else
          end
          session["preview-update-timer"] = nil
          session["preview-update-pending"] = false
        else
        end
        if (session and (token == session["preview-update-token"]) and is_active_session(session) and (target_path == selected_preview_path(session))) then
          return pcall(update_preview_window_21, session)
        else
          return nil
        end
      end
      return timer.start(timer, math.max(0, (wait_ms or 0)), 0, vim.schedule_wrap(_33_))
    else
      return nil
    end
  end
  local function maybe_update_preview_for_selection_21(session)
    local target_path = selected_preview_path(session)
    local shown_path = (session["preview-last-path"] or "")
    if ((shown_path ~= "") and (target_path ~= shown_path)) then
      return schedule_preview_update_21(session, source_switch_debounce_ms)
    else
      cancel_preview_update_21(session)
      return update_preview_window_21(session)
    end
  end
  return {["close-window!"] = close_preview_window_21, ["refresh-statusline!"] = refresh_preview_statusline_21, ["maybe-update-for-selection!"] = maybe_update_preview_for_selection_21, ["cancel-update!"] = cancel_preview_update_21}
end
return M
