-- [nfnl] fnl/metabuffer/window/preview.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local source_mod = require("metabuffer.source")
local statusline_mod = require("metabuffer.window.statusline")
local util = require("metabuffer.util")
local base_window_mod = require("metabuffer.window.base")
local disable_airline_statusline_21 = base_window_mod["disable-airline-statusline!"]
local metabuffer_winhighlight = base_window_mod["metabuffer-winhighlight"]
local function preview_winhighlight()
  return (metabuffer_winhighlight() .. ",StatusLine:MetaPreviewStatusline,StatusLineNC:MetaPreviewStatusline")
end
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
local function preview_statusline_text_for_path(path)
  return statusline_mod["render-path"](path, {["default-text"] = "Preview", ["base-group"] = "MetaPreviewStatusline", ["left-pad"] = "   ", ["seg-prefix"] = "MetaPreviewStatuslinePathSeg", ["sep-group"] = "MetaPreviewStatuslinePathSep", ["file-group"] = "MetaPreviewStatuslinePathFile"})
end
local function apply_ft_buffer_vars_21(buf, ft)
  if (buf and vim.api.nvim_buf_is_valid(buf) and (ft == "fennel")) then
    pcall(vim.api.nvim_buf_set_var, buf, "fennel_lua_version", "5.1")
    local function _2_()
      if _G.jit then
        return 1
      else
        return 0
      end
    end
    return pcall(vim.api.nvim_buf_set_var, buf, "fennel_use_luajit", _2_())
  else
    return nil
  end
end
local function set_window_options_21(win, opts)
  for name, value in pairs((opts or {})) do
    pcall(vim.api.nvim_set_option_value, name, value, {win = win})
  end
  return nil
end
local function set_buffer_options_21(buf, opts)
  for name, value in pairs((opts or {})) do
    vim.bo[buf][name] = value
  end
  return nil
end
local function delete_window_match_21(win, id)
  if (id and win and vim.api.nvim_win_is_valid(win)) then
    local or_4_ = pcall(vim.fn.matchdelete, id, win)
    if not or_4_ then
      local function _5_()
        return vim.fn.matchdelete(id)
      end
      or_4_ = pcall(vim.api.nvim_win_call, win, _5_)
    end
    return or_4_
  else
    return nil
  end
end
local function with_file_messages_suppressed(f)
  local prev = vim.o.shortmess
  local next
  if string.find(prev, "F", 1, true) then
    next = prev
  else
    next = (prev .. "F")
  end
  vim.o.shortmess = next
  local ok,result = pcall(f)
  vim.o.shortmess = prev
  if ok then
    return result
  else
    return error(result)
  end
end
local function wipe_replaced_split_buffer_21(old_buf)
  if (old_buf and vim.api.nvim_buf_is_valid(old_buf)) then
    return util["delete-transient-unnamed-buffer!"](old_buf)
  else
    return nil
  end
end
M.new = function(opts)
  local selected_ref = opts["selected-ref"]
  local read_file_lines_cached = opts["read-file-lines-cached"]
  local read_file_view_cached = opts["read-file-view-cached"]
  local floating_window_mod = opts["floating-window-mod"]
  local is_active_session = opts["is-active-session"]
  local debug_log = opts["debug-log"]
  local source_switch_debounce_ms = opts["source-switch-debounce-ms"]
  local target_preview_width
  local function _10_(session)
    local anchor_win
    if (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
      anchor_win = session.meta.win.window
    else
      anchor_win = session["prompt-win"]
    end
    local total_width = vim.api.nvim_win_get_width(anchor_win)
    return math.max(36, math.min(220, math.floor((total_width * 0.58))))
  end
  target_preview_width = _10_
  local selected_preview_ref
  local function _12_(session)
    return (session and session.meta and selected_ref(session.meta))
  end
  selected_preview_ref = _12_
  local preview_float_config
  local function _13_(session, width, height)
    local host_win
    if (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
      host_win = session.meta.win.window
    else
      host_win = session["prompt-win"]
    end
    return {relative = "win", win = host_win, anchor = "SE", row = 0, col = vim.api.nvim_win_get_width(host_win), width = width, height = math.max(1, (height or 1))}
  end
  preview_float_config = _13_
  local refresh_preview_statusline_21
  local function _15_(session)
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
  refresh_preview_statusline_21 = _15_
  local ensure_preview_statusline_autocmds_21
  local function _17_(session)
    if (session and session["preview-buf"] and vim.api.nvim_buf_is_valid(session["preview-buf"]) and (not session["preview-statusline-aug"] or (session["preview-statusline-buf"] ~= session["preview-buf"]))) then
      if session["preview-statusline-aug"] then
        pcall(vim.api.nvim_del_augroup_by_id, session["preview-statusline-aug"])
      else
      end
      local aug_name = ("metabuffer.preview.statusline." .. tostring(session["preview-buf"]))
      local aug = vim.api.nvim_create_augroup(aug_name, {clear = true})
      session["preview-statusline-aug"] = aug
      session["preview-statusline-buf"] = session["preview-buf"]
      local function _19_(_)
        local function _20_()
          if (is_active_session(session) and session["preview-buf"] and vim.api.nvim_buf_is_valid(session["preview-buf"])) then
            return refresh_preview_statusline_21(session)
          else
            return nil
          end
        end
        return vim.schedule(_20_)
      end
      return vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "FocusGained"}, {group = aug, buffer = session["preview-buf"], callback = _19_})
    else
      return nil
    end
  end
  ensure_preview_statusline_autocmds_21 = _17_
  local mark_preview_buffer_21
  local function _23_(buf)
    if (buf and vim.api.nvim_buf_is_valid(buf)) then
      util["disable-heavy-buffer-features!"](buf)
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
  mark_preview_buffer_21 = _23_
  local file_backed_preview_ref_3f
  local function _25_(ref)
    return (ref and ((ref.buf and vim.api.nvim_buf_is_valid(ref.buf)) or (ref.path and (1 == vim.fn.filereadable(ref.path)))))
  end
  file_backed_preview_ref_3f = _25_
  local real_preview_buffer
  local function _26_(ref)
    if (ref and ref.buf and vim.api.nvim_buf_is_valid(ref.buf)) then
      return ref.buf
    else
      local path = (ref and ref.path)
      if ((type(path) == "string") and (path ~= "") and (1 == vim.fn.filereadable(path))) then
        local buf = vim.fn.bufadd(path)
        local function _27_()
          return pcall(vim.fn.bufload, buf)
        end
        with_file_messages_suppressed(_27_)
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
  real_preview_buffer = _26_
  local apply_preview_window_opts_21
  local function _31_(session, win)
    if (win and vim.api.nvim_win_is_valid(win)) then
      disable_airline_statusline_21(win)
      local real_buffer_3f = clj.boolean(session["preview-real-buffer?"])
      local win_opts
      local _32_
      if real_buffer_3f then
        _32_ = "auto"
      else
        _32_ = "no"
      end
      local _34_
      if session["preview-float?"] then
        _34_ = ""
      else
        _34_ = (session["preview-statusline-text"] or "")
      end
      win_opts = {number = real_buffer_3f, winfixwidth = true, signcolumn = _32_, foldcolumn = "0", statuscolumn = "", cursorline = true, winblend = 0, winhighlight = preview_winhighlight(), statusline = _34_, linebreak = false, relativenumber = false, spell = false, wrap = false}
      return set_window_options_21(win, win_opts)
    else
      return nil
    end
  end
  apply_preview_window_opts_21 = _31_
  local clear_preview_focus_highlight_21
  local function _37_(session)
    if session["preview-focus-match-id"] then
      delete_window_match_21(session["preview-win"], session["preview-focus-match-id"])
      session["preview-focus-match-id"] = nil
      return nil
    else
      return nil
    end
  end
  clear_preview_focus_highlight_21 = _37_
  local apply_preview_focus_highlight_21
  local function _39_(session, lnum)
    clear_preview_focus_highlight_21(session)
    if (session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"]) and lnum and (lnum >= 1)) then
      local pat = ("\\%" .. tostring(lnum) .. "l.*")
      local ok,id = pcall(vim.fn.matchadd, "MetaWindowCursorLine", pat, 18, -1, {window = session["preview-win"]})
      if ok then
        session["preview-focus-match-id"] = id
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  apply_preview_focus_highlight_21 = _39_
  local close_preview_window_21 = nil
  local function ensure_preview_window_21(session)
    if not (session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
      local buf
      if (session["preview-scratch-buf"] and vim.api.nvim_buf_is_valid(session["preview-scratch-buf"])) then
        buf = session["preview-scratch-buf"]
      else
        buf = vim.api.nvim_create_buf(false, true)
      end
      local width = target_preview_width(session)
      local float_start_3f = clj.boolean(session["prompt-animating?"])
      local height
      if float_start_3f then
        height = 1
      else
        height = math.max(1, vim.api.nvim_win_get_height(session["prompt-win"]))
      end
      local win_id
      if float_start_3f then
        win_id = floating_window_mod.new(vim, buf, preview_float_config(session, width, height)).window
      else
        local function _44_()
          vim.cmd("rightbelow vsplit")
          return vim.api.nvim_get_current_win()
        end
        win_id = vim.api.nvim_win_call(session["prompt-win"], _44_)
      end
      session["preview-scratch-buf"] = buf
      session["preview-buf"] = buf
      session["preview-win"] = win_id
      session["preview-float?"] = float_start_3f
      session["preview-real-buffer?"] = false
      session["preview-layout"] = nil
      session["preview-last-path"] = nil
      do
        local old_buf = (not float_start_3f and win_id and vim.api.nvim_win_is_valid(win_id) and vim.api.nvim_win_get_buf(win_id))
        if old_buf then
          util["mark-transient-unnamed-buffer!"](old_buf)
        else
        end
        util["set-buffer-name!"](buf, "[Metabuffer Preview]")
        pcall(vim.api.nvim_win_set_buf, win_id, buf)
        wipe_replaced_split_buffer_21(old_buf)
      end
      if not float_start_3f then
        pcall(vim.api.nvim_win_set_width, win_id, width)
      else
      end
      set_buffer_options_21(buf, {bufhidden = "hide", buftype = "nofile", filetype = "", modifiable = false, swapfile = false})
      mark_preview_buffer_21(buf)
      ensure_preview_statusline_autocmds_21(session)
      apply_preview_window_opts_21(session, session["preview-win"])
      session["preview-animated?"] = true
      return nil
    else
      return nil
    end
  end
  local function ensure_preview_split_window_21(session)
    if session["preview-float?"] then
      close_preview_window_21(session)
      ensure_preview_window_21(session)
    else
    end
    if (session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
      session["preview-float?"] = false
      return nil
    else
      return nil
    end
  end
  local function _51_(session)
    local buf = session["preview-buf"]
    local scratch_buf = session["preview-scratch-buf"]
    if (session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
      pcall(vim.api.nvim_win_close, session["preview-win"], true)
    else
    end
    if session["preview-statusline-aug"] then
      pcall(vim.api.nvim_del_augroup_by_id, session["preview-statusline-aug"])
    else
    end
    session["preview-statusline-aug"] = nil
    session["preview-statusline-buf"] = nil
    clear_preview_focus_highlight_21(session)
    if (scratch_buf and vim.api.nvim_buf_is_valid(scratch_buf) and (true == pcall(vim.api.nvim_buf_get_var, scratch_buf, "meta_preview"))) then
      pcall(vim.api.nvim_buf_delete, scratch_buf, {force = true})
    else
    end
    if (buf and vim.api.nvim_buf_is_valid(buf) and (true == pcall(vim.api.nvim_buf_get_var, buf, "meta_preview"))) then
      pcall(vim.api.nvim_buf_delete, buf, {force = true})
    else
    end
    session["preview-win"] = nil
    session["preview-float?"] = false
    session["preview-real-buffer?"] = false
    session["preview-scratch-buf"] = nil
    session["preview-buf"] = nil
    return nil
  end
  close_preview_window_21 = _51_
  local function ensure_preview_scratch_buf_21(session)
    if (not session["preview-scratch-buf"] or not vim.api.nvim_buf_is_valid(session["preview-scratch-buf"])) then
      session["preview-scratch-buf"] = vim.api.nvim_create_buf(false, true)
      util["set-buffer-name!"](session["preview-scratch-buf"], "[Metabuffer Preview]")
      set_buffer_options_21(session["preview-scratch-buf"], {bufhidden = "hide", buftype = "nofile", filetype = "", modifiable = false, swapfile = false})
      return mark_preview_buffer_21(session["preview-scratch-buf"])
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
    local preview_data = source_mod["preview-lines"](session, ref, p_height, read_file_lines_cached, read_file_view_cached)
    local ft = source_mod["preview-filetype"](ref)
    local lines = (preview_data.lines or trim_or_pad_lines({}, p_height))
    local src_lnum = math.max(1, (preview_data["focus-lnum"] or (ref and (ref["preview-lnum"] or ref.lnum)) or 1))
    local start_lnum
    local or_58_ = preview_data["start-lnum"]
    if not or_58_ then
      if ref then
        or_58_ = (src_lnum - 1)
      else
        or_58_ = 1
      end
    end
    start_lnum = math.max(1, or_58_)
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
        if session["preview-float?"] then
          local height = math.max(1, vim.api.nvim_win_get_height(session["preview-win"]))
          return pcall(vim.api.nvim_win_set_config, session["preview-win"], preview_float_config(session, width, height))
        else
          return pcall(vim.api.nvim_win_set_width, session["preview-win"], width)
        end
      else
        return nil
      end
    else
      return nil
    end
  end
  local function render_preview_scratch_21(session, ctx)
    ensure_preview_scratch_buf_21(session)
    session["preview-real-buffer?"] = false
    session["preview-buf"] = session["preview-scratch-buf"]
    if (vim.api.nvim_win_get_buf(session["preview-win"]) ~= session["preview-buf"]) then
      pcall(vim.api.nvim_win_set_buf, session["preview-win"], session["preview-buf"])
    else
    end
    do
      local bo = vim.bo[session["preview-buf"]]
      bo["modifiable"] = true
    end
    do
      local rendered = {}
      for _, line in ipairs(ctx.lines) do
        table.insert(rendered, (line or ""))
      end
      vim.api.nvim_buf_set_lines(session["preview-buf"], 0, -1, false, rendered)
      pcall(vim.api.nvim_win_set_cursor, session["preview-win"], {ctx["focus-row"], 0})
      apply_preview_focus_highlight_21(session, ctx["focus-row"])
    end
    local bo = vim.bo[session["preview-buf"]]
    local ft = ctx.ft
    bo["modifiable"] = false
    local next_ft
    if ((type(ft) == "string") and (ft ~= "")) then
      next_ft = ft
    else
      next_ft = ""
    end
    if (next_ft ~= "") then
      apply_ft_buffer_vars_21(session["preview-buf"], next_ft)
    else
    end
    pcall(vim.api.nvim_set_option_value, "syntax", "", {buf = session["preview-buf"]})
    bo["filetype"] = next_ft
    if (next_ft ~= "") then
      return pcall(vim.api.nvim_set_option_value, "syntax", next_ft, {buf = session["preview-buf"]})
    else
      return nil
    end
  end
  local function render_preview_source_21(session, ctx)
    local ref = ctx.ref
    local buf = real_preview_buffer(ref)
    if (buf and vim.api.nvim_buf_is_valid(buf)) then
      session["preview-real-buffer?"] = true
      session["preview-buf"] = buf
      if (vim.api.nvim_win_get_buf(session["preview-win"]) ~= buf) then
        local function _68_()
          return pcall(vim.api.nvim_win_set_buf, session["preview-win"], buf)
        end
        with_file_messages_suppressed(_68_)
      else
      end
      do
        local bo = vim.bo[buf]
        bo["bufhidden"] = "hide"
      end
      local lnum = math.max(1, ((ref and (ref["preview-lnum"] or ref.lnum)) or 1))
      local topline = math.max(1, (lnum - 2))
      local function _70_()
        return pcall(vim.fn.winrestview, {lnum = lnum, topline = topline, col = 0, leftcol = 0})
      end
      pcall(vim.api.nvim_win_call, session["preview-win"], _70_)
      return apply_preview_focus_highlight_21(session, lnum)
    else
      return nil
    end
  end
  local function render_preview_placeholder_21(session)
    ensure_preview_scratch_buf_21(session)
    session["preview-real-buffer?"] = false
    session["preview-buf"] = session["preview-scratch-buf"]
    if (session["preview-buf"] and vim.api.nvim_buf_is_valid(session["preview-buf"])) then
      if (vim.api.nvim_win_get_buf(session["preview-win"]) ~= session["preview-buf"]) then
        pcall(vim.api.nvim_win_set_buf, session["preview-win"], session["preview-buf"])
      else
      end
      local bo = vim.bo[session["preview-buf"]]
      bo["modifiable"] = true
      vim.api.nvim_buf_set_lines(session["preview-buf"], 0, -1, false, {""})
      bo["modifiable"] = false
      pcall(vim.api.nvim_set_option_value, "syntax", "", {buf = session["preview-buf"]})
      bo["filetype"] = ""
    else
    end
    clear_preview_focus_highlight_21(session)
    session["preview-last-path"] = nil
    return nil
  end
  local function update_preview_window_21(session)
    ensure_preview_window_21(session)
    if (session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
      if session["prompt-animating?"] then
        apply_preview_window_opts_21(session, session["preview-win"])
        return render_preview_placeholder_21(session)
      else
        ensure_preview_split_window_21(session)
        local ctx = preview_context(session)
        debug_log(("preview idx=" .. tostring(session.meta.selected_index) .. " path=" .. tostring((ctx.ref and ctx.ref.path)) .. " lnum=" .. tostring((ctx.ref and ctx.ref.lnum))))
        ensure_preview_width_21(session, ctx)
        if file_backed_preview_ref_3f(ctx.ref) then
          render_preview_source_21(session, ctx)
        else
          render_preview_scratch_21(session, ctx)
        end
        ensure_preview_statusline_autocmds_21(session)
        apply_preview_window_opts_21(session, session["preview-win"])
        refresh_preview_statusline_21(session)
        session["preview-last-path"] = (ctx.ref and ctx.ref.path)
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
      local function _81_()
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
      return timer.start(timer, math.max(0, (wait_ms or 0)), 0, vim.schedule_wrap(_81_))
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
  return {["close-window!"] = close_preview_window_21, ["ensure-window!"] = ensure_preview_window_21, ["update!"] = update_preview_window_21, ["refresh-statusline!"] = refresh_preview_statusline_21, ["maybe-update-for-selection!"] = maybe_update_preview_for_selection_21, ["cancel-update!"] = cancel_preview_update_21}
end
return M
