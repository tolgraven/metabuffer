-- [nfnl] fnl/metabuffer/prompt/hooks.fnl
local M = {}
local animation_mod = require("metabuffer.window.animation")
local prompt_view_mod = require("metabuffer.buffer.prompt_view")
local events = require("metabuffer.events")
local hooks_directive_mod = require("metabuffer.prompt.hooks_directive")
local hooks_keymaps_mod = require("metabuffer.prompt.hooks_keymaps")
local hooks_layout_mod = require("metabuffer.prompt.hooks_layout")
local hooks_results_mod = require("metabuffer.prompt.hooks_results")
local loading_state_mod = require("metabuffer.widgets.loading_state")
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
  local refresh_prompt_highlights_21 = nil
  local schedule_loading_indicator_21 = nil
  local prompt_view
  local function _6_(session)
    if schedule_loading_indicator_21 then
      return schedule_loading_indicator_21(session)
    else
      return nil
    end
  end
  prompt_view = prompt_view_mod.new({["option-prefix"] = option_prefix, ["session-prompt-valid?"] = session_prompt_valid_3f, ["schedule-loading-indicator!"] = _6_})
  local directive_hooks = hooks_directive_mod.new({["option-prefix"] = option_prefix, ["highlight-prompt-like-line!"] = prompt_view["highlight-like-line!"]})
  local keymap_hooks = hooks_keymaps_mod.new({["default-prompt-keymaps"] = default_prompt_keymaps, ["default-main-keymaps"] = default_main_keymaps, ["schedule-when-valid"] = schedule_when_valid, ["switch-mode"] = switch_mode, ["sign-mod"] = sign_mod})
  local hide_directive_help_21 = directive_hooks["hide-directive-help!"]
  local maybe_show_directive_help_21 = directive_hooks["maybe-show-directive-help!"]
  local maybe_trigger_directive_complete_21 = directive_hooks["maybe-trigger-directive-complete!"]
  local apply_keymaps = keymap_hooks["apply-keymaps"]
  local apply_emacs_insert_fallbacks = keymap_hooks["apply-emacs-insert-fallbacks"]
  local apply_main_keymaps = keymap_hooks["apply-main-keymaps"]
  local apply_results_edit_keymaps = keymap_hooks["apply-results-edit-keymaps"]
  local begin_direct_results_edit_21 = keymap_hooks["begin-direct-results-edit!"]
  local loading_hooks
  local function _8_(session)
    return refresh_prompt_highlights_21(session)
  end
  loading_hooks = loading_state_mod.new({["session-prompt-valid?"] = session_prompt_valid_3f, ["animation-enabled?"] = animation_enabled_3f, ["animation-duration-ms"] = animation_duration_ms, ["refresh-prompt-highlights!"] = _8_})
  local loading_scheduler = loading_hooks["schedule-loading-indicator!"]
  local layout_hooks
  local function _9_(session)
    return refresh_prompt_highlights_21(session)
  end
  layout_hooks = hooks_layout_mod.new({["session-prompt-valid?"] = session_prompt_valid_3f, ["capture-expected-layout!"] = capture_expected_layout_21, ["note-editor-size!"] = note_editor_size_21, ["note-global-editor-resize!"] = note_global_editor_resize_21, ["manual-prompt-resize?"] = manual_prompt_resize_3f, ["schedule-restore-expected-layout!"] = schedule_restore_expected_layout_21, ["refresh-prompt-highlights!"] = _9_, ["rebuild-source-set!"] = rebuild_source_set_21})
  local handle_global_resize_21 = layout_hooks["handle-global-resize!"]
  local handle_wrap_option_set_21 = layout_hooks["handle-wrap-option-set!"]
  local results_hooks = hooks_results_mod.new({["active-by-prompt"] = active_by_prompt, ["sign-mod"] = sign_mod, ["maybe-sync-from-main!"] = maybe_sync_from_main_21, ["schedule-scroll-sync!"] = schedule_scroll_sync_21, ["maybe-restore-hidden-ui!"] = maybe_restore_hidden_ui_21, ["hide-visible-ui!"] = hide_visible_ui_21, ["rebuild-source-set!"] = rebuild_source_set_21, ["covered-by-new-window?"] = covered_by_new_window_3f, ["transient-overlay-buffer?"] = transient_overlay_buffer_3f, ["first-window-for-buffer"] = first_window_for_buffer, ["hidden-session-reachable?"] = hidden_session_reachable_3f, ["begin-direct-results-edit!"] = begin_direct_results_edit_21})
  local handle_results_cursor_21 = results_hooks["handle-results-cursor!"]
  local handle_results_edit_enter_21 = results_hooks["handle-results-edit-enter!"]
  local handle_results_text_changed_21 = results_hooks["handle-results-text-changed!"]
  local handle_results_focus_21 = results_hooks["handle-results-focus!"]
  local handle_overlay_winnew_21 = results_hooks["handle-overlay-winnew!"]
  local handle_overlay_bufwinenter_21 = results_hooks["handle-overlay-bufwinenter!"]
  local handle_selection_focus_21 = results_hooks["handle-selection-focus!"]
  local handle_hidden_session_gc_21 = results_hooks["handle-hidden-session-gc!"]
  local handle_results_leave_21 = results_hooks["handle-results-leave!"]
  local handle_external_write_21 = results_hooks["handle-external-write!"]
  local handle_scroll_sync_21 = results_hooks["handle-scroll-sync!"]
  local handle_results_writecmd_21 = results_hooks["handle-results-writecmd!"]
  local handle_results_wipeout_21 = results_hooks["handle-results-wipeout!"]
  refresh_prompt_highlights_21 = prompt_view["refresh-highlights!"]
  schedule_loading_indicator_21 = loading_scheduler
  local function maybe_expand_history_shorthand_21(router, session)
    if session["_expanding-history-shorthand"] then
      return false
    else
      if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        local _let_10_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
        local row = _let_10_[1]
        local col = _let_10_[2]
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
            local _15_
            if (trigger == "!^!") then
              _15_ = 3
            else
              _15_ = 2
            end
            start_col = (col - _15_)
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
  local function register_21(router, session)
    local aug = vim.api.nvim_create_augroup(("MetaPrompt" .. session["prompt-buf"]), {clear = true})
    session.augroup = aug
    capture_expected_layout_21(session)
    local function au_21(events0, buf, body)
      local function _22_(_)
        return schedule_when_valid(session, body)
      end
      return vim.api.nvim_create_autocmd(events0, {group = aug, buffer = buf, callback = _22_})
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
    local function _23_(_, _0, changedtick, _1, _2, _3, _4, _5)
      local function _24_()
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
      return vim.schedule(_24_)
    end
    local function _27_()
      if session["prompt-buf"] then
        active_by_prompt[session["prompt-buf"]] = nil
        return nil
      else
        return nil
      end
    end
    vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _23_, on_detach = _27_})
    local function _29_(_)
      if maybe_expand_history_shorthand_21(router, session) then
        return nil
      else
        refresh_prompt_highlights_21(session)
        maybe_show_directive_help_21(session)
        maybe_trigger_directive_complete_21(session)
        return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
      end
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session["prompt-buf"], _29_)
    local function _31_(ev)
      local item = (ev and (type(ev) == "table") and ev.completed_item)
      return maybe_show_directive_help_21(session, item)
    end
    au_21("CompleteChanged", session["prompt-buf"], _31_)
    local function _32_()
      return maybe_show_directive_help_21(session)
    end
    au_21("CompleteDone", session["prompt-buf"], _32_)
    local function _33_()
      events.send("on-insert-enter!", {session = session})
      apply_keymaps(router, session)
      return apply_emacs_insert_fallbacks(router, session)
    end
    au_21("InsertEnter", session["prompt-buf"], _33_)
    local function _34_()
      return events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session["prompt-buf"], _34_)
    local function _35_()
      events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
      return maybe_show_directive_help_21(session)
    end
    au_21({"ModeChanged", "InsertEnter", "InsertLeave"}, session["prompt-buf"], _35_)
    local function _36_()
      return maybe_show_directive_help_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session["prompt-buf"], _36_)
    local function _37_()
      return hide_directive_help_21(session)
    end
    au_21({"BufLeave", "WinLeave"}, session["prompt-buf"], _37_)
    local function _38_(ev)
      return handle_global_resize_21(session, ev)
    end
    au_global_21({"VimResized", "WinResized"}, _38_)
    local function _39_(_)
      return handle_wrap_option_set_21(session)
    end
    au_global_21("OptionSet", _39_, {pattern = "wrap"})
    local function _40_()
      return handle_results_cursor_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session.meta.buf.buffer, _40_)
    local function _41_(_)
      return handle_results_edit_enter_21(session)
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _41_)
    local function _42_(_)
      return handle_results_text_changed_21(router, session)
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session.meta.buf.buffer, _42_)
    local function _43_(_)
      return handle_results_focus_21(session)
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _43_)
    local function _44_(_)
      return handle_overlay_winnew_21(session)
    end
    au_global_21("WinNew", _44_)
    local function _45_(ev)
      return handle_overlay_bufwinenter_21(session, ev)
    end
    au_global_21("BufWinEnter", _45_)
    local function _46_()
      return handle_selection_focus_21(session)
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _46_)
    local function _47_(_)
      return handle_hidden_session_gc_21(router, session)
    end
    au_global_21({"BufEnter", "WinEnter", "FocusGained"}, _47_)
    local function _48_(_)
      return handle_results_leave_21(router, session)
    end
    au_buf_21("BufLeave", session.meta.buf.buffer, _48_)
    apply_main_keymaps(router, session)
    apply_results_edit_keymaps(session)
    local function _49_(ev)
      return handle_external_write_21(router, session, ev)
    end
    au_global_21("BufWritePost", _49_)
    local function _50_(_)
      return handle_scroll_sync_21(session)
    end
    au_global_21("WinScrolled", _50_)
    local function _51_(_)
      return handle_results_writecmd_21(router, session)
    end
    au_buf_21("BufWriteCmd", session.meta.buf.buffer, _51_)
    local function _52_(_)
      return handle_results_wipeout_21(router, session)
    end
    au_buf_21("BufWipeout", session.meta.buf.buffer, _52_)
    refresh_prompt_highlights_21(session)
    maybe_show_directive_help_21(session)
    local function _53_()
      if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
        pcall(refresh_prompt_highlights_21, session)
        return capture_expected_layout_21(session)
      else
        return nil
      end
    end
    vim.defer_fn(_53_, prompt_animation_delay_ms(session))
    apply_keymaps(router, session)
    return apply_emacs_insert_fallbacks(router, session)
  end
  return {["register!"] = register_21, ["refresh!"] = refresh_prompt_highlights_21, ["loading!"] = schedule_loading_indicator_21}
end
return M
