-- [nfnl] fnl/metabuffer/prompt/hooks_autocmds.fnl
local events = require("metabuffer.events")
local M = {}
M.new = function(opts)
  local _let_1_ = (opts or {})
  local active_by_prompt = _let_1_["active-by-prompt"]
  local prompt_animation_delay_ms = _let_1_["prompt-animation-delay-ms"]
  local refresh_prompt_highlights_21 = _let_1_["refresh-prompt-highlights!"]
  local maybe_expand_history_shorthand_21 = _let_1_["maybe-expand-history-shorthand!"]
  local on_prompt_changed = _let_1_["on-prompt-changed"]
  local maybe_show_directive_help_21 = _let_1_["maybe-show-directive-help!"]
  local maybe_trigger_directive_complete_21 = _let_1_["maybe-trigger-directive-complete!"]
  local hide_directive_help_21 = _let_1_["hide-directive-help!"]
  local apply_keymaps = _let_1_["apply-keymaps"]
  local apply_emacs_insert_fallbacks = _let_1_["apply-emacs-insert-fallbacks"]
  local apply_main_keymaps = _let_1_["apply-main-keymaps"]
  local apply_results_edit_keymaps = _let_1_["apply-results-edit-keymaps"]
  local capture_expected_layout_21 = _let_1_["capture-expected-layout!"]
  local handle_global_resize_21 = _let_1_["handle-global-resize!"]
  local handle_wrap_option_set_21 = _let_1_["handle-wrap-option-set!"]
  local handle_results_cursor_21 = _let_1_["handle-results-cursor!"]
  local handle_results_edit_enter_21 = _let_1_["handle-results-edit-enter!"]
  local handle_results_text_changed_21 = _let_1_["handle-results-text-changed!"]
  local handle_results_focus_21 = _let_1_["handle-results-focus!"]
  local handle_overlay_winnew_21 = _let_1_["handle-overlay-winnew!"]
  local handle_overlay_bufwinenter_21 = _let_1_["handle-overlay-bufwinenter!"]
  local handle_selection_focus_21 = _let_1_["handle-selection-focus!"]
  local handle_hidden_session_gc_21 = _let_1_["handle-hidden-session-gc!"]
  local handle_results_leave_21 = _let_1_["handle-results-leave!"]
  local handle_external_write_21 = _let_1_["handle-external-write!"]
  local handle_scroll_sync_21 = _let_1_["handle-scroll-sync!"]
  local handle_results_writecmd_21 = _let_1_["handle-results-writecmd!"]
  local handle_results_wipeout_21 = _let_1_["handle-results-wipeout!"]
  local function attach_prompt_buffer_21(router, session)
    local function _2_(_, _0, changedtick, _1, _2, _3, _4, _5)
      local function _3_()
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
      return vim.schedule(_3_)
    end
    local function _6_()
      if session["prompt-buf"] then
        active_by_prompt[session["prompt-buf"]] = nil
        return nil
      else
        return nil
      end
    end
    return vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _2_, on_detach = _6_})
  end
  local function register_prompt_autocmds_21(router, session, au_21, au_buf_21)
    local function _8_(_)
      if maybe_expand_history_shorthand_21(router, session) then
        return nil
      else
        refresh_prompt_highlights_21(session)
        maybe_show_directive_help_21(session)
        maybe_trigger_directive_complete_21(session)
        return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
      end
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session["prompt-buf"], _8_)
    local function _10_(ev)
      local item = (ev and (type(ev) == "table") and ev.completed_item)
      return maybe_show_directive_help_21(session, item)
    end
    au_21("CompleteChanged", session["prompt-buf"], _10_)
    local function _11_()
      return maybe_show_directive_help_21(session)
    end
    au_21("CompleteDone", session["prompt-buf"], _11_)
    local function _12_()
      events.send("on-insert-enter!", {session = session})
      apply_keymaps(router, session)
      return apply_emacs_insert_fallbacks(router, session)
    end
    au_21("InsertEnter", session["prompt-buf"], _12_)
    local function _13_()
      return events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
    end
    au_21({"BufEnter", "WinEnter", "FocusGained"}, session["prompt-buf"], _13_)
    local function _14_()
      events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
      return maybe_show_directive_help_21(session)
    end
    au_21({"ModeChanged", "InsertEnter", "InsertLeave"}, session["prompt-buf"], _14_)
    local function _15_()
      return maybe_show_directive_help_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session["prompt-buf"], _15_)
    local function _16_()
      return hide_directive_help_21(session)
    end
    return au_21({"BufLeave", "WinLeave"}, session["prompt-buf"], _16_)
  end
  local function register_global_autocmds_21(router, session, au_global_21)
    local function _17_(ev)
      return handle_global_resize_21(session, ev)
    end
    au_global_21({"VimResized", "WinResized"}, _17_)
    local function _18_(_)
      return handle_wrap_option_set_21(session)
    end
    au_global_21("OptionSet", _18_, {pattern = "wrap"})
    local function _19_(_)
      return handle_overlay_winnew_21(session)
    end
    au_global_21("WinNew", _19_)
    local function _20_(ev)
      return handle_overlay_bufwinenter_21(session, ev)
    end
    au_global_21("BufWinEnter", _20_)
    local function _21_(_)
      return handle_hidden_session_gc_21(router, session)
    end
    au_global_21({"BufEnter", "WinEnter", "FocusGained"}, _21_)
    local function _22_(ev)
      return handle_external_write_21(router, session, ev)
    end
    au_global_21("BufWritePost", _22_)
    local function _23_(_)
      return handle_scroll_sync_21(session)
    end
    return au_global_21("WinScrolled", _23_)
  end
  local function register_results_autocmds_21(router, session, au_21, au_buf_21)
    local function _24_()
      return handle_results_cursor_21(session)
    end
    au_21({"CursorMoved", "CursorMovedI"}, session.meta.buf.buffer, _24_)
    local function _25_(_)
      return handle_results_edit_enter_21(session)
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _25_)
    local function _26_(_)
      return handle_results_text_changed_21(router, session)
    end
    au_buf_21({"TextChanged", "TextChangedI"}, session.meta.buf.buffer, _26_)
    local function _27_(_)
      return handle_results_focus_21(session)
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _27_)
    local function _28_()
      return handle_selection_focus_21(session)
    end
    au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _28_)
    local function _29_(_)
      return handle_results_leave_21(router, session)
    end
    au_buf_21("BufLeave", session.meta.buf.buffer, _29_)
    local function _30_(_)
      return handle_results_writecmd_21(router, session)
    end
    au_buf_21("BufWriteCmd", session.meta.buf.buffer, _30_)
    local function _31_(_)
      return handle_results_wipeout_21(router, session)
    end
    return au_buf_21("BufWipeout", session.meta.buf.buffer, _31_)
  end
  local function finalize_registration_21(router, session)
    refresh_prompt_highlights_21(session)
    maybe_show_directive_help_21(session)
    local function _32_()
      if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
        pcall(refresh_prompt_highlights_21, session)
        return capture_expected_layout_21(session)
      else
        return nil
      end
    end
    vim.defer_fn(_32_, prompt_animation_delay_ms(session))
    apply_keymaps(router, session)
    apply_emacs_insert_fallbacks(router, session)
    apply_main_keymaps(router, session)
    return apply_results_edit_keymaps(session)
  end
  return {["attach-prompt-buffer!"] = attach_prompt_buffer_21, ["register-prompt-autocmds!"] = register_prompt_autocmds_21, ["register-global-autocmds!"] = register_global_autocmds_21, ["register-results-autocmds!"] = register_results_autocmds_21, ["finalize-registration!"] = finalize_registration_21}
end
return M
