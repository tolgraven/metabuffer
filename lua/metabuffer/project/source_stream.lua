-- [nfnl] fnl/metabuffer/project/source_stream.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local M = {}
local debug = require("metabuffer.debug")
M.new = function(opts)
  local settings = opts.settings
  local truthy_3f = opts["truthy?"]
  local session_active_3f = opts["session-active?"]
  local lazy_streaming_allowed_3f = opts["lazy-streaming-allowed?"]
  local prompt_has_active_query_3f = opts["prompt-has-active-query?"]
  local now_ms = opts["now-ms"]
  local prompt_update_delay_ms = opts["prompt-update-delay-ms"]
  local schedule_prompt_update_21 = opts["schedule-prompt-update!"]
  local on_prompt_changed = opts["on-prompt-changed"]
  local apply_prompt_lines_now_21 = opts["apply-prompt-lines-now!"]
  local stream_next_path_21 = opts["stream-next-path!"]
  local emit_source_pool_change_21 = opts["emit-source-pool-change!"]
  local maybe_finish_project_stream_21 = opts["maybe-finish-project-stream!"]
  local apply_source_set_21 = opts["apply-source-set!"]
  local set_single_source_content_21 = opts["set-single-source-content!"]
  local function lazy_preferred_3f(session, estimated_lines)
    return (lazy_streaming_allowed_3f(session) and truthy_3f(session["lazy-mode"]) and ((session["project-mode"] and not session["project-bootstrapped"] and not prompt_has_active_query_3f(session)) or (settings["project-lazy-min-estimated-lines"] <= 0) or (estimated_lines >= settings["project-lazy-min-estimated-lines"])))
  end
  local function start_project_stream_21(session, prefilter, init)
    session["lazy-stream-id"] = (1 + (session["lazy-stream-id"] or 0))
    session["lazy-last-render-ms"] = now_ms()
    debug.log("project-source", ("start-stream" .. " stream-id=" .. tostring((1 + (session["lazy-stream-id"] or 0))) .. " bootstrapped=" .. tostring(clj.boolean(session["project-bootstrapped"])) .. " token=" .. tostring((session["project-bootstrap-token"] or 0)) .. " hits=" .. tostring(#((session.meta and session.meta.buf and session.meta.buf.indices) or {}))))
    session["lazy-stream-done"] = false
    session["lazy-stream-next"] = 1
    session["lazy-stream-paths"] = (init["deferred-paths"] or {})
    session["lazy-stream-total"] = #session["lazy-stream-paths"]
    session["lazy-prefilter"] = prefilter
    local stream_id = session["lazy-stream-id"]
    local run_batch0 = nil
    local run_batch = run_batch0
    local function _1_()
      if (session_active_3f(session) and (stream_id == session["lazy-stream-id"]) and not session["lazy-stream-done"]) then
        local paths = session["lazy-stream-paths"]
        local total = #paths
        local chunk = math.max(1, settings["project-lazy-chunk-size"])
        local frame_budget = math.max(1, (settings["project-lazy-frame-budget-ms"] or 6))
        local batch_start = now_ms()
        local consumed = 0
        local touched = false
        while ((consumed < chunk) and ((now_ms() - batch_start) < frame_budget) and (session["lazy-stream-next"] <= total) and (#session.meta.buf.content < settings["project-max-total-lines"])) do
          local path = paths[session["lazy-stream-next"]]
          if stream_next_path_21(session, path, prefilter) then
            touched = true
          else
          end
          consumed = (consumed + 1)
          session["lazy-stream-next"] = (session["lazy-stream-next"] + 1)
        end
        if ((session["lazy-stream-next"] > total) or (#session.meta.buf.content >= settings["project-max-total-lines"])) then
          session["lazy-stream-done"] = true
        else
        end
        maybe_finish_project_stream_21(session)
        if touched then
          local _4_
          if prompt_has_active_query_3f(session) then
            _4_ = nil
          else
            _4_ = "bootstrap"
          end
          emit_source_pool_change_21(session, {phase = _4_, ["refresh-lines"] = false})
        else
        end
        if (not session["lazy-stream-done"] and (stream_id == session["lazy-stream-id"]) and session_active_3f(session)) then
          return vim.defer_fn(run_batch, 17)
        else
          return nil
        end
      else
        return nil
      end
    end
    run_batch = _1_
    return vim.defer_fn(run_batch, 0)
  end
  local function schedule_source_set_rebuild_21(session, wait_ms)
    if (session and not session.closing) then
      session["source-set-rebuild-token"] = (1 + (session["source-set-rebuild-token"] or 0))
      local token = session["source-set-rebuild-token"]
      session["source-set-rebuild-pending"] = true
      local function _9_()
        if (session and (token == session["source-set-rebuild-token"])) then
          session["source-set-rebuild-pending"] = false
        else
        end
        if (session and (token == session["source-set-rebuild-token"]) and session["prompt-buf"] and session_active_3f(session) and not session.closing) then
          apply_source_set_21(session)
          if apply_prompt_lines_now_21 then
            return apply_prompt_lines_now_21(session)
          else
            return on_prompt_changed(session["prompt-buf"], true)
          end
        else
          return nil
        end
      end
      return vim.defer_fn(_9_, math.max(0, (wait_ms or 0)))
    else
      return nil
    end
  end
  local function apply_minimal_source_set_21(session)
    local meta = session.meta
    local old_line
    if (meta.selected_index and (meta.selected_index >= 0) and ((meta.selected_index + 1) <= #meta.buf.indices)) then
      old_line = math.max(1, meta.selected_line())
    else
      old_line = math.max(1, (session["initial-source-line"] or 1))
    end
    session["lazy-stream-id"] = (1 + (session["lazy-stream-id"] or 0))
    session["lazy-stream-done"] = true
    set_single_source_content_21(session, false)
    meta.selected_index = math.max(0, (meta.buf["closest-index"](old_line) - 1))
    meta._prev_text = ""
    meta["_filter-cache"] = {}
    meta["_filter-cache-line-count"] = #meta.buf.content
    return nil
  end
  local function schedule_project_bootstrap_21(session, wait_ms)
    if (session and session["project-mode"] and not session["project-bootstrapped"]) then
      session["project-bootstrap-token"] = (1 + (session["project-bootstrap-token"] or 0))
      local token = session["project-bootstrap-token"]
      local delay = math.max(0, (wait_ms or session["project-bootstrap-delay-ms"] or settings["project-bootstrap-delay-ms"] or 0))
      debug.log("project-source", ("schedule-bootstrap" .. " token=" .. tostring(token) .. " delay=" .. tostring(delay) .. " hidden=" .. tostring(clj.boolean(session["ui-hidden"])) .. " restoring=" .. tostring(clj.boolean(session["restoring-ui?"])) .. " prompt=" .. tostring((session["prompt-last-event-text"] or ""))))
      session["project-bootstrap-pending"] = true
      local run_bootstrap_21
      local function _15_()
        if (session and (token == session["project-bootstrap-token"])) then
          session["project-bootstrap-pending"] = false
        else
        end
        if (session and (token == session["project-bootstrap-token"]) and session["project-mode"] and session["prompt-buf"] and session_active_3f(session) and not session["project-bootstrapped"]) then
          local has_query = prompt_has_active_query_3f(session)
          apply_source_set_21(session)
          emit_source_pool_change_21(session, {phase = "bootstrap", ["force?"] = true, ["refresh-lines"] = true})
          session["project-bootstrapped"] = true
          if has_query then
            session["prompt-update-dirty"] = true
            local now = now_ms()
            local quiet_for = (now - (session["prompt-last-change-ms"] or 0))
            local need_quiet = math.max(0, prompt_update_delay_ms(session))
            if (quiet_for < need_quiet) then
              schedule_prompt_update_21(session, math.max(1, (need_quiet - quiet_for)))
            else
              schedule_prompt_update_21(session, 0)
            end
          else
          end
          if not has_query then
            emit_source_pool_change_21(session, {phase = "complete", ["force?"] = true, ["restore-view?"] = true, ["refresh-lines"] = true})
          else
          end
          session["project-mode-starting?"] = false
          return nil
        else
          return nil
        end
      end
      run_bootstrap_21 = _15_
      return vim.defer_fn(run_bootstrap_21, delay)
    else
      return nil
    end
  end
  return {["lazy-preferred?"] = lazy_preferred_3f, ["start-project-stream!"] = start_project_stream_21, ["schedule-source-set-rebuild!"] = schedule_source_set_rebuild_21, ["apply-minimal-source-set!"] = apply_minimal_source_set_21, ["schedule-project-bootstrap!"] = schedule_project_bootstrap_21}
end
return M
