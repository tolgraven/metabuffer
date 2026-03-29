-- [nfnl] fnl/metabuffer/prompt/hooks.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local animation_mod = require("metabuffer.window.animation")
local highlight_util = require("metabuffer.highlight_util")
local prompt_view_mod = require("metabuffer.buffer.prompt_view")
local events = require("metabuffer.events")
local hooks_directive_mod = require("metabuffer.prompt.hooks_directive")
local hooks_window_mod = require("metabuffer.prompt.hooks_window")
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
  local hl_rendered_bg = highlight_util["hl-rendered-bg"]
  local darken_rgb = highlight_util["darken-rgb"]
  local brighten_rgb = highlight_util["brighten-rgb"]
  local copy_highlight_with_bg = highlight_util["copy-highlight-with-bg"]
  local function session_busy_3f(session)
    return (session and (session["prompt-update-pending"] or session["prompt-update-dirty"] or session["project-bootstrap-pending"] or (session["project-mode"] and not session["lazy-stream-done"]) or (session["project-mode"] and not session["project-bootstrapped"])))
  end
  local function session_actually_idle_3f(session)
    return (session and not session_busy_3f(session) and not session["prompt-update-dirty"])
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
    return copy_highlight_with_bg(group, bg)
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
  local prompt_view
  local function _8_(session)
    if schedule_loading_indicator_21 then
      return schedule_loading_indicator_21(session)
    else
      return nil
    end
  end
  prompt_view = prompt_view_mod.new({["option-prefix"] = option_prefix, ["session-prompt-valid?"] = session_prompt_valid_3f, ["schedule-loading-indicator!"] = _8_})
  local directive_hooks = hooks_directive_mod.new({["option-prefix"] = option_prefix, ["highlight-prompt-like-line!"] = prompt_view["highlight-like-line!"]})
  local hide_directive_help_21 = directive_hooks["hide-directive-help!"]
  local maybe_show_directive_help_21 = directive_hooks["maybe-show-directive-help!"]
  local maybe_trigger_directive_complete_21 = directive_hooks["maybe-trigger-directive-complete!"]
  refresh_prompt_highlights_21 = prompt_view["refresh-highlights!"]
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
  local function _15_(session)
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
      local function _18_()
        return loading_indicator_tick_21(session)
      end
      return vim.defer_fn(_18_, delay)
    else
      return nil
    end
  end
  schedule_loading_indicator_21 = _15_
  local function maybe_expand_history_shorthand_21(router, session)
    if session["_expanding-history-shorthand"] then
      return false
    else
      if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        local _let_20_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
        local row = _let_20_[1]
        local col = _let_20_[2]
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
            local _25_
            if (trigger == "!^!") then
              _25_ = 3
            else
              _25_ = 2
            end
            start_col = (col - _25_)
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
      local function _32_()
        return router.accept(session["prompt-buf"])
      end
      return _32_
    elseif (action == "enter-edit-mode") then
      local function _33_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _33_
    elseif (action == "cancel") then
      local function _34_()
        return router.cancel(session["prompt-buf"])
      end
      return _34_
    elseif (action == "move-selection") then
      local function _35_()
        return router["move-selection"](session["prompt-buf"], arg)
      end
      return _35_
    elseif (action == "history-or-move") then
      local function _36_()
        return router["history-or-move"](session["prompt-buf"], arg)
      end
      return _36_
    elseif (action == "prompt-home") then
      local function _37_()
        local function _38_()
          return router["prompt-home"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _38_)
      end
      return _37_
    elseif (action == "prompt-end") then
      local function _39_()
        local function _40_()
          return router["prompt-end"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _40_)
      end
      return _39_
    elseif (action == "prompt-kill-backward") then
      local function _41_()
        local function _42_()
          return router["prompt-kill-backward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _42_)
      end
      return _41_
    elseif (action == "prompt-kill-forward") then
      local function _43_()
        local function _44_()
          return router["prompt-kill-forward"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _44_)
      end
      return _43_
    elseif (action == "prompt-yank") then
      local function _45_()
        local function _46_()
          return router["prompt-yank"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _46_)
      end
      return _45_
    elseif (action == "prompt-newline") then
      local function _47_()
        local function _48_()
          return router["prompt-newline"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _48_)
      end
      return _47_
    elseif (action == "insert-last-prompt") then
      local function _49_()
        local function _50_()
          return router["insert-last-prompt"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _50_)
      end
      return _49_
    elseif (action == "insert-last-token") then
      local function _51_()
        local function _52_()
          return router["insert-last-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _52_)
      end
      return _51_
    elseif (action == "insert-last-tail") then
      local function _53_()
        local function _54_()
          return router["insert-last-tail"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _54_)
      end
      return _53_
    elseif (action == "toggle-prompt-results-focus") then
      local function _55_()
        local function _56_()
          return router["toggle-prompt-results-focus"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _56_)
      end
      return _55_
    elseif (action == "negate-current-token") then
      local function _57_()
        local function _58_()
          return router["negate-current-token"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _58_)
      end
      return _57_
    elseif (action == "history-searchback") then
      local function _59_()
        local function _60_()
          return router["open-history-searchback"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _60_)
      end
      return _59_
    elseif (action == "merge-history") then
      local function _61_()
        local function _62_()
          return router["merge-history-cache"](session["prompt-buf"])
        end
        return schedule_when_valid(session, _62_)
      end
      return _61_
    elseif (action == "switch-mode") then
      local function _63_()
        return switch_mode(session, arg)
      end
      return _63_
    elseif (action == "toggle-scan-option") then
      local function _64_()
        return router["toggle-scan-option"](session["prompt-buf"], arg)
      end
      return _64_
    elseif (action == "scroll-main") then
      local function _65_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _65_
    elseif (action == "toggle-project-mode") then
      local function _66_()
        return router["toggle-project-mode"](session["prompt-buf"])
      end
      return _66_
    elseif (action == "toggle-info-file-entry-view") then
      local function _67_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _67_
    elseif (action == "refresh-files") then
      local function _68_()
        return router["refresh-files"](session["prompt-buf"])
      end
      return _68_
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
      local function _73_()
        return router.cancel(session["prompt-buf"])
      end
      return _73_
    elseif (action == "accept-main") then
      local function _74_()
        return router["accept-main"](session["prompt-buf"])
      end
      return _74_
    elseif (action == "enter-edit-mode") then
      local function _75_()
        return router["enter-edit-mode"](session["prompt-buf"])
      end
      return _75_
    elseif (action == "exclude-symbol-under-cursor") then
      local function _76_()
        return router["exclude-symbol-under-cursor"](session["prompt-buf"])
      end
      return _76_
    elseif (action == "insert-symbol-under-cursor") then
      local function _77_()
        return router["insert-symbol-under-cursor"](session["prompt-buf"])
      end
      return _77_
    elseif (action == "insert-symbol-under-cursor-newline") then
      local function _78_()
        return router["insert-symbol-under-cursor-newline"](session["prompt-buf"])
      end
      return _78_
    elseif (action == "toggle-prompt-results-focus") then
      local function _79_()
        return router["toggle-prompt-results-focus"](session["prompt-buf"])
      end
      return _79_
    elseif (action == "scroll-main") then
      local function _80_()
        return router["scroll-main"](session["prompt-buf"], arg)
      end
      return _80_
    elseif (action == "toggle-info-file-entry-view") then
      local function _81_()
        return router["toggle-info-file-entry-view"](session["prompt-buf"])
      end
      return _81_
    elseif (action == "refresh-files") then
      local function _82_()
        return router["refresh-files"](session["prompt-buf"])
      end
      return _82_
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
    local function _87_()
      set_pending_structural_edit_21(session, "after")
      return feed_results_normal_key_21("o")
    end
    vim.keymap.set("n", "o", _87_, opts0)
    local function _88_()
      set_pending_structural_edit_21(session, "before")
      return feed_results_normal_key_21("O")
    end
    vim.keymap.set("n", "O", _88_, opts0)
    local function _89_()
      set_pending_structural_edit_21(session, "after")
      return feed_results_normal_key_21("p")
    end
    vim.keymap.set("n", "p", _89_, opts0)
    local function _90_()
      set_pending_structural_edit_21(session, "before")
      return feed_results_normal_key_21("P")
    end
    return vim.keymap.set("n", "P", _90_, opts0)
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
      local function _93_(_)
        return schedule_when_valid(session, body)
      end
      return vim.api.nvim_create_autocmd(events0, {group = aug, buffer = buf, callback = _93_})
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
    local function _94_(_, _0, changedtick, _1, _2, _3, _4, _5)
      local function _95_()
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
      return vim.schedule(_95_)
    end
    local function _98_()
      if session["prompt-buf"] then
        active_by_prompt[session["prompt-buf"]] = nil
        return nil
      else
        return nil
      end
    end
    vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _94_, on_detach = _98_})
    local function _100_(_)
      if maybe_expand_history_shorthand_21(router, session) then
        return nil
      else
        refresh_prompt_highlights_21(session)
        maybe_show_directive_help_21(session)
        maybe_trigger_directive_complete_21(session)
        return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
      end
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session["prompt-buf"], _100_)
    local function _102_(ev)
      local item = (ev and (type(ev) == "table") and ev.completed_item)
      return maybe_show_directive_help_21(session, item)
    end
    au_21("CompleteChanged", session["prompt-buf"], _102_)
    local function _103_()
      return maybe_show_directive_help_21(session)
    end
    au_21("CompleteDone", session["prompt-buf"], _103_)
    local function _104_()
      events.send("on-insert-enter!", {session = session})
      apply_keymaps(router, session)
      return apply_emacs_insert_fallbacks(router, session)
    end
    au_21("InsertEnter", session["prompt-buf"], _104_)
    local function _105_()
      return events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session["prompt-buf"], _105_)
    local function _106_()
      events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
      return maybe_show_directive_help_21(session)
    end
    au_21({"ModeChanged", "InsertEnter", "InsertLeave"}, session["prompt-buf"], _106_)
    local function _107_()
      return maybe_show_directive_help_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session["prompt-buf"], _107_)
    local function _108_()
      return hide_directive_help_21(session)
    end
    au_21({"BufLeave", "WinLeave"}, session["prompt-buf"], _108_)
    local function _109_(ev)
      if not session["handling-layout-change?"] then
        do
          local is_vim_resized_3f = (ev.event == "VimResized")
          local wins
          local _111_
          do
            local t_110_ = vim.v
            if (nil ~= t_110_) then
              t_110_ = t_110_.event
            else
            end
            if (nil ~= t_110_) then
              t_110_ = t_110_.windows
            else
            end
            _111_ = t_110_
          end
          wins = (_111_ or {})
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
        local function _119_()
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
        return vim.schedule(_119_)
      else
        return nil
      end
    end
    au_global_21({"VimResized", "WinResized"}, _109_)
    local function _125_(_)
      if not session["handling-layout-change?"] then
        session["handling-layout-change?"] = true
        local function _126_()
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
        return vim.schedule(_126_)
      else
        return nil
      end
    end
    au_global_21("OptionSet", _125_, {pattern = "wrap"})
    local function _131_()
      return maybe_sync_from_main_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session.meta.buf.buffer, _131_)
    local function _132_(_)
      return begin_direct_results_edit_21(session)
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _132_)
    local function _133_(_)
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
        local function _135_()
          if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            pcall(router["sync-live-edits"], session["prompt-buf"])
            pcall(maybe_sync_from_main_21, session, true)
            return events.send("on-query-update!", {session = session, query = (session["prompt-last-applied-text"] or ""), ["refresh-lines"] = true, ["refresh-signs?"] = true})
          else
            return nil
          end
        end
        return vim.schedule(_135_)
      else
        return nil
      end
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session.meta.buf.buffer, _133_)
    local function _138_(_)
      if (not session.closing and session.meta and session.meta.buf and vim.api.nvim_buf_is_valid(session.meta.buf.buffer)) then
        local bo = vim.bo[session.meta.buf.buffer]
        bo["buftype"] = "acwrite"
        bo["modifiable"] = true
        bo["readonly"] = false
        bo["bufhidden"] = "hide"
      else
      end
      if maybe_restore_hidden_ui_21 then
        local function _140_()
          if (not session.closing and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
            return pcall(maybe_restore_hidden_ui_21, session)
          else
            return nil
          end
        end
        return vim.schedule(_140_)
      else
        return nil
      end
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _138_)
    local function _143_(_)
      local function _144_()
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
      return vim.defer_fn(_144_, 20)
    end
    au_global_21("WinNew", _143_)
    local function _147_(ev)
      local function _148_()
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
      return vim.defer_fn(_148_, 20)
    end
    au_global_21("BufWinEnter", _147_)
    local function _151_()
      return events.send("on-selection-change!", {session = session, ["line-nr"] = (1 + (session.meta.selected_index or 0)), ["refresh-lines"] = false})
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _151_)
    local function _152_(_)
      local function _153_()
        if (session["ui-hidden"] and session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session) and not hidden_session_reachable_3f(session)) then
          return pcall(router["remove-session"], session)
        else
          return nil
        end
      end
      return vim.schedule(_153_)
    end
    au_global_21({"BufEnter", "WinEnter", "FocusGained"}, _152_)
    local function _155_(_)
      local function _156_()
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
      return vim.schedule(_156_)
    end
    au_buf_21("BufLeave", session.meta.buf.buffer, _155_)
    apply_main_keymaps(router, session)
    apply_results_edit_keymaps(session)
    local function _161_(ev)
      local function _162_()
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
      return vim.schedule(_162_)
    end
    au_global_21("BufWritePost", _161_)
    local function _172_(_)
      return schedule_scroll_sync_21(session)
    end
    au_global_21("WinScrolled", _172_)
    local function _173_(_)
      return router["write-results"](session["prompt-buf"])
    end
    au_buf_21("BufWriteCmd", session.meta.buf.buffer, _173_)
    local function _174_(_)
      local function _175_()
        return router["results-buffer-wiped"](session.meta.buf.buffer)
      end
      return vim.schedule(_175_)
    end
    au_buf_21("BufWipeout", session.meta.buf.buffer, _174_)
    refresh_prompt_highlights_21(session)
    maybe_show_directive_help_21(session)
    local function _176_()
      if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
        pcall(refresh_prompt_highlights_21, session)
        return capture_expected_layout_21(session)
      else
        return nil
      end
    end
    vim.defer_fn(_176_, prompt_animation_delay_ms(session))
    apply_keymaps(router, session)
    return apply_emacs_insert_fallbacks(router, session)
  end
  return {["register!"] = register_21, ["refresh!"] = refresh_prompt_highlights_21, ["loading!"] = schedule_loading_indicator_21}
end
return M
