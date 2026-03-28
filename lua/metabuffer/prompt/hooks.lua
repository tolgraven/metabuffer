-- [nfnl] fnl/metabuffer/prompt/hooks.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local animation_mod = require("metabuffer.window.animation")
local events = require("metabuffer.events")
local query_mod = require("metabuffer.query")
local directive_mod = require("metabuffer.query.directive")
M.new = function(opts)
  local default_prompt_keymaps = opts["default-prompt-keymaps"]
  local active_by_prompt = opts["active-by-prompt"]
  local default_main_keymaps = opts["default-main-keymaps"]
  local on_prompt_changed = opts["on-prompt-changed"]
  local update_info_window = opts["update-info-window"]
  local update_preview_window = opts["update-preview-window"]
  local maybe_sync_from_main_21 = opts["maybe-sync-from-main!"]
  local schedule_scroll_sync_21 = opts["schedule-scroll-sync!"]
  local maybe_restore_hidden_ui_21 = opts["maybe-restore-hidden-ui!"]
  local hide_visible_ui_21 = opts["hide-visible-ui!"]
  local rebuild_source_set_21 = opts["rebuild-source-set!"]
  local maybe_refresh_preview_statusline_21 = opts["maybe-refresh-preview-statusline!"]
  local maybe_refresh_info_statusline_21 = opts["maybe-refresh-info-statusline!"]
  local sign_mod = opts["sign-mod"]
  local animation_enabled_3f = animation_mod["enabled?"]
  local animation_duration_ms = animation_mod["duration-ms"]
  local function prompt_animation_delay_ms(session)
    if (animation_mod and animation_enabled_3f and animation_enabled_3f(session, "prompt")) then
      return animation_duration_ms(session, "prompt", 140)
    else
      return 0
    end
  end
  local function switch_mode(session, which)
    local meta = session.meta
    meta.switch_mode(which)
    return pcall(meta.refresh_statusline)
  end
  local function nvim_exiting_3f()
    local v = (vim.v and vim.v.exiting)
    return ((v ~= nil) and (v ~= vim.NIL) and (v ~= 0) and (v ~= ""))
  end
  local function session_prompt_valid_3f(session)
    return (not nvim_exiting_3f() and session and not session["ui-hidden"] and not session.closing and session.meta and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and (active_by_prompt[session["prompt-buf"]] == session))
  end
  local function schedule_when_valid(session, f)
    local function _2_()
      if session_prompt_valid_3f(session) then
        return f()
      else
        return nil
      end
    end
    return vim.schedule(_2_)
  end
  local function option_prefix()
    local p = vim.g["meta#prefix"]
    if ((type(p) == "string") and (p ~= "")) then
      return p
    else
      return "#"
    end
  end
  local function window_rect(win)
    if (win and (type(win) == "number") and vim.api.nvim_win_is_valid(win)) then
      local pos = vim.api.nvim_win_get_position(win)
      local row = (pos[1] or 0)
      local col = (pos[2] or 0)
      local height = vim.api.nvim_win_get_height(win)
      local width = vim.api.nvim_win_get_width(win)
      return {top = row, left = col, bottom = (row + height + -1), right = (col + width + -1)}
    else
      return nil
    end
  end
  local function rect_overlap_3f(a, b)
    return (a and b and (a.top <= b.bottom) and (b.top <= a.bottom) and (a.left <= b.right) and (b.left <= a.right))
  end
  local function meta_owned_window_3f(session, win)
    local meta_win = (session.meta and session.meta.win and session.meta.win.window)
    local prompt_win = session["prompt-win"]
    local info_win = session["info-win"]
    local preview_win = session["preview-win"]
    local history_win = session["history-browser-win"]
    return ((win == meta_win) or (win == prompt_win) or (win == info_win) or (win == preview_win) or (win == history_win))
  end
  local function covered_by_new_window_3f(session, win)
    local target = window_rect(win)
    local prompt_win = session["prompt-win"]
    local info_win = session["info-win"]
    local preview_win = session["preview-win"]
    local history_win = session["history-browser-win"]
    return (target and not meta_owned_window_3f(session, win) and (rect_overlap_3f(target, window_rect(info_win)) or rect_overlap_3f(target, window_rect(preview_win)) or rect_overlap_3f(target, window_rect(history_win)) or (session["prompt-floating?"] and rect_overlap_3f(target, window_rect(prompt_win)))))
  end
  local function transient_overlay_buffer_3f(buf)
    if (buf and (type(buf) == "number") and vim.api.nvim_buf_is_valid(buf)) then
      local bo = vim.bo[buf]
      local ft = (bo.filetype or "")
      local bt = (bo.buftype or "")
      return ((ft == "help") or (ft == "man") or (bt == "help"))
    else
      return nil
    end
  end
  local function first_window_for_buffer(buf)
    if (buf and (type(buf) == "number") and vim.api.nvim_buf_is_valid(buf)) then
      local wins = vim.fn.win_findbuf(buf)
      local found = nil
      for _, win in ipairs((wins or {})) do
        if (not found and vim.api.nvim_win_is_valid(win)) then
          found = win
        else
        end
      end
      return found
    else
      return nil
    end
  end
  local function tab_window_count(win)
    if (win and (type(win) == "number") and vim.api.nvim_win_is_valid(win)) then
      local ok,tab = pcall(vim.api.nvim_win_get_tabpage, win)
      if (ok and tab) then
        local ok2,wins = pcall(vim.api.nvim_tabpage_list_wins, tab)
        if (ok2 and (type(wins) == "table")) then
          return #wins
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
  local function layout_snapshot(session)
    local main_win = (session.meta and session.meta.win and session.meta.win.window)
    local prompt_win = session["prompt-win"]
    local preview_win = session["preview-win"]
    if (main_win and prompt_win and preview_win and vim.api.nvim_win_is_valid(main_win) and vim.api.nvim_win_is_valid(prompt_win) and vim.api.nvim_win_is_valid(preview_win)) then
      return {["main-height"] = vim.api.nvim_win_get_height(main_win), ["prompt-height"] = vim.api.nvim_win_get_height(prompt_win), ["preview-height"] = vim.api.nvim_win_get_height(preview_win), ["tab-window-count"] = tab_window_count(main_win)}
    else
      return nil
    end
  end
  local function capture_expected_layout_21(session)
    if (session and not session.closing and not session["ui-hidden"] and not session["prompt-floating?"] and not session["prompt-animating?"]) then
      local val_110_auto = layout_snapshot(session)
      if val_110_auto then
        local snap = val_110_auto
        session["expected-layout"] = snap
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  local function expected_layout_mismatch_3f(session)
    local val_111_auto = session["expected-layout"]
    if val_111_auto then
      local expected = val_111_auto
      local val_111_auto0 = layout_snapshot(session)
      if val_111_auto0 then
        local current = val_111_auto0
        return ((current["main-height"] ~= expected["main-height"]) or (current["prompt-height"] ~= expected["prompt-height"]) or (current["preview-height"] ~= expected["preview-height"]))
      else
        return false
      end
    else
      return false
    end
  end
  local function manual_prompt_resize_3f(session, resized_wins)
    local val_111_auto = session["expected-layout"]
    if val_111_auto then
      local expected = val_111_auto
      local prompt_win = session["prompt-win"]
      local prompt_valid_3f = (prompt_win and vim.api.nvim_win_is_valid(prompt_win))
      local tab_count = (session.meta and session.meta.win and session.meta.win.window and tab_window_count(session.meta.win.window))
      local prompt_height = (prompt_valid_3f and vim.api.nvim_win_get_height(prompt_win))
      local prompt_hit_3f = false
      local hit = prompt_hit_3f
      for _, wid in ipairs((resized_wins or {})) do
        if (wid == prompt_win) then
          hit = true
        else
        end
      end
      return (prompt_valid_3f and hit and (tab_count == expected["tab-window-count"]) and (prompt_height ~= expected["prompt-height"]))
    else
      return false
    end
  end
  local function restore_expected_layout_21(session)
    local val_110_auto = session["expected-layout"]
    if val_110_auto then
      local expected = val_110_auto
      local main_win = (session.meta and session.meta.win and session.meta.win.window)
      local prompt_win = session["prompt-win"]
      local preview_win = session["preview-win"]
      if (main_win and prompt_win and preview_win and vim.api.nvim_win_is_valid(main_win) and vim.api.nvim_win_is_valid(prompt_win) and vim.api.nvim_win_is_valid(preview_win)) then
        session["handling-layout-change?"] = true
        pcall(vim.api.nvim_win_set_height, main_win, math.max(1, (expected["main-height"] or 1)))
        pcall(vim.api.nvim_win_set_height, prompt_win, math.max(1, (expected["prompt-height"] or 1)))
        pcall(vim.api.nvim_win_set_height, preview_win, math.max(1, (expected["preview-height"] or 1)))
        session["handling-layout-change?"] = false
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  local function schedule_restore_expected_layout_21(session)
    if session["expected-layout"] then
      session["layout-restore-token"] = (1 + (session["layout-restore-token"] or 0))
      local token = session["layout-restore-token"]
      local function _21_()
        if (session_prompt_valid_3f(session) and (token == session["layout-restore-token"]) and session["expected-layout"]) then
          local main_win = (session.meta and session.meta.win and session.meta.win.window)
          local current_count = (main_win and tab_window_count(main_win))
          local expected_count = session["expected-layout"]["tab-window-count"]
          if ((current_count == expected_count) and expected_layout_mismatch_3f(session)) then
            return restore_expected_layout_21(session)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_21_, 80)
    else
      return nil
    end
  end
  local function hidden_session_reachable_3f(session)
    local results_buf = (session and session.meta and session.meta.buf and session.meta.buf.buffer)
    if not (results_buf and vim.api.nvim_buf_is_valid(results_buf)) then
      return false
    else
      if (vim.api.nvim_get_current_buf() == results_buf) then
        return true
      else
        local raw = vim.fn.getjumplist()
        local jumps
        if ((type(raw) == "table") and (type(raw[1]) == "table")) then
          jumps = raw[1]
        else
          jumps = {}
        end
        local hit0 = false
        local hit = hit0
        for _, item in ipairs((jumps or {})) do
          if ((item.bufnr or item.bufnr) == results_buf) then
            hit = true
          else
          end
        end
        return hit
      end
    end
  end
  local function control_token_style(tok)
    local token = (tok or "")
    local prefix = option_prefix()
    local escaped_prefix_3f = (vim.startswith(token, "\\") and vim.startswith(string.sub(token, 2), prefix))
    local parsed = (not escaped_prefix_3f and directive_mod["parse-token"](prefix, token))
    local off_3f = (parsed and (parsed.value == false))
    local provider_type = ((parsed and parsed["provider-type"]) or "")
    local functional_3f = ((provider_type == "transform") or (((parsed and parsed["token-key"]) or "") == "prefilter") or (((parsed and parsed["token-key"]) or "") == "lazy") or (((parsed and parsed["token-key"]) or "") == "escape"))
    local matches_3f = clj.boolean(parsed)
    if (escaped_prefix_3f or not matches_3f) then
      return nil
    else
      local _29_
      if off_3f then
        _29_ = "MetaPromptFlagHashOff"
      else
        _29_ = "MetaPromptFlagHashOn"
      end
      local _31_
      if functional_3f then
        if off_3f then
          _31_ = "MetaPromptFlagTextFuncOff"
        else
          _31_ = "MetaPromptFlagTextFuncOn"
        end
      else
        if off_3f then
          _31_ = "MetaPromptFlagTextOff"
        else
          _31_ = "MetaPromptFlagTextOn"
        end
      end
      return {["hash-hl"] = _29_, ["text-hl"] = _31_}
    end
  end
  local function session_busy_3f(session)
    return (session and (session["prompt-update-pending"] or session["prompt-update-dirty"] or session["lazy-refresh-pending"] or session["lazy-refresh-dirty"] or session["project-bootstrap-pending"] or (session["project-mode"] and not session["project-bootstrapped"])))
  end
  local function session_actually_idle_3f(session)
    return (session and not session_busy_3f(session) and not session["prompt-update-dirty"] and not session["lazy-refresh-dirty"])
  end
  local function hl_rendered_fg(hl)
    if (hl and hl.reverse) then
      return (hl.bg or hl.fg)
    else
      return hl.fg
    end
  end
  local function hl_rendered_bg(hl)
    if (hl and hl.reverse) then
      return (hl.fg or hl.bg)
    else
      return hl.bg
    end
  end
  local function darken_rgb(n, factor)
    if not n then
      return nil
    else
      local r = math.floor((n / 65536))
      local g = math.floor(((n / 256) % 256))
      local b = (n % 256)
      local f = math.max(0, math.min(factor, 1))
      local dr = math.max(0, math.min(255, math.floor((r * (1 - f)))))
      local dg = math.max(0, math.min(255, math.floor((g * (1 - f)))))
      local db = math.max(0, math.min(255, math.floor((b * (1 - f)))))
      return ((dr * 65536) + (dg * 256) + db)
    end
  end
  local function brighten_rgb(n, factor)
    if not n then
      return nil
    else
      local r = math.floor((n / 65536))
      local g = math.floor(((n / 256) % 256))
      local b = (n % 256)
      local f = math.max(0, math.min(factor, 1))
      local br = math.max(0, math.min(255, math.floor((r + ((255 - r) * f)))))
      local bg = math.max(0, math.min(255, math.floor((g + ((255 - g) * f)))))
      local bb = math.max(0, math.min(255, math.floor((b + ((255 - b) * f)))))
      return ((br * 65536) + (bg * 256) + bb)
    end
  end
  local function results_pulse_bg(step)
    local ok_middle,middle = pcall(vim.api.nvim_get_hl, 0, {name = "MetaStatuslineMiddle", link = false})
    local ok_status,status = pcall(vim.api.nvim_get_hl, 0, {name = "StatusLine", link = false})
    local base = ((ok_middle and (type(middle) == "table") and hl_rendered_bg(middle)) or (ok_status and (type(status) == "table") and hl_rendered_bg(status)) or 2763306)
    if (step == 2) then
      return (brighten_rgb(base, 0.02) or base)
    elseif (step == 3) then
      return (brighten_rgb(base, 0.04) or base)
    elseif (step == 4) then
      return (brighten_rgb(base, 0.06) or base)
    elseif (step == 5) then
      return (brighten_rgb(base, 0.04) or base)
    elseif (step == 6) then
      return (brighten_rgb(base, 0.02) or base)
    elseif (step == 7) then
      return (darken_rgb(base, 0.02) or base)
    elseif (step == 8) then
      return (darken_rgb(base, 0.04) or base)
    elseif (step == 9) then
      return (brighten_rgb(base, 0.06) or base)
    elseif (step == 10) then
      return (brighten_rgb(base, 0.04) or base)
    elseif (step == 11) then
      return (darken_rgb(base, 0.02) or base)
    else
      return base
    end
  end
  local function pulse_hl_from(group, bg)
    local opts0 = {default = true, cterm = {reverse = false}, reverse = false}
    local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
    if (ok and (type(hl) == "table")) then
      if hl_rendered_fg(hl) then
        opts0["fg"] = hl_rendered_fg(hl)
      else
      end
      if hl.ctermfg then
        opts0["ctermfg"] = hl.ctermfg
      else
      end
      if hl.bold then
        opts0["bold"] = hl.bold
      else
      end
    else
    end
    opts0["bg"] = bg
    return opts0
  end
  local function update_results_loading_pulse_highlights_21(step)
    local bg = results_pulse_bg(step)
    local hi = vim.api.nvim_set_hl
    hi(0, "MetaStatuslineMiddlePulse", pulse_hl_from("MetaStatuslineMiddle", bg))
    hi(0, "MetaStatuslineIndicatorPulse", pulse_hl_from("MetaStatuslineIndicator", bg))
    hi(0, "MetaStatuslineKeyPulse", pulse_hl_from("MetaStatuslineKey", bg))
    hi(0, "MetaStatuslineFlagOnPulse", pulse_hl_from("MetaStatuslineFlagOn", bg))
    return hi(0, "MetaStatuslineFlagOffPulse", pulse_hl_from("MetaStatuslineFlagOff", bg))
  end
  local function set_results_loading_pulse_21(session)
    if (session and session["loading-anim-phase"]) then
      local step = (((session["loading-anim-phase"] or 0) % 8) + 1)
      session["results-statusline-pulse-active?"] = true
      return update_results_loading_pulse_highlights_21(step)
    else
      session["results-statusline-pulse-active?"] = nil
      return nil
    end
  end
  local refresh_prompt_highlights_21 = nil
  local schedule_loading_indicator_21 = nil
  local function loading_indicator_tick_21(session)
    session["loading-anim-pending"] = false
    if session_prompt_valid_3f(session) then
      local animating_3f = (session_busy_3f(session) and animation_enabled_3f and animation_enabled_3f(session, "loading"))
      if animating_3f then
        session["loading-idle-pending"] = false
        session["loading-anim-phase"] = (1 + (session["loading-anim-phase"] or 0))
        set_results_loading_pulse_21(session)
        pcall(session.meta.refresh_statusline)
        refresh_prompt_highlights_21(session)
        return schedule_loading_indicator_21(session)
      else
        if session["loading-anim-phase"] then
          if session["loading-idle-pending"] then
            if session_actually_idle_3f(session) then
              session["loading-idle-pending"] = false
              session["loading-anim-phase"] = nil
              set_results_loading_pulse_21(session)
              return pcall(session.meta.refresh_statusline)
            else
              return nil
            end
          else
            session["loading-idle-pending"] = true
            return schedule_loading_indicator_21(session)
          end
        else
          session["loading-idle-pending"] = false
          return set_results_loading_pulse_21(session)
        end
      end
    else
      return nil
    end
  end
  local function _51_(session)
    if (session and not session["loading-anim-pending"] and session["prompt-buf"] and session_prompt_valid_3f(session) and session["loading-indicator?"] and (session_busy_3f(session) or session["loading-anim-phase"] or session["loading-idle-pending"])) then
      if (session_busy_3f(session) and (session["loading-anim-phase"] == nil)) then
        session["loading-idle-pending"] = false
        session["loading-anim-phase"] = 0
        set_results_loading_pulse_21(session)
        pcall(session.meta.refresh_statusline)
      else
      end
      session["loading-anim-pending"] = true
      local delay
      if session["loading-idle-pending"] then
        delay = 120
      else
        delay = animation_duration_ms(session, "loading", 90)
      end
      local function _54_()
        return loading_indicator_tick_21(session)
      end
      return vim.defer_fn(_54_, delay)
    else
      return nil
    end
  end
  schedule_loading_indicator_21 = _51_
  local function render_project_flags_footer_21(session)
    if (session["prompt-buf"] and session_prompt_valid_3f(session)) then
      local ns = (session["prompt-footer-ns"] or vim.api.nvim_create_namespace("metabuffer.prompt.footer"))
      local _
      session["prompt-footer-ns"] = ns
      _ = nil
      session["prompt-footer-ns"] = ns
      vim.api.nvim_buf_clear_namespace(session["prompt-buf"], ns, 0, -1)
      return schedule_loading_indicator_21(session)
    else
      return nil
    end
  end
  local function prompt_line_primary_group(row)
    return ("MetaPromptText" .. tostring(((math.max(0, (row - 1)) % 6) + 1)))
  end
  local function prompt_tokens(txt)
    local or_57_ = query_mod["tokenize-line"]
    if not or_57_ then
      local function _58_(s)
        return vim.split(s, "%s+", {trimempty = true})
      end
      or_57_ = _58_
    end
    return or_57_(txt)
  end
  local function directive_arg_style(tok)
    local token = (tok or "")
    local prefix = option_prefix()
    local parsed = directive_mod["parse-token"](prefix, token)
    local await = (parsed and parsed.await)
    if (((await and await.kind) or "") == "query-source") then
      return {["text-hl"] = "MetaPromptLgrep"}
    else
      return nil
    end
  end
  local function inline_file_filter_style(tok)
    local token = (tok or "")
    local colon = string.find(token, ":", 1, true)
    local prefix = option_prefix()
    if colon then
      local flag_token = string.sub(token, 1, (colon - 1))
      local parsed = directive_mod["parse-token"](prefix, flag_token)
      local style = (parsed and control_token_style(flag_token))
      if (((parsed and parsed["token-key"]) or "") == "include-files") then
        return {["flag-style"] = style, ["arg-start"] = colon, ["arg-hl"] = "MetaPromptFileArg"}
      else
        return nil
      end
    else
      return nil
    end
  end
  local function current_prompt_token(session)
    if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"]) and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
      local function _62_()
        local row_col = vim.api.nvim_win_get_cursor(0)
        local row = (row_col[1] or 1)
        local col1 = ((row_col[2] or 0) + 1)
        local line = (vim.api.nvim_buf_get_lines(session["prompt-buf"], (row - 1), row, false)[1] or "")
        return directive_mod["token-under-cursor"](line, col1)
      end
      return vim.api.nvim_win_call(session["prompt-win"], _62_)
    else
      return nil
    end
  end
  local function directive_help_token(tok)
    local token = (tok or "")
    local prefix = option_prefix()
    local colon = string.find(token, ":", 1, true)
    if colon then
      local stem = string.sub(token, 1, (colon - 1))
      if directive_mod["parse-token"](prefix, stem) then
        return stem
      else
        return token
      end
    else
      return token
    end
  end
  local function highlight_prompt_like_line_21(buf, ns, row, txt, primary_hl)
    local tokens = prompt_tokens(txt)
    local pos = 1
    local await_style = nil
    for _, token in ipairs(tokens) do
      local s,e = string.find(txt, token, pos, true)
      if (s and e) then
        local s0 = (s - 1)
        local e0 = e
        vim.api.nvim_buf_add_highlight(buf, ns, primary_hl, row, s0, e0)
        if await_style then
          vim.api.nvim_buf_add_highlight(buf, ns, (await_style["text-hl"] or "MetaPromptLgrep"), row, s0, e0)
        else
        end
        do
          local val_111_auto = inline_file_filter_style(token)
          if val_111_auto then
            local inline_style = val_111_auto
            local flag_style = inline_style["flag-style"]
            local arg_start = (s0 + (inline_style["arg-start"] or 0))
            if flag_style then
              vim.api.nvim_buf_add_highlight(buf, ns, (flag_style["hash-hl"] or primary_hl), row, s0, (s0 + 1))
              if (arg_start > (s0 + 1)) then
                vim.api.nvim_buf_add_highlight(buf, ns, (flag_style["text-hl"] or primary_hl), row, (s0 + 1), arg_start)
              else
              end
            else
            end
            if (e0 > arg_start) then
              vim.api.nvim_buf_add_highlight(buf, ns, (inline_style["arg-hl"] or "MetaPromptFileArg"), row, arg_start, e0)
            else
            end
          else
            local val_110_auto = control_token_style(token)
            if val_110_auto then
              local style = val_110_auto
              vim.api.nvim_buf_add_highlight(buf, ns, (style["hash-hl"] or primary_hl), row, s0, (s0 + 1))
              if (e0 > (s0 + 1)) then
                vim.api.nvim_buf_add_highlight(buf, ns, (style["text-hl"] or primary_hl), row, (s0 + 1), e0)
              else
              end
            else
            end
          end
        end
        await_style = directive_arg_style(token)
        if ((#token > 1) and (string.sub(token, 1, 1) == "!")) then
          vim.api.nvim_buf_add_highlight(buf, ns, "MetaPromptNeg", row, s0, e0)
        else
        end
        do
          local core
          if ((#token > 1) and (string.sub(token, 1, 1) == "!")) then
            core = string.sub(token, 2)
          else
            core = token
          end
          if ((#core > 0) and (nil ~= string.find(core, "[\\%[%]%(%)%+%*%?%|]"))) then
            vim.api.nvim_buf_add_highlight(buf, ns, "MetaPromptRegex", row, s0, e0)
          else
          end
        end
        if ((#token > 0) and (string.sub(token, 1, 1) == "^")) then
          vim.api.nvim_buf_add_highlight(buf, ns, "MetaPromptAnchor", row, s0, (s0 + 1))
        else
        end
        if ((#token > 0) and (string.sub(token, #token) == "$")) then
          vim.api.nvim_buf_add_highlight(buf, ns, "MetaPromptAnchor", row, (e0 - 1), e0)
        else
        end
        pos = (e + 1)
      else
      end
    end
    return nil
  end
  local function hide_directive_help_21(session)
    if (session["directive-help-win"] and vim.api.nvim_win_is_valid(session["directive-help-win"])) then
      pcall(vim.api.nvim_win_close, session["directive-help-win"], true)
    else
    end
    session["directive-help-win"] = nil
    if (session["directive-help-buf"] and not vim.api.nvim_buf_is_valid(session["directive-help-buf"])) then
      session["directive-help-buf"] = nil
      return nil
    else
      return nil
    end
  end
  local function show_directive_help_21(session, spec, span)
    if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"]) and spec) then
      local buf0 = (session["directive-help-buf"] and vim.api.nvim_buf_is_valid(session["directive-help-buf"]) and session["directive-help-buf"])
      local buf = (buf0 or vim.api.nvim_create_buf(false, true))
      local _
      session["directive-help-buf"] = buf
      _ = nil
      local help = (spec.help or "")
      local display
      if ((spec["token-key"] or "") == "include-files") then
        display = (option_prefix() .. "file:{filter}")
      else
        display = (spec.display or "")
      end
      local lines = {display, help}
      local width = math.max(#display, #help, 12)
      local row1 = ((span and span.row) or 1)
      local col1 = ((span and span.start) or 1)
      local screenpos = vim.fn.screenpos(session["prompt-win"], row1, col1)
      local screen_row = math.max(1, (screenpos.row or 1))
      local screen_col = math.max(1, (screenpos.col or 1))
      local cfg = {relative = "editor", row = math.max(0, (screen_row - (#lines + 3))), col = math.max(0, (screen_col - 1)), width = width, height = #lines, style = "minimal", border = "rounded", noautocmd = true, focusable = false}
      do
        local bo = vim.bo[buf]
        bo["buftype"] = "nofile"
        bo["bufhidden"] = "wipe"
        bo["swapfile"] = false
        bo["modifiable"] = true
      end
      pcall(vim.api.nvim_buf_set_name, buf, "[Metabuffer Directive Help]")
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      do
        local ns = (session["directive-help-hl-ns"] or vim.api.nvim_create_namespace("metabuffer.directive-help"))
        session["directive-help-hl-ns"] = ns
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        highlight_prompt_like_line_21(buf, ns, 0, display, "MetaPromptText1")
        vim.api.nvim_buf_add_highlight(buf, ns, "Comment", 1, 0, -1)
      end
      do
        local bo = vim.bo[buf]
        bo["modifiable"] = false
      end
      if (session["directive-help-win"] and vim.api.nvim_win_is_valid(session["directive-help-win"])) then
        pcall(vim.api.nvim_win_set_buf, session["directive-help-win"], buf)
        return pcall(vim.api.nvim_win_set_config, session["directive-help-win"], cfg)
      else
        session["directive-help-win"] = vim.api.nvim_open_win(buf, false, cfg)
        return nil
      end
    else
      return nil
    end
  end
  local function maybe_show_directive_help_21(session)
    if (not session["prompt-win"] or not vim.api.nvim_win_is_valid(session["prompt-win"]) or (vim.api.nvim_get_current_win() ~= session["prompt-win"])) then
      return hide_directive_help_21(session)
    else
      local val_111_auto = current_prompt_token(session)
      if val_111_auto then
        local span = val_111_auto
        local token = directive_help_token((span.token or ""))
        local prefix = option_prefix()
        local matches
        if vim.startswith(token, prefix) then
          matches = directive_mod["matching-catalog"](prefix, token)
        else
          matches = {}
        end
        if (#matches > 0) then
          return show_directive_help_21(session, matches[1], span)
        else
          return hide_directive_help_21(session)
        end
      else
        return hide_directive_help_21(session)
      end
    end
  end
  local function maybe_trigger_directive_complete_21(session)
    if (session["prompt-win"] and vim.api.nvim_win_is_valid(session["prompt-win"]) and (vim.api.nvim_get_current_win() == session["prompt-win"]) and vim.startswith((vim.api.nvim_get_mode().mode or ""), "i")) then
      local val_111_auto = current_prompt_token(session)
      if val_111_auto then
        local span = val_111_auto
        local token = (span.token or "")
        local prefix = option_prefix()
        local matches
        if vim.startswith(token, prefix) then
          matches = directive_mod["complete-items"](prefix, token)
        else
          matches = {}
        end
        local start = (span.start or 1)
        if ((#matches > 0) and (0 == vim.fn.pumvisible()) and (token ~= (session["directive-last-complete-token"] or ""))) then
          session["directive-last-complete-token"] = token
          return vim.fn.complete(start, matches)
        else
          return nil
        end
      else
        session["directive-last-complete-token"] = nil
        return nil
      end
    else
      return nil
    end
  end
  local function _92_(session)
    if (session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"])) then
      local ns = (session["prompt-hl-ns"] or vim.api.nvim_create_namespace("metabuffer.prompt"))
      local lines = vim.api.nvim_buf_get_lines(session["prompt-buf"], 0, -1, false)
      session["prompt-hl-ns"] = ns
      vim.api.nvim_buf_clear_namespace(session["prompt-buf"], ns, 0, -1)
      for row, line in ipairs((lines or {})) do
        local r = (row - 1)
        local txt = (line or "")
        local primary_hl = prompt_line_primary_group(row)
        highlight_prompt_like_line_21(session["prompt-buf"], ns, r, txt, primary_hl)
      end
      return render_project_flags_footer_21(session)
    else
      return nil
    end
  end
  refresh_prompt_highlights_21 = _92_
  local function maybe_expand_history_shorthand_21(router, session)
    if session["_expanding-history-shorthand"] then
      return false
    else
      if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        local _let_94_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
        local row = _let_94_[1]
        local col = _let_94_[2]
        local row0 = math.max(0, (row - 1))
        local line = (vim.api.nvim_buf_get_lines(session["prompt-buf"], row0, (row0 + 1), false)[1] or "")
        local left
        if (col > 0) then
          left = string.sub(line, 1, col)
        else
          left = ""
        end
        local saved_tag = string.match(left, "##([%w_%-]+)$")
        local saved_replacement
        if saved_tag then
          saved_replacement = router["saved-prompt-entry"](saved_tag)
        else
          saved_replacement = ""
        end
        local trigger
        if ((col >= 3) and vim.endswith(left, "!^!")) then
          trigger = "!^!"
        elseif ((col >= 2) and vim.endswith(left, "!!")) then
          trigger = "!!"
        elseif ((col >= 2) and vim.endswith(left, "!$")) then
          trigger = "!$"
        else
          trigger = nil
        end
        local replacement
        if (trigger == "!!") then
          replacement = router["last-prompt-entry"](session["prompt-buf"])
        elseif (trigger == "!$") then
          replacement = router["last-prompt-token"](session["prompt-buf"])
        elseif (trigger == "!^!") then
          replacement = router["last-prompt-tail"](session["prompt-buf"])
        else
          replacement = ""
        end
        if (trigger and (type(replacement) == "string") and (replacement ~= "")) then
          session["_expanding-history-shorthand"] = true
          do
            local start_col
            local _99_
            if (trigger == "!^!") then
              _99_ = 3
            else
              _99_ = 2
            end
            start_col = (col - _99_)
            vim.api.nvim_buf_set_text(session["prompt-buf"], row0, start_col, row0, col, {""})
            pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, start_col})
          end
          if (trigger == "!!") then
            router["insert-last-prompt"](session["prompt-buf"])
          elseif (trigger == "!$") then
            router["insert-last-token"](session["prompt-buf"])
          else
            router["insert-last-tail"](session["prompt-buf"])
          end
          session["_expanding-history-shorthand"] = false
          return true
        else
          if (saved_tag and (type(saved_replacement) == "string") and (saved_replacement ~= "")) then
            session["_expanding-history-shorthand"] = true
            do
              local tag_len = (2 + #saved_tag)
              local start_col = (col - tag_len)
              vim.api.nvim_buf_set_text(session["prompt-buf"], row0, start_col, row0, col, {""})
              pcall(vim.api.nvim_win_set_cursor, session["prompt-win"], {row, start_col})
            end
            router["prompt-insert-text"](session["prompt-buf"], saved_replacement)
            session["_expanding-history-shorthand"] = false
            return true
          else
            return false
          end
        end
      else
        return false
      end
    end
  end
  local function resolve_map_action(router, session, action, arg)
    if (action == "accept") then
      local function _106_()
        return router.accept(session["prompt-buf"])
      end
      return _106_
    elseif (action == "enter-edit-mode") then
      local function _107_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _107_
    elseif (action == "cancel") then
      local function _108_()
        return router.cancel(session["prompt-buf"])
      end
      return _108_
    elseif (action == "move-selection") then
      local function _109_()
        return router["move-selection"](session["prompt-buf"], arg)
      end
      return _109_
    elseif (action == "history-or-move") then
      local function _110_()
        return router["history-or-move"](session["prompt-buf"], arg)
      end
      return _110_
    elseif (action == "prompt-home") then
      local function _111_()
        local function _112_()
          return router["prompt-home"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _112_)
      end
      return _111_
    elseif (action == "prompt-end") then
      local function _113_()
        local function _114_()
          return router["prompt-end"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _114_)
      end
      return _113_
    elseif (action == "prompt-kill-backward") then
      local function _115_()
        local function _116_()
          return router["prompt-kill-backward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _116_)
      end
      return _115_
    elseif (action == "prompt-kill-forward") then
      local function _117_()
        local function _118_()
          return router["prompt-kill-forward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _118_)
      end
      return _117_
    elseif (action == "prompt-yank") then
      local function _119_()
        local function _120_()
          return router["prompt-yank"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _120_)
      end
      return _119_
    elseif (action == "prompt-newline") then
      local function _121_()
        local function _122_()
          return router["prompt-newline"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _122_)
      end
      return _121_
    elseif (action == "insert-last-prompt") then
      local function _123_()
        local function _124_()
          return router["insert-last-prompt"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _124_)
      end
      return _123_
    elseif (action == "insert-last-token") then
      local function _125_()
        local function _126_()
          return router["insert-last-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _126_)
      end
      return _125_
    elseif (action == "insert-last-tail") then
      local function _127_()
        local function _128_()
          return router["insert-last-tail"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _128_)
      end
      return _127_
    elseif (action == "toggle-prompt-results-focus") then
      local function _129_()
        local function _130_()
          return router["toggle-prompt-results-focus"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _130_)
      end
      return _129_
    elseif (action == "negate-current-token") then
      local function _131_()
        local function _132_()
          return router["negate-current-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _132_)
      end
      return _131_
    elseif (action == "history-searchback") then
      local function _133_()
        local function _134_()
          return router["open-history-searchback"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _134_)
      end
      return _133_
    elseif (action == "merge-history") then
      local function _135_()
        local function _136_()
          return router["merge-history-cache"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _136_)
      end
      return _135_
    elseif (action == "switch-mode") then
      local function _137_()
        return switch_mode(session, arg)
      end
      return _137_
    elseif (action == "toggle-scan-option") then
      local function _138_()
        return router["toggle-scan-option"](session["prompt-buf"], arg)
      end
      return _138_
    elseif (action == "scroll-main") then
      local function _139_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _139_
    elseif (action == "toggle-project-mode") then
      local function _140_()
        return router["toggle-project-mode"](session["prompt-buf"])
      end
      return _140_
    elseif (action == "toggle-info-file-entry-view") then
      local function _141_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _141_
    elseif (action == "refresh-files") then
      local function _142_()
        return router["refresh-files"](session["prompt-buf"])
      end
      return _142_
    else
      return nil
    end
  end
  local function apply_keymaps(router, session)
    local base_opts = {buffer = session["prompt-buf"], silent = true, noremap = true, nowait = true}
    local rules = (session["prompt-keymaps"] or default_prompt_keymaps)
    for _, r in ipairs(rules) do
      local mode = r[1]
      local lhs = r[2]
      local action = r[3]
      local arg = r[4]
      local opts0
      if ((action == "insert-last-prompt") or (action == "insert-last-token") or (action == "insert-last-tail")) then
        opts0 = vim.tbl_extend("force", base_opts, {nowait = false})
      else
        opts0 = base_opts
      end
      local rhs = resolve_map_action(router, session, action, arg)
      if rhs then
        vim.keymap.set(mode, lhs, rhs, opts0)
      else
        vim.notify(("metabuffer: unknown prompt keymap action '" .. tostring(action) .. "' for " .. tostring(lhs)), vim.log.levels.WARN)
      end
    end
    return nil
  end
  local function apply_emacs_insert_fallbacks(router, session)
    local base_opts = {buffer = session["prompt-buf"], silent = true, noremap = true, nowait = true}
    local rules = (session["prompt-fallback-keymaps"] or {})
    for _, r in ipairs(rules) do
      local mode = r[1]
      local lhs = r[2]
      local action = r[3]
      local arg = r[4]
      local rhs = resolve_map_action(router, session, action, arg)
      if rhs then
        vim.keymap.set(mode, lhs, rhs, base_opts)
      else
      end
    end
    return nil
  end
  local function resolve_main_map_action(router, session, action, arg)
    if (action == "cancel") then
      local function _147_()
        return router.cancel(session["prompt-buf"])
      end
      return _147_
    elseif (action == "accept-main") then
      local function _148_()
        return router["accept-main"](session["prompt-buf"])
      end
      return _148_
    elseif (action == "enter-edit-mode") then
      local function _149_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _149_
    elseif (action == "exclude-symbol-under-cursor") then
      local function _150_()
        return router["exclude-symbol-under-cursor"](session["prompt-buf"])
      end
      return _150_
    elseif (action == "insert-symbol-under-cursor") then
      local function _151_()
        return router["insert-symbol-under-cursor"](session["prompt-buf"])
      end
      return _151_
    elseif (action == "insert-symbol-under-cursor-newline") then
      local function _152_()
        return router["insert-symbol-under-cursor-newline"](session["prompt-buf"])
      end
      return _152_
    elseif (action == "toggle-prompt-results-focus") then
      local function _153_()
        return router["toggle-prompt-results-focus"](session["prompt-buf"])
      end
      return _153_
    elseif (action == "scroll-main") then
      local function _154_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _154_
    elseif (action == "toggle-info-file-entry-view") then
      local function _155_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _155_
    elseif (action == "refresh-files") then
      local function _156_()
        return router["refresh-files"](session["prompt-buf"])
      end
      return _156_
    else
      return nil
    end
  end
  local function apply_main_keymaps(router, session)
    local base_opts = {buffer = session.meta.buf.buffer, silent = true, noremap = true, nowait = true}
    local rules = (session["main-keymaps"] or default_main_keymaps)
    for _, r in ipairs(rules) do
      local mode = r[1]
      local lhs = r[2]
      local action = r[3]
      local arg = r[4]
      local rhs = resolve_main_map_action(router, session, action, arg)
      if rhs then
        vim.keymap.set(mode, lhs, rhs, base_opts)
      else
        vim.notify(("metabuffer: unknown main keymap action '" .. tostring(action) .. "' for " .. tostring(lhs)), vim.log.levels.WARN)
      end
    end
    return nil
  end
  local function feed_results_normal_key_21(key)
    return vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "n", false)
  end
  local function set_pending_structural_edit_21(session, side)
    if (session["results-edit-mode"] and session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window)) then
      local row = vim.api.nvim_win_get_cursor(session.meta.win.window)[1]
      local idx = (session.meta.buf.indices or {})[row]
      local ref = (idx and (session.meta.buf["source-refs"] or {})[idx])
      if (ref and ref.path and ref.lnum) then
        session["pending-structural-edit"] = {path = ref.path, lnum = ref.lnum, side = side, kind = (ref.kind or "")}
        return nil
      else
        return nil
      end
    else
      return nil
    end
  end
  local function apply_results_edit_keymaps(session)
    local opts0 = {buffer = session.meta.buf.buffer, silent = true, noremap = true, nowait = true}
    local function _161_()
      set_pending_structural_edit_21(session, "after")
      return feed_results_normal_key_21("o")
    end
    vim.keymap.set("n", "o", _161_, opts0)
    local function _162_()
      set_pending_structural_edit_21(session, "before")
      return feed_results_normal_key_21("O")
    end
    vim.keymap.set("n", "O", _162_, opts0)
    local function _163_()
      set_pending_structural_edit_21(session, "after")
      return feed_results_normal_key_21("p")
    end
    vim.keymap.set("n", "p", _163_, opts0)
    local function _164_()
      set_pending_structural_edit_21(session, "before")
      return feed_results_normal_key_21("P")
    end
    return vim.keymap.set("n", "P", _164_, opts0)
  end
  local function begin_direct_results_edit_21(session)
    if (sign_mod and session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
      local buf = session.meta.buf.buffer
      local internal_3f
      do
        local ok,v = pcall(vim.api.nvim_buf_get_var, buf, "meta_internal_render")
        internal_3f = (ok and v)
      end
      local manual_3f
      do
        local ok,v = pcall(vim.api.nvim_buf_get_var, buf, "meta_manual_edit_active")
        manual_3f = (ok and v)
      end
      if not (internal_3f or manual_3f) then
        session["results-edit-mode"] = true
        pcall(sign_mod["capture-baseline!"], session)
        return pcall(vim.api.nvim_buf_set_var, buf, "meta_manual_edit_active", true)
      else
        return nil
      end
    else
      return nil
    end
  end
  local function register_21(router, session)
    local aug = vim.api.nvim_create_augroup(("MetaPrompt" .. session["prompt-buf"]), {clear = true})
    session.augroup = aug
    capture_expected_layout_21(session)
    local function au_21(events0, buf, body)
      local function _167_(_)
        return schedule_when_valid(session, body)
      end
      return vim.api.nvim_create_autocmd(events0, {group = aug, buffer = buf, callback = _167_})
    end
    local function au_buf_21(events0, buf, callback)
      return vim.api.nvim_create_autocmd(events0, {group = aug, buffer = buf, callback = callback})
    end
    local function au_global_21(events0, callback, _3fopts)
      local base = {group = aug, callback = callback}
      for k, v in pairs((_3fopts or {})) do
        base[k] = v
      end
      return vim.api.nvim_create_autocmd(events0, base)
    end
    local function _168_(_, _0, changedtick, _1, _2, _3, _4, _5)
      local function _169_()
        if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
          if maybe_expand_history_shorthand_21(router, session) then
            return nil
          else
            refresh_prompt_highlights_21(session)
            return on_prompt_changed(session["prompt-buf"], false, changedtick)
          end
        else
          return nil
        end
      end
      return vim.schedule(_169_)
    end
    local function _172_()
      if session["prompt-buf"] then
        active_by_prompt[session["prompt-buf"]] = nil
        return nil
      else
        return nil
      end
    end
    vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _168_, on_detach = _172_})
    local function _174_(_)
      if maybe_expand_history_shorthand_21(router, session) then
        return nil
      else
        refresh_prompt_highlights_21(session)
        maybe_show_directive_help_21(session)
        maybe_trigger_directive_complete_21(session)
        return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
      end
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session["prompt-buf"], _174_)
    local function _176_()
      events.send("on-insert-enter!", {session = session})
      apply_keymaps(router, session)
      return apply_emacs_insert_fallbacks(router, session)
    end
    au_21("InsertEnter", session["prompt-buf"], _176_)
    local function _177_()
      return pcall(session.meta.refresh_statusline)
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session["prompt-buf"], _177_)
    local function _178_()
      pcall(session.meta.refresh_statusline)
      return maybe_show_directive_help_21(session)
    end
    au_21({"ModeChanged", "InsertEnter", "InsertLeave"}, session["prompt-buf"], _178_)
    local function _179_()
      return maybe_show_directive_help_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session["prompt-buf"], _179_)
    local function _180_()
      return hide_directive_help_21(session)
    end
    au_21({"BufLeave", "WinLeave"}, session["prompt-buf"], _180_)
    local function _181_()
      if maybe_refresh_preview_statusline_21 then
        pcall(maybe_refresh_preview_statusline_21, session)
      else
      end
      if maybe_refresh_info_statusline_21 then
        return pcall(maybe_refresh_info_statusline_21, session)
      else
        return nil
      end
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session["prompt-buf"], _181_)
    local function _184_(ev)
      if not session["handling-layout-change?"] then
        do
          local is_vim_resized_3f = (ev.event == "VimResized")
          local wins
          local _186_
          do
            local t_185_ = vim.v
            if (nil ~= t_185_) then
              t_185_ = t_185_.event
            else
            end
            if (nil ~= t_185_) then
              t_185_ = t_185_.windows
            else
            end
            _186_ = t_185_
          end
          wins = (_186_ or {})
          local manual_prompt_resize = (not is_vim_resized_3f and manual_prompt_resize_3f(session, wins))
          if is_vim_resized_3f then
            session["preview-user-resized?"] = false
          else
          end
          if (not is_vim_resized_3f and session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
            for _, wid in ipairs(wins) do
              if (wid == session["preview-win"]) then
                session["preview-user-resized?"] = true
              else
              end
            end
          else
          end
          if manual_prompt_resize then
            session["prompt-target-height"] = vim.api.nvim_win_get_height(session["prompt-win"])
            capture_expected_layout_21(session)
          else
            schedule_restore_expected_layout_21(session)
          end
        end
        session["handling-layout-change?"] = true
        local function _193_()
          if session_prompt_valid_3f(session) then
            do
              local results_wrap_3f = (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window) and vim.api.nvim_get_option_value("wrap", {win = session.meta.win.window}))
              if (results_wrap_3f and rebuild_source_set_21) then
                pcall(rebuild_source_set_21, session)
                pcall(session.meta["on-update"], 0)
              else
              end
            end
            if not session["prompt-animating?"] then
              pcall(refresh_prompt_highlights_21, session)
              if update_preview_window then
                pcall(update_preview_window, session)
              else
              end
              pcall(update_info_window, session)
            else
            end
            if (ev.event == "VimResized") then
              capture_expected_layout_21(session)
            else
            end
          else
          end
          session["handling-layout-change?"] = false
          return nil
        end
        return vim.schedule(_193_)
      else
        return nil
      end
    end
    au_global_21({"VimResized", "WinResized"}, _184_)
    local function _200_(_)
      if not session["handling-layout-change?"] then
        session["handling-layout-change?"] = true
        local function _201_()
          if session_prompt_valid_3f(session) then
            if (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window) and (vim.api.nvim_get_current_win() == session.meta.win.window)) then
              local wrap_3f = clj.boolean(vim.api.nvim_get_option_value("wrap", {win = session.meta.win.window}))
              pcall(vim.api.nvim_set_option_value, "linebreak", wrap_3f, {win = session.meta.win.window})
              if rebuild_source_set_21 then
                pcall(rebuild_source_set_21, session)
                pcall(session.meta["on-update"], 0)
                pcall(update_info_window, session, true)
                if update_preview_window then
                  pcall(update_preview_window, session)
                else
                end
              else
              end
            else
            end
          else
          end
          session["handling-layout-change?"] = false
          return nil
        end
        return vim.schedule(_201_)
      else
        return nil
      end
    end
    au_global_21("OptionSet", _200_, {pattern = "wrap"})
    local function _207_()
      return maybe_sync_from_main_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session.meta.buf.buffer, _207_)
    local function _208_(_)
      return begin_direct_results_edit_21(session)
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _208_)
    local function _209_(_)
      if (sign_mod and session.meta and session.meta.buf) then
        local buf = session.meta.buf.buffer
        local internal_3f
        do
          local ok,v = pcall(vim.api.nvim_buf_get_var, buf, "meta_internal_render")
          internal_3f = (ok and v)
        end
        if not internal_3f then
          begin_direct_results_edit_21(session)
        else
        end
        local function _211_()
          if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            pcall(router["sync-live-edits"], session["prompt-buf"])
            pcall(maybe_sync_from_main_21, session, true)
            pcall(update_info_window, session, true)
            return pcall(sign_mod["refresh-change-signs!"], session)
          else
            return nil
          end
        end
        return vim.schedule(_211_)
      else
        return nil
      end
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session.meta.buf.buffer, _209_)
    local function _214_(_)
      if (not session.closing and session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
        local bo = vim.bo[session.meta.buf.buffer]
        bo["buftype"] = "acwrite"
        bo["modifiable"] = true
        bo["readonly"] = false
        bo["bufhidden"] = "hide"
      else
      end
      if maybe_restore_hidden_ui_21 then
        local function _216_()
          if (not session.closing and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            return pcall(maybe_restore_hidden_ui_21, session)
          else
            return nil
          end
        end
        return vim.schedule(_216_)
      else
        return nil
      end
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _214_)
    local function _219_(_)
      local function _220_()
        if (hide_visible_ui_21 and not session["ui-hidden"] and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
          local win = vim.api.nvim_get_current_win()
          if covered_by_new_window_3f(session, win) then
            return pcall(hide_visible_ui_21, session)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_220_, 20)
    end
    au_global_21("WinNew", _219_)
    local function _223_(ev)
      local function _224_()
        if (hide_visible_ui_21 and not session["ui-hidden"] and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
          local buf = (ev.buf or vim.api.nvim_get_current_buf())
          local win = (first_window_for_buffer(buf) or vim.api.nvim_get_current_win())
          if (transient_overlay_buffer_3f(buf) or covered_by_new_window_3f(session, win)) then
            return pcall(hide_visible_ui_21, session)
          else
            return nil
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_224_, 20)
    end
    au_global_21("BufWinEnter", _223_)
    local function _227_()
      return pcall(session.meta.refresh_statusline)
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _227_)
    local function _228_(_)
      local function _229_()
        if (session["ui-hidden"] and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session) and not hidden_session_reachable_3f(session)) then
          return pcall(router["remove-session"], session)
        else
          return nil
        end
      end
      return vim.schedule(_229_)
    end
    au_global_21({"BufEnter", "WinEnter", "FocusGained"}, _228_)
    local function _231_(_)
      local function _232_()
        if (not session["ui-hidden"] and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and (active_by_prompt[session["prompt-buf"]] == session)) then
          local win = session.meta.win.window
          if not vim.api.nvim_win_is_valid(win) then
            return router.cancel(session["prompt-buf"])
          else
            local buf = vim.api.nvim_win_get_buf(win)
            if (buf ~= session.meta.buf.buffer) then
              if (session["project-mode"] and hide_visible_ui_21) then
                return hide_visible_ui_21(session["prompt-buf"])
              else
                return router.cancel(session["prompt-buf"])
              end
            else
              return nil
            end
          end
        else
          return nil
        end
      end
      return vim.schedule(_232_)
    end
    au_buf_21("BufLeave", session.meta.buf.buffer, _231_)
    apply_main_keymaps(router, session)
    apply_results_edit_keymaps(session)
    local function _237_(ev)
      local function _238_()
        if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session) and not session.closing) then
          local buf = (ev.buf or vim.api.nvim_get_current_buf())
          if (vim.api.nvim_buf_is_valid(buf) and (buf ~= session.meta.buf.buffer)) then
            local raw = vim.api.nvim_buf_get_name(buf)
            local path
            if (raw and (raw ~= "")) then
              path = vim.fn.fnamemodify(raw, ":p")
            else
              path = nil
            end
            if path then
              if session["preview-file-cache"] then
                session["preview-file-cache"][path] = nil
              else
              end
              if session["info-file-head-cache"] then
                session["info-file-head-cache"][path] = nil
              else
              end
              if session["info-file-meta-cache"] then
                session["info-file-meta-cache"][path] = nil
              else
              end
              if router["project-file-cache"] then
                router["project-file-cache"][path] = nil
              else
              end
              if rebuild_source_set_21 then
                pcall(rebuild_source_set_21, session)
              else
              end
              return pcall(update_info_window, session, true)
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
      return vim.schedule(_238_)
    end
    au_global_21("BufWritePost", _237_)
    local function _248_(_)
      return schedule_scroll_sync_21(session)
    end
    au_global_21("WinScrolled", _248_)
    local function _249_(_)
      return router["write-results"](session["prompt-buf"])
    end
    au_buf_21("BufWriteCmd", session.meta.buf.buffer, _249_)
    local function _250_(_)
      local function _251_()
        return router["results-buffer-wiped"](session.meta.buf.buffer)
      end
      return vim.schedule(_251_)
    end
    au_buf_21("BufWipeout", session.meta.buf.buffer, _250_)
    refresh_prompt_highlights_21(session)
    maybe_show_directive_help_21(session)
    local function _252_()
      if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
        pcall(refresh_prompt_highlights_21, session)
        return capture_expected_layout_21(session)
      else
        return nil
      end
    end
    vim.defer_fn(_252_, prompt_animation_delay_ms(session))
    apply_keymaps(router, session)
    return apply_emacs_insert_fallbacks(router, session)
  end
  return {["register!"] = register_21, ["refresh!"] = refresh_prompt_highlights_21}
end
return M
