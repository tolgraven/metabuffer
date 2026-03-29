-- [nfnl] fnl/metabuffer/prompt/hooks.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local animation_mod = require("metabuffer.window.animation")
local events = require("metabuffer.events")
local hooks_window_mod = require("metabuffer.prompt.hooks_window")
local query_mod = require("metabuffer.query")
local directive_mod = require("metabuffer.query.directive")
M.new = function(opts)
  local default_prompt_keymaps = opts["default-prompt-keymaps"]
  local active_by_prompt = opts["active-by-prompt"]
  local default_main_keymaps = opts["default-main-keymaps"]
  local on_prompt_changed = opts["on-prompt-changed"]
  local maybe_sync_from_main_21 = opts["maybe-sync-from-main!"]
  local schedule_scroll_sync_21 = opts["schedule-scroll-sync!"]
  local maybe_restore_hidden_ui_21 = opts["maybe-restore-hidden-ui!"]
  local hide_visible_ui_21 = opts["hide-visible-ui!"]
  local rebuild_source_set_21 = opts["rebuild-source-set!"]
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
    local function mode_label(value)
      if (type(value) == "table") then
        return (value.name or tostring(value))
      else
        return tostring(value)
      end
    end
    local old = mode_label(meta.mode[which].current())
    meta.switch_mode(which)
    return events.post("on-mode-switch!", {session = session, kind = which, old = old, new = mode_label(meta.mode[which].current())}, {["supersede?"] = true, ["dedupe-key"] = ("on-mode-switch:" .. tostring(session["prompt-buf"]) .. ":" .. which)})
  end
  local function nvim_exiting_3f()
    local v = (vim.v and vim.v.exiting)
    return ((v ~= nil) and (v ~= vim.NIL) and (v ~= 0) and (v ~= ""))
  end
  local function session_prompt_valid_3f(session)
    return (not nvim_exiting_3f() and session and not session["ui-hidden"] and not session.closing and session.meta and session["prompt-buf"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and (active_by_prompt[session["prompt-buf"]] == session))
  end
  local function schedule_when_valid(session, f)
    local function _3_()
      if session_prompt_valid_3f(session) then
        return f()
      else
        return nil
      end
    end
    return vim.schedule(_3_)
  end
  local function option_prefix()
    local p = vim.g["meta#prefix"]
    if ((type(p) == "string") and (p ~= "")) then
      return p
    else
      return "#"
    end
  end
  local window_hooks = hooks_window_mod.new(session_prompt_valid_3f)
  local covered_by_new_window_3f = window_hooks["covered-by-new-window?"]
  local transient_overlay_buffer_3f = window_hooks["transient-overlay-buffer?"]
  local first_window_for_buffer = window_hooks["first-window-for-buffer"]
  local capture_expected_layout_21 = window_hooks["capture-expected-layout!"]
  local note_editor_size_21 = window_hooks["note-editor-size!"]
  local note_global_editor_resize_21 = window_hooks["note-global-editor-resize!"]
  local manual_prompt_resize_3f = window_hooks["manual-prompt-resize?"]
  local schedule_restore_expected_layout_21 = window_hooks["schedule-restore-expected-layout!"]
  local hidden_session_reachable_3f = window_hooks["hidden-session-reachable?"]
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
      local _6_
      if off_3f then
        _6_ = "MetaPromptFlagHashOff"
      else
        _6_ = "MetaPromptFlagHashOn"
      end
      local _8_
      if functional_3f then
        if off_3f then
          _8_ = "MetaPromptFlagTextFuncOff"
        else
          _8_ = "MetaPromptFlagTextFuncOn"
        end
      else
        if off_3f then
          _8_ = "MetaPromptFlagTextOff"
        else
          _8_ = "MetaPromptFlagTextOn"
        end
      end
      return {["hash-hl"] = _6_, ["text-hl"] = _8_}
    end
  end
  local function session_busy_3f(session)
    return (session and (session["prompt-update-pending"] or session["prompt-update-dirty"] or session["project-bootstrap-pending"] or (session["project-mode"] and not session["lazy-stream-done"]) or (session["project-mode"] and not session["project-bootstrapped"])))
  end
  local function session_actually_idle_3f(session)
    return (session and not session_busy_3f(session) and not session["prompt-update-dirty"])
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
        events.send("on-loading-state!", {session = session})
        refresh_prompt_highlights_21(session)
        return schedule_loading_indicator_21(session)
      else
        if session["loading-anim-phase"] then
          if session["loading-idle-pending"] then
            if session_actually_idle_3f(session) then
              session["loading-idle-pending"] = false
              session["loading-anim-phase"] = nil
              set_results_loading_pulse_21(session)
              return events.send("on-loading-state!", {session = session})
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
  local function _28_(session)
    if (session and not session["loading-anim-pending"] and session["prompt-buf"] and session_prompt_valid_3f(session) and session["loading-indicator?"] and (session_busy_3f(session) or session["loading-anim-phase"] or session["loading-idle-pending"])) then
      if (session_busy_3f(session) and (session["loading-anim-phase"] == nil)) then
        session["loading-idle-pending"] = false
        session["loading-anim-phase"] = 0
        set_results_loading_pulse_21(session)
        events.send("on-loading-state!", {session = session})
      else
      end
      session["loading-anim-pending"] = true
      local delay
      if session["loading-idle-pending"] then
        delay = 120
      else
        delay = animation_duration_ms(session, "loading", 90)
      end
      local function _31_()
        return loading_indicator_tick_21(session)
      end
      return vim.defer_fn(_31_, delay)
    else
      return nil
    end
  end
  schedule_loading_indicator_21 = _28_
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
    local or_34_ = query_mod["tokenize-line"]
    if not or_34_ then
      local function _35_(s)
        return vim.split(s, "%s+", {trimempty = true})
      end
      or_34_ = _35_
    end
    return or_34_(txt)
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
      local function _39_()
        local row_col = vim.api.nvim_win_get_cursor(0)
        local row = (row_col[1] or 1)
        local col1 = ((row_col[2] or 0) + 1)
        local line = (vim.api.nvim_buf_get_lines(session["prompt-buf"], (row - 1), row, false)[1] or "")
        local val_111_auto = directive_mod["token-under-cursor"](line, col1)
        if val_111_auto then
          local span = val_111_auto
          return vim.tbl_extend("force", span, {row = row})
        else
          return nil
        end
      end
      return vim.api.nvim_win_call(session["prompt-win"], _39_)
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
  local function directive_help_spec_for_token(token)
    local needle = (token or "")
    local prefix = option_prefix()
    local matches = directive_mod["matching-catalog"](prefix, needle)
    local exact = nil
    for _, spec in ipairs(matches) do
      if (not exact and (((spec.display or "") == needle) or ((spec.literal or "") == needle) or ((spec.prefix or "") == needle))) then
        exact = spec
      else
      end
    end
    return (exact or matches[1])
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
  local function maybe_show_directive_help_21(session, selected_item)
    if (not session["prompt-win"] or not vim.api.nvim_win_is_valid(session["prompt-win"]) or (vim.api.nvim_get_current_win() ~= session["prompt-win"])) then
      return hide_directive_help_21(session)
    else
      local val_111_auto = current_prompt_token(session)
      if val_111_auto then
        local span = val_111_auto
        local selected_word = ((selected_item and selected_item.word) or (selected_item and selected_item.abbr) or "")
        local token = directive_help_token((span.token or ""))
        local prefix = option_prefix()
        local spec
        if ((selected_word ~= "") and vim.startswith(selected_word, prefix)) then
          spec = directive_help_spec_for_token(selected_word)
        else
          spec = (vim.startswith(token, prefix) and directive_help_spec_for_token(token))
        end
        if spec then
          return show_directive_help_21(session, spec, span)
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
  local function _71_(session)
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
  refresh_prompt_highlights_21 = _71_
  local function maybe_expand_history_shorthand_21(router, session)
    if session["_expanding-history-shorthand"] then
      return false
    else
      if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        local _let_73_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
        local row = _let_73_[1]
        local col = _let_73_[2]
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
            local _78_
            if (trigger == "!^!") then
              _78_ = 3
            else
              _78_ = 2
            end
            start_col = (col - _78_)
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
      local function _85_()
        return router.accept(session["prompt-buf"])
      end
      return _85_
    elseif (action == "enter-edit-mode") then
      local function _86_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _86_
    elseif (action == "cancel") then
      local function _87_()
        return router.cancel(session["prompt-buf"])
      end
      return _87_
    elseif (action == "move-selection") then
      local function _88_()
        return router["move-selection"](session["prompt-buf"], arg)
      end
      return _88_
    elseif (action == "history-or-move") then
      local function _89_()
        return router["history-or-move"](session["prompt-buf"], arg)
      end
      return _89_
    elseif (action == "prompt-home") then
      local function _90_()
        local function _91_()
          return router["prompt-home"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _91_)
      end
      return _90_
    elseif (action == "prompt-end") then
      local function _92_()
        local function _93_()
          return router["prompt-end"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _93_)
      end
      return _92_
    elseif (action == "prompt-kill-backward") then
      local function _94_()
        local function _95_()
          return router["prompt-kill-backward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _95_)
      end
      return _94_
    elseif (action == "prompt-kill-forward") then
      local function _96_()
        local function _97_()
          return router["prompt-kill-forward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _97_)
      end
      return _96_
    elseif (action == "prompt-yank") then
      local function _98_()
        local function _99_()
          return router["prompt-yank"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _99_)
      end
      return _98_
    elseif (action == "prompt-newline") then
      local function _100_()
        local function _101_()
          return router["prompt-newline"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _101_)
      end
      return _100_
    elseif (action == "insert-last-prompt") then
      local function _102_()
        local function _103_()
          return router["insert-last-prompt"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _103_)
      end
      return _102_
    elseif (action == "insert-last-token") then
      local function _104_()
        local function _105_()
          return router["insert-last-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _105_)
      end
      return _104_
    elseif (action == "insert-last-tail") then
      local function _106_()
        local function _107_()
          return router["insert-last-tail"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _107_)
      end
      return _106_
    elseif (action == "toggle-prompt-results-focus") then
      local function _108_()
        local function _109_()
          return router["toggle-prompt-results-focus"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _109_)
      end
      return _108_
    elseif (action == "negate-current-token") then
      local function _110_()
        local function _111_()
          return router["negate-current-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _111_)
      end
      return _110_
    elseif (action == "history-searchback") then
      local function _112_()
        local function _113_()
          return router["open-history-searchback"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _113_)
      end
      return _112_
    elseif (action == "merge-history") then
      local function _114_()
        local function _115_()
          return router["merge-history-cache"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _115_)
      end
      return _114_
    elseif (action == "switch-mode") then
      local function _116_()
        return switch_mode(session, arg)
      end
      return _116_
    elseif (action == "toggle-scan-option") then
      local function _117_()
        return router["toggle-scan-option"](session["prompt-buf"], arg)
      end
      return _117_
    elseif (action == "scroll-main") then
      local function _118_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _118_
    elseif (action == "toggle-project-mode") then
      local function _119_()
        return router["toggle-project-mode"](session["prompt-buf"])
      end
      return _119_
    elseif (action == "toggle-info-file-entry-view") then
      local function _120_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _120_
    elseif (action == "refresh-files") then
      local function _121_()
        return router["refresh-files"](session["prompt-buf"])
      end
      return _121_
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
      local function _126_()
        return router.cancel(session["prompt-buf"])
      end
      return _126_
    elseif (action == "accept-main") then
      local function _127_()
        return router["accept-main"](session["prompt-buf"])
      end
      return _127_
    elseif (action == "enter-edit-mode") then
      local function _128_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _128_
    elseif (action == "exclude-symbol-under-cursor") then
      local function _129_()
        return router["exclude-symbol-under-cursor"](session["prompt-buf"])
      end
      return _129_
    elseif (action == "insert-symbol-under-cursor") then
      local function _130_()
        return router["insert-symbol-under-cursor"](session["prompt-buf"])
      end
      return _130_
    elseif (action == "insert-symbol-under-cursor-newline") then
      local function _131_()
        return router["insert-symbol-under-cursor-newline"](session["prompt-buf"])
      end
      return _131_
    elseif (action == "toggle-prompt-results-focus") then
      local function _132_()
        return router["toggle-prompt-results-focus"](session["prompt-buf"])
      end
      return _132_
    elseif (action == "scroll-main") then
      local function _133_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _133_
    elseif (action == "toggle-info-file-entry-view") then
      local function _134_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _134_
    elseif (action == "refresh-files") then
      local function _135_()
        return router["refresh-files"](session["prompt-buf"])
      end
      return _135_
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
    local function _140_()
      set_pending_structural_edit_21(session, "after")
      return feed_results_normal_key_21("o")
    end
    vim.keymap.set("n", "o", _140_, opts0)
    local function _141_()
      set_pending_structural_edit_21(session, "before")
      return feed_results_normal_key_21("O")
    end
    vim.keymap.set("n", "O", _141_, opts0)
    local function _142_()
      set_pending_structural_edit_21(session, "after")
      return feed_results_normal_key_21("p")
    end
    vim.keymap.set("n", "p", _142_, opts0)
    local function _143_()
      set_pending_structural_edit_21(session, "before")
      return feed_results_normal_key_21("P")
    end
    return vim.keymap.set("n", "P", _143_, opts0)
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
      local function _146_(_)
        return schedule_when_valid(session, body)
      end
      return vim.api.nvim_create_autocmd(events0, {group = aug, buffer = buf, callback = _146_})
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
    local function _147_(_, _0, changedtick, _1, _2, _3, _4, _5)
      local function _148_()
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
      return vim.schedule(_148_)
    end
    local function _151_()
      if session["prompt-buf"] then
        active_by_prompt[session["prompt-buf"]] = nil
        return nil
      else
        return nil
      end
    end
    vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _147_, on_detach = _151_})
    local function _153_(_)
      if maybe_expand_history_shorthand_21(router, session) then
        return nil
      else
        refresh_prompt_highlights_21(session)
        maybe_show_directive_help_21(session)
        maybe_trigger_directive_complete_21(session)
        return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
      end
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session["prompt-buf"], _153_)
    local function _155_(ev)
      local item = (ev and (type(ev) == "table") and ev.completed_item)
      return maybe_show_directive_help_21(session, item)
    end
    au_21("CompleteChanged", session["prompt-buf"], _155_)
    local function _156_()
      return maybe_show_directive_help_21(session)
    end
    au_21("CompleteDone", session["prompt-buf"], _156_)
    local function _157_()
      events.send("on-insert-enter!", {session = session})
      apply_keymaps(router, session)
      return apply_emacs_insert_fallbacks(router, session)
    end
    au_21("InsertEnter", session["prompt-buf"], _157_)
    local function _158_()
      return events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session["prompt-buf"], _158_)
    local function _159_()
      events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
      return maybe_show_directive_help_21(session)
    end
    au_21({"ModeChanged", "InsertEnter", "InsertLeave"}, session["prompt-buf"], _159_)
    local function _160_()
      return maybe_show_directive_help_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session["prompt-buf"], _160_)
    local function _161_()
      return hide_directive_help_21(session)
    end
    au_21({"BufLeave", "WinLeave"}, session["prompt-buf"], _161_)
    local function _162_(ev)
      if not session["handling-layout-change?"] then
        do
          local is_vim_resized_3f = (ev.event == "VimResized")
          local wins
          local _164_
          do
            local t_163_ = vim.v
            if (nil ~= t_163_) then
              t_163_ = t_163_.event
            else
            end
            if (nil ~= t_163_) then
              t_163_ = t_163_.windows
            else
            end
            _164_ = t_163_
          end
          wins = (_164_ or {})
          local manual_prompt_resize = (not is_vim_resized_3f and manual_prompt_resize_3f(session, wins))
          if is_vim_resized_3f then
            session["preview-user-resized?"] = false
          else
          end
          do
            local editor_size_changed_3f = (((session["last-editor-columns"] or vim.o.columns) ~= vim.o.columns) or ((session["last-editor-lines"] or vim.o.lines) ~= vim.o.lines))
            note_editor_size_21(session)
            if (is_vim_resized_3f or editor_size_changed_3f) then
              note_global_editor_resize_21(session)
            else
            end
            if (not is_vim_resized_3f and not editor_size_changed_3f and not session["preview-global-resize-token"] and session["preview-win"] and vim.api.nvim_win_is_valid(session["preview-win"])) then
              for _, wid in ipairs(wins) do
                if (wid == session["preview-win"]) then
                  session["preview-user-resized?"] = true
                else
                end
              end
            else
            end
          end
          if manual_prompt_resize then
            session["prompt-target-height"] = vim.api.nvim_win_get_height(session["prompt-win"])
            capture_expected_layout_21(session)
          else
            schedule_restore_expected_layout_21(session)
          end
        end
        session["handling-layout-change?"] = true
        local function _172_()
          if session_prompt_valid_3f(session) then
            do
              local results_wrap_3f = (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window) and vim.api.nvim_get_option_value("wrap", {win = session.meta.win.window}))
              if (results_wrap_3f and rebuild_source_set_21 and not session["project-mode"]) then
                pcall(rebuild_source_set_21, session)
                pcall(session.meta["on-update"], 0)
              else
              end
            end
            if not session["prompt-animating?"] then
              pcall(refresh_prompt_highlights_21, session)
              events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true})
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
        return vim.schedule(_172_)
      else
        return nil
      end
    end
    au_global_21({"VimResized", "WinResized"}, _162_)
    local function _178_(_)
      if not session["handling-layout-change?"] then
        session["handling-layout-change?"] = true
        local function _179_()
          if session_prompt_valid_3f(session) then
            if (session.meta and session.meta.win and vim.api.nvim_win_is_valid(session.meta.win.window) and (vim.api.nvim_get_current_win() == session.meta.win.window)) then
              local wrap_3f = clj.boolean(vim.api.nvim_get_option_value("wrap", {win = session.meta.win.window}))
              pcall(vim.api.nvim_set_option_value, "linebreak", wrap_3f, {win = session.meta.win.window})
              if (rebuild_source_set_21 and not session["project-mode"]) then
                pcall(rebuild_source_set_21, session)
                pcall(session.meta["on-update"], 0)
                events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true})
              else
              end
            else
            end
          else
          end
          session["handling-layout-change?"] = false
          return nil
        end
        return vim.schedule(_179_)
      else
        return nil
      end
    end
    au_global_21("OptionSet", _178_, {pattern = "wrap"})
    local function _184_()
      return maybe_sync_from_main_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session.meta.buf.buffer, _184_)
    local function _185_(_)
      return begin_direct_results_edit_21(session)
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _185_)
    local function _186_(_)
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
        local function _188_()
          if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            pcall(router["sync-live-edits"], session["prompt-buf"])
            pcall(maybe_sync_from_main_21, session, true)
            return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true, ["refresh-signs?"] = true})
          else
            return nil
          end
        end
        return vim.schedule(_188_)
      else
        return nil
      end
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session.meta.buf.buffer, _186_)
    local function _191_(_)
      if (not session.closing and session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
        local bo = vim.bo[session.meta.buf.buffer]
        bo["buftype"] = "acwrite"
        bo["modifiable"] = true
        bo["readonly"] = false
        bo["bufhidden"] = "hide"
      else
      end
      if maybe_restore_hidden_ui_21 then
        local function _193_()
          if (not session.closing and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            return pcall(maybe_restore_hidden_ui_21, session)
          else
            return nil
          end
        end
        return vim.schedule(_193_)
      else
        return nil
      end
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _191_)
    local function _196_(_)
      local function _197_()
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
      return vim.defer_fn(_197_, 20)
    end
    au_global_21("WinNew", _196_)
    local function _200_(ev)
      local function _201_()
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
      return vim.defer_fn(_201_, 20)
    end
    au_global_21("BufWinEnter", _200_)
    local function _204_()
      return events.send("on-selection-change!", {session = session, ["line-nr"] = (1 + (session.meta.selected_index or 0)), ["refresh-lines"] = false})
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _204_)
    local function _205_(_)
      local function _206_()
        if (session["ui-hidden"] and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session) and not hidden_session_reachable_3f(session)) then
          return pcall(router["remove-session"], session)
        else
          return nil
        end
      end
      return vim.schedule(_206_)
    end
    au_global_21({"BufEnter", "WinEnter", "FocusGained"}, _205_)
    local function _208_(_)
      local function _209_()
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
      return vim.schedule(_209_)
    end
    au_buf_21("BufLeave", session.meta.buf.buffer, _208_)
    apply_main_keymaps(router, session)
    apply_results_edit_keymaps(session)
    local function _214_(ev)
      local function _215_()
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
              return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true})
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
      return vim.schedule(_215_)
    end
    au_global_21("BufWritePost", _214_)
    local function _225_(_)
      return schedule_scroll_sync_21(session)
    end
    au_global_21("WinScrolled", _225_)
    local function _226_(_)
      return router["write-results"](session["prompt-buf"])
    end
    au_buf_21("BufWriteCmd", session.meta.buf.buffer, _226_)
    local function _227_(_)
      local function _228_()
        return router["results-buffer-wiped"](session.meta.buf.buffer)
      end
      return vim.schedule(_228_)
    end
    au_buf_21("BufWipeout", session.meta.buf.buffer, _227_)
    refresh_prompt_highlights_21(session)
    maybe_show_directive_help_21(session)
    local function _229_()
      if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
        pcall(refresh_prompt_highlights_21, session)
        return capture_expected_layout_21(session)
      else
        return nil
      end
    end
    vim.defer_fn(_229_, prompt_animation_delay_ms(session))
    apply_keymaps(router, session)
    return apply_emacs_insert_fallbacks(router, session)
  end
  return {["register!"] = register_21, ["refresh!"] = refresh_prompt_highlights_21, ["loading!"] = schedule_loading_indicator_21}
end
return M
