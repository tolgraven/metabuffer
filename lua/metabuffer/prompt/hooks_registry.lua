-- [nfnl] fnl/metabuffer/prompt/hooks_registry.fnl
local M = {}
local hooks_autocmds_mod = require("metabuffer.prompt.hooks_autocmds")
local hooks_history_expand_mod = require("metabuffer.prompt.hooks_history_expand")
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
  local history_expand = hooks_history_expand_mod.new({["active-by-prompt"] = active_by_prompt})
  local maybe_expand_history_shorthand_21 = history_expand["maybe-expand-history-shorthand!"]
  local autocmds = hooks_autocmds_mod.new({["active-by-prompt"] = active_by_prompt, ["schedule-when-valid"] = schedule_when_valid, ["prompt-animation-delay-ms"] = prompt_animation_delay_ms, ["refresh-prompt-highlights!"] = refresh_prompt_highlights_21, ["maybe-expand-history-shorthand!"] = maybe_expand_history_shorthand_21, ["on-prompt-changed"] = on_prompt_changed, ["maybe-show-directive-help!"] = maybe_show_directive_help_21, ["maybe-trigger-directive-complete!"] = maybe_trigger_directive_complete_21, ["hide-directive-help!"] = hide_directive_help_21, ["apply-keymaps"] = apply_keymaps, ["apply-emacs-insert-fallbacks"] = apply_emacs_insert_fallbacks, ["apply-main-keymaps"] = apply_main_keymaps, ["apply-results-edit-keymaps"] = apply_results_edit_keymaps, ["capture-expected-layout!"] = capture_expected_layout_21, ["handle-global-resize!"] = handle_global_resize_21, ["handle-wrap-option-set!"] = handle_wrap_option_set_21, ["handle-results-cursor!"] = handle_results_cursor_21, ["handle-results-edit-enter!"] = handle_results_edit_enter_21, ["handle-results-text-changed!"] = handle_results_text_changed_21, ["handle-results-focus!"] = handle_results_focus_21, ["handle-overlay-winnew!"] = handle_overlay_winnew_21, ["handle-overlay-bufwinenter!"] = handle_overlay_bufwinenter_21, ["handle-selection-focus!"] = handle_selection_focus_21, ["handle-hidden-session-gc!"] = handle_hidden_session_gc_21, ["handle-results-leave!"] = handle_results_leave_21, ["handle-external-write!"] = handle_external_write_21, ["handle-scroll-sync!"] = handle_scroll_sync_21, ["handle-results-writecmd!"] = handle_results_writecmd_21, ["handle-results-wipeout!"] = handle_results_wipeout_21})
  local attach_prompt_buffer_21 = autocmds["attach-prompt-buffer!"]
  local register_prompt_autocmds_21 = autocmds["register-prompt-autocmds!"]
  local register_global_autocmds_21 = autocmds["register-global-autocmds!"]
  local register_results_autocmds_21 = autocmds["register-results-autocmds!"]
  local finalize_registration_21 = autocmds["finalize-registration!"]
  local function register_21(router, session)
    local aug = vim.api.nvim_create_augroup(("MetaPrompt" .. session["prompt-buf"]), {clear = true})
    session.augroup = aug
    capture_expected_layout_21(session)
    local function au_21(evs, buf, body)
      local function _2_(_)
        return schedule_when_valid(session, body)
      end
      return vim.api.nvim_create_autocmd(evs, {group = aug, buffer = buf, callback = _2_})
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
    attach_prompt_buffer_21(router, session)
    register_prompt_autocmds_21(router, session, au_21, au_buf_21)
    register_global_autocmds_21(router, session, au_global_21)
    register_results_autocmds_21(router, session, au_21, au_buf_21)
    return finalize_registration_21(router, session)
  end
  return {["register!"] = register_21}
end
return M
