-- [nfnl] fnl/metabuffer/prompt/hooks.fnl
local M = {}
local animation_mod = require("metabuffer.window.animation")
local prompt_view_mod = require("metabuffer.buffer.prompt_view")
local events = require("metabuffer.events")
local hooks_directive_mod = require("metabuffer.prompt.hooks_directive")
local hooks_keymaps_mod = require("metabuffer.prompt.hooks_keymaps")
local hooks_layout_mod = require("metabuffer.prompt.hooks_layout")
local hooks_registry_mod = require("metabuffer.prompt.hooks_registry")
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
  local registry_hooks
  local function _10_(session)
    return refresh_prompt_highlights_21(session)
  end
  local function _11_(session)
    return schedule_loading_indicator_21(session)
  end
  registry_hooks = hooks_registry_mod.new({["active-by-prompt"] = active_by_prompt, ["on-prompt-changed"] = on_prompt_changed, ["session-prompt-valid?"] = session_prompt_valid_3f, ["schedule-when-valid"] = schedule_when_valid, ["prompt-animation-delay-ms"] = prompt_animation_delay_ms, ["refresh-prompt-highlights!"] = _10_, ["schedule-loading-indicator!"] = _11_, ["maybe-show-directive-help!"] = maybe_show_directive_help_21, ["maybe-trigger-directive-complete!"] = maybe_trigger_directive_complete_21, ["hide-directive-help!"] = hide_directive_help_21, ["apply-keymaps"] = apply_keymaps, ["apply-emacs-insert-fallbacks"] = apply_emacs_insert_fallbacks, ["apply-main-keymaps"] = apply_main_keymaps, ["apply-results-edit-keymaps"] = apply_results_edit_keymaps, ["capture-expected-layout!"] = capture_expected_layout_21, ["handle-global-resize!"] = handle_global_resize_21, ["handle-wrap-option-set!"] = handle_wrap_option_set_21, ["handle-results-cursor!"] = handle_results_cursor_21, ["handle-results-edit-enter!"] = handle_results_edit_enter_21, ["handle-results-text-changed!"] = handle_results_text_changed_21, ["handle-results-focus!"] = handle_results_focus_21, ["handle-overlay-winnew!"] = handle_overlay_winnew_21, ["handle-overlay-bufwinenter!"] = handle_overlay_bufwinenter_21, ["handle-selection-focus!"] = handle_selection_focus_21, ["handle-hidden-session-gc!"] = handle_hidden_session_gc_21, ["handle-results-leave!"] = handle_results_leave_21, ["handle-external-write!"] = handle_external_write_21, ["handle-scroll-sync!"] = handle_scroll_sync_21, ["handle-results-writecmd!"] = handle_results_writecmd_21, ["handle-results-wipeout!"] = handle_results_wipeout_21})
  local register_21 = registry_hooks["register!"]
  return {["register!"] = register_21, ["refresh!"] = refresh_prompt_highlights_21, ["loading!"] = schedule_loading_indicator_21}
end
return M
