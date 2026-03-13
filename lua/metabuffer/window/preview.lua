-- [nfnl] fnl/metabuffer/window/preview.fnl
local M = {}
local lineno_mod = require("metabuffer.window.lineno")
local source_mod = require("metabuffer.source")
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
M.new = function(opts)
  local selected_ref = opts["selected-ref"]
  local read_file_lines_cached = opts["read-file-lines-cached"]
  local is_active_session = opts["is-active-session"]
  local debug_log = opts["debug-log"]
  local source_switch_debounce_ms = opts["source-switch-debounce-ms"]
  local function target_preview_width(session)
    local p_width = vim.api.nvim_win_get_width(session["prompt-win"])
    return math.max(24, math.min(128, math.floor((p_width * 0.58))))
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
  local function apply_preview_window_opts_21(win)
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
      return pcall(vim.api.nvim_set_option_value, "winhighlight", "NormalFloat:Normal,Normal:Normal,NormalNC:Normal,CursorLine:CursorLine,SignColumn:SignColumn,FloatBorder:Normal", {win = win})
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
        local function _5_()
          vim.cmd("rightbelow vsplit")
          return vim.api.nvim_get_current_win()
        end
        win_id = vim.api.nvim_win_call(session["prompt-win"], _5_)
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
      return apply_preview_window_opts_21(session["preview-win"])
    else
      return nil
    end
  end
  local function close_preview_window_21(session)
    if (session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
      pcall(vim.api.nvim_win_close, session["preview-win"], true)
    else
    end
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
    local p_height = vim.api.nvim_win_get_height(session["prompt-win"])
    local width = target_preview_width(session)
    local preview_data = source_mod["preview-lines"](session, ref, p_height, read_file_lines_cached)
    local ft = source_mod["preview-filetype"](ref)
    local lines = (preview_data.lines or trim_or_pad_lines({}, p_height))
    local src_lnum = math.max(1, (preview_data["focus-lnum"] or (ref and (ref["preview-lnum"] or ref.lnum)) or 1))
    local start_lnum
    local or_9_ = preview_data["start-lnum"]
    if not or_9_ then
      if ref then
        or_9_ = (src_lnum - 1)
      else
        or_9_ = 1
      end
    end
    start_lnum = math.max(1, or_9_)
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
      return pcall(vim.api.nvim_win_set_width, session["preview-win"], width)
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
      local digit_width = lineno_mod["digit-width-from-max-value"](stop)
      local field_width = (digit_width + 1)
      local focus_row = math.max(1, (ctx["focus-row"] or 1))
      local focus_line = (ctx.lines[focus_row] or "")
      local indent = leading_indent_width(focus_line)
      local target_leftcol = math.max(0, (field_width + math.max(0, (indent - 2))))
      local rendered = {}
      local highlights = {}
      for i, line in ipairs(ctx.lines) do
        local lnum_cell = lineno_mod["lnum-cell"]((start + i + -1), digit_width)
        local text = (lnum_cell .. (line or ""))
        table.insert(rendered, text)
        table.insert(highlights, {(i - 1), "LineNr", 0, #lnum_cell})
      end
      vim.api.nvim_buf_set_lines(session["preview-buf"], 0, -1, false, rendered)
      pcall(vim.api.nvim_set_option_value, "numberwidth", field_width, {win = session["preview-win"]})
      local ns = (session["preview-hl-ns"] or vim.api.nvim_create_namespace("metabuffer.preview"))
      session["preview-hl-ns"] = ns
      vim.api.nvim_buf_clear_namespace(session["preview-buf"], ns, 0, -1)
      for _, h in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(session["preview-buf"], ns, h[2], h[1], h[3], h[4])
      end
      pcall(vim.api.nvim_win_set_cursor, session["preview-win"], {ctx["focus-row"], 0})
      pcall(vim.fn.winrestview, {leftcol = target_leftcol})
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
        apply_preview_window_opts_21(session["preview-win"])
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
      local function _22_()
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
      return timer.start(timer, math.max(0, (wait_ms or 0)), 0, vim.schedule_wrap(_22_))
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
  return {["close-window!"] = close_preview_window_21, ["maybe-update-for-selection!"] = maybe_update_preview_for_selection_21, ["cancel-update!"] = cancel_preview_update_21}
end
return M
