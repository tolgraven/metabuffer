-- [nfnl] fnl/metabuffer/prompt/hooks_results.fnl
local M = {}
local results_events_mod = require("metabuffer.prompt.hooks_results_events")
local results_windows_mod = require("metabuffer.prompt.hooks_results_windows")
M.new = function(opts)
  local active_by_prompt = opts["active-by-prompt"]
  local sign_mod = opts["sign-mod"]
  local maybe_sync_from_main_21 = opts["maybe-sync-from-main!"]
  local schedule_scroll_sync_21 = opts["schedule-scroll-sync!"]
  local maybe_restore_hidden_ui_21 = opts["maybe-restore-hidden-ui!"]
  local hide_visible_ui_21 = opts["hide-visible-ui!"]
  local rebuild_source_set_21 = opts["rebuild-source-set!"]
  local covered_by_new_window_3f = opts["covered-by-new-window?"]
  local transient_overlay_buffer_3f = opts["transient-overlay-buffer?"]
  local first_window_for_buffer = opts["first-window-for-buffer"]
  local hidden_session_reachable_3f = opts["hidden-session-reachable?"]
  local begin_direct_results_edit_21 = opts["begin-direct-results-edit!"]
  local event_hooks = results_events_mod.new({["active-by-prompt"] = active_by_prompt, ["maybe-sync-from-main!"] = maybe_sync_from_main_21, ["schedule-scroll-sync!"] = schedule_scroll_sync_21, ["begin-direct-results-edit!"] = begin_direct_results_edit_21, ["sign-mod"] = sign_mod})
  local session_active_3f = event_hooks["session-active?"]
  local emit_query_refresh_21 = event_hooks["emit-query-refresh!"]
  local handle_results_cursor_21 = event_hooks["handle-results-cursor!"]
  local handle_results_edit_enter_21 = event_hooks["handle-results-edit-enter!"]
  local handle_results_text_changed_21 = event_hooks["handle-results-text-changed!"]
  local handle_selection_focus_21 = event_hooks["handle-selection-focus!"]
  local handle_scroll_sync_21 = event_hooks["handle-scroll-sync!"]
  local window_hooks = results_windows_mod.new({["covered-by-new-window?"] = covered_by_new_window_3f, ["transient-overlay-buffer?"] = transient_overlay_buffer_3f, ["first-window-for-buffer"] = first_window_for_buffer, ["hidden-session-reachable?"] = hidden_session_reachable_3f, ["maybe-restore-hidden-ui!"] = maybe_restore_hidden_ui_21, ["hide-visible-ui!"] = hide_visible_ui_21, ["rebuild-source-set!"] = rebuild_source_set_21})
  local handle_results_focus0_21 = window_hooks["handle-results-focus!"]
  local handle_overlay_winnew0_21 = window_hooks["handle-overlay-winnew!"]
  local handle_overlay_bufwinenter0_21 = window_hooks["handle-overlay-bufwinenter!"]
  local handle_hidden_session_gc0_21 = window_hooks["handle-hidden-session-gc!"]
  local handle_results_leave_21 = window_hooks["handle-results-leave!"]
  local handle_external_write0_21 = window_hooks["handle-external-write!"]
  local function handle_results_focus_21(session)
    return handle_results_focus0_21(session, session_active_3f)
  end
  local function handle_overlay_winnew_21(session)
    return handle_overlay_winnew0_21(session, session_active_3f)
  end
  local function handle_overlay_bufwinenter_21(session, ev)
    return handle_overlay_bufwinenter0_21(session, ev, session_active_3f)
  end
  local function handle_hidden_session_gc_21(router, session)
    return handle_hidden_session_gc0_21(router, session, session_active_3f)
  end
  local function handle_external_write_21(router, session, ev)
    return handle_external_write0_21(router, session, ev, session_active_3f, emit_query_refresh_21)
  end
  local function handle_results_writecmd_21(router, session)
    return router["write-results"](session["prompt-buf"])
  end
  local function handle_results_wipeout_21(router, session)
    local function _1_()
      return router["results-buffer-wiped"](session.meta.buf.buffer)
    end
    return vim.schedule(_1_)
  end
  return {["handle-results-cursor!"] = handle_results_cursor_21, ["handle-results-edit-enter!"] = handle_results_edit_enter_21, ["handle-results-text-changed!"] = handle_results_text_changed_21, ["handle-results-focus!"] = handle_results_focus_21, ["handle-overlay-winnew!"] = handle_overlay_winnew_21, ["handle-overlay-bufwinenter!"] = handle_overlay_bufwinenter_21, ["handle-selection-focus!"] = handle_selection_focus_21, ["handle-hidden-session-gc!"] = handle_hidden_session_gc_21, ["handle-results-leave!"] = handle_results_leave_21, ["handle-external-write!"] = handle_external_write_21, ["handle-scroll-sync!"] = handle_scroll_sync_21, ["handle-results-writecmd!"] = handle_results_writecmd_21, ["handle-results-wipeout!"] = handle_results_wipeout_21}
end
return M
