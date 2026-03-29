-- [nfnl] fnl/metabuffer/prompt/hooks_registry.fnl
local M = {}
local events = require("metabuffer.events")
M.new = function(opts)
  local _let_1_ = (opts or {})
  local active_by_prompt = _let_1_["active-by-prompt"]
  local on_prompt_changed = _let_1_["on-prompt-changed"]
  local schedule_when_valid = _let_1_["schedule-when-valid"]
  local prompt_animation_delay_ms = _let_1_["prompt-animation-delay-ms"]
  local refresh_prompt_highlights_21 = _let_1_["refresh-prompt-highlights!"]
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
  local function maybe_expand_history_shorthand_21(router, session)
    if session["_expanding-history-shorthand"] then
      return false
    else
      if (session and session["prompt-buf"] and session["prompt-win"] and vim.api.nvim_buf_is_valid(session["prompt-buf"]) and vim.api.nvim_win_is_valid(session["prompt-win"])) then
        local _let_2_ = vim.api.nvim_win_get_cursor(session["prompt-win"])
        local row = _let_2_[1]
        local col = _let_2_[2]
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
            local _7_
            if (trigger == "!^!") then
              _7_ = 3
            else
              _7_ = 2
            end
            start_col = (col - _7_)
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
    local function au_21(evs, buf, body)
      local function _14_(_)
        return schedule_when_valid(session, body)
      end
      return vim.api.nvim_create_autocmd(evs, {group = aug, buffer = buf, callback = _14_})
    end
    local function au_buf_21(evs, buf, callback)
      return vim.api.nvim_create_autocmd(evs, {group = aug, buffer = buf, callback = callback})
    end
    local function au_global_21(evs, callback, _3fopts)
      local base = {group = aug, callback = callback}
      for k, v in pairs((_3fopts or {})) do
        base[k] = v
      end
      return vim.api.nvim_create_autocmd(evs, base)
    end
    local function attach_prompt_buffer_21()
      local function _15_(_, _0, changedtick, _1, _2, _3, _4, _5)
        local function _16_()
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
        return vim.schedule(_16_)
      end
      local function _19_()
        if session["prompt-buf"] then
          active_by_prompt[session["prompt-buf"]] = nil
          return nil
        else
          return nil
        end
      end
      return vim.api.nvim_buf_attach(session["prompt-buf"], false, {on_lines = _15_, on_detach = _19_})
    end
    local function register_prompt_autocmds_21()
      local function _21_(_)
        if maybe_expand_history_shorthand_21(router, session) then
          return nil
        else
          refresh_prompt_highlights_21(session)
          maybe_show_directive_help_21(session)
          maybe_trigger_directive_complete_21(session)
          return on_prompt_changed(session["prompt-buf"], false, vim.api.nvim_buf_get_changedtick(session["prompt-buf"]))
        end
      end
      au_buf_21({"TextChanged", "TextChangedI"}, session["prompt-buf"], _21_)
      local function _23_(ev)
        local item = (ev and (type(ev) == "table") and ev.completed_item)
        return maybe_show_directive_help_21(session, item)
      end
      au_21("CompleteChanged", session["prompt-buf"], _23_)
      local function _24_()
        return maybe_show_directive_help_21(session)
      end
      au_21("CompleteDone", session["prompt-buf"], _24_)
      local function _25_()
        events.send("on-insert-enter!", {session = session})
        apply_keymaps(router, session)
        return apply_emacs_insert_fallbacks(router, session)
      end
      au_21("InsertEnter", session["prompt-buf"], _25_)
      local function _26_()
        return events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
      end
      au_21({"BufEnter", "WinEnter", "FocusGained"}, session["prompt-buf"], _26_)
      local function _27_()
        events.post("on-prompt-focus!", {session = session}, {["supersede?"] = true, ["dedupe-key"] = ("on-prompt-focus:" .. tostring(session["prompt-buf"]))})
        return maybe_show_directive_help_21(session)
      end
      au_21({"ModeChanged", "InsertEnter", "InsertLeave"}, session["prompt-buf"], _27_)
      local function _28_()
        return maybe_show_directive_help_21(session)
      end
      au_21({"CursorMoved", "CursorMovedI"}, session["prompt-buf"], _28_)
      local function _29_()
        return hide_directive_help_21(session)
      end
      return au_21({"BufLeave", "WinLeave"}, session["prompt-buf"], _29_)
    end
    local function register_global_autocmds_21()
      local function _30_(ev)
        return handle_global_resize_21(session, ev)
      end
      au_global_21({"VimResized", "WinResized"}, _30_)
      local function _31_(_)
        return handle_wrap_option_set_21(session)
      end
      au_global_21("OptionSet", _31_, {pattern = "wrap"})
      local function _32_(_)
        return handle_overlay_winnew_21(session)
      end
      au_global_21("WinNew", _32_)
      local function _33_(ev)
        return handle_overlay_bufwinenter_21(session, ev)
      end
      au_global_21("BufWinEnter", _33_)
      local function _34_(_)
        return handle_hidden_session_gc_21(router, session)
      end
      au_global_21({"BufEnter", "WinEnter", "FocusGained"}, _34_)
      local function _35_(ev)
        return handle_external_write_21(router, session, ev)
      end
      au_global_21("BufWritePost", _35_)
      local function _36_(_)
        return handle_scroll_sync_21(session)
      end
      return au_global_21("WinScrolled", _36_)
    end
    local function register_results_autocmds_21()
      local function _37_()
        return handle_results_cursor_21(session)
      end
      au_21({"CursorMoved", "CursorMovedI"}, session.meta.buf.buffer, _37_)
      local function _38_(_)
        return handle_results_edit_enter_21(session)
      end
      au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _38_)
      local function _39_(_)
        return handle_results_text_changed_21(router, session)
      end
      au_buf_21({"TextChanged", "TextChangedI"}, session.meta.buf.buffer, _39_)
      local function _40_(_)
        return handle_results_focus_21(session)
      end
      au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _40_)
      local function _41_()
        return handle_selection_focus_21(session)
      end
      au_buf_21({"BufEnter", "WinEnter", "FocusGained"}, session.meta.buf.buffer, _41_)
      local function _42_(_)
        return handle_results_leave_21(router, session)
      end
      au_buf_21("BufLeave", session.meta.buf.buffer, _42_)
      local function _43_(_)
        return handle_results_writecmd_21(router, session)
      end
      au_buf_21("BufWriteCmd", session.meta.buf.buffer, _43_)
      local function _44_(_)
        return handle_results_wipeout_21(router, session)
      end
      return au_buf_21("BufWipeout", session.meta.buf.buffer, _44_)
    end
    local function finalize_registration_21()
      refresh_prompt_highlights_21(session)
      maybe_show_directive_help_21(session)
      local function _45_()
        if (session["prompt-buf"] and (active_by_prompt[session["prompt-buf"]] == session)) then
          pcall(refresh_prompt_highlights_21, session)
          return capture_expected_layout_21(session)
        else
          return nil
        end
      end
      vim.defer_fn(_45_, prompt_animation_delay_ms(session))
      apply_keymaps(router, session)
      apply_emacs_insert_fallbacks(router, session)
      apply_main_keymaps(router, session)
      return apply_results_edit_keymaps(session)
    end
    attach_prompt_buffer_21()
    register_prompt_autocmds_21()
    register_global_autocmds_21()
    register_results_autocmds_21()
    return finalize_registration_21()
  end
  return {["register!"] = register_21}
end
return M
