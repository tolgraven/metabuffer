-- [nfnl] fnl/metabuffer/router/session_state.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local session_builders_mod = require("metabuffer.router.session_builders")
local session_query_mod = require("metabuffer.router.session_query")
local M = {}
M.new = function(opts)
  local _let_1_ = (opts or {})
  local history_api = _let_1_["history-api"]
  local history_store = _let_1_["history-store"]
  local query_mod = _let_1_["query-mod"]
  local router_util_mod = _let_1_["router-util-mod"]
  local session_view = _let_1_["session-view"]
  local prompt_window_mod = _let_1_["prompt-window-mod"]
  local session_query = session_query_mod.new({["history-api"] = history_api, ["query-mod"] = query_mod})
  local resolve_start_query_state = session_query["resolve-start-query-state"]
  local session_builders = session_builders_mod.new({["history-store"] = history_store, ["query-mod"] = query_mod, ["router-util-mod"] = router_util_mod, ["prompt-window-mod"] = prompt_window_mod})
  local prompt_animates_3f = session_builders["prompt-animates?"]
  local build_prompt_window = session_builders["build-prompt-window"]
  local build_session_state = session_builders["build-session-state"]
  local function restored_hidden_session(router_state, maybe_restore_hidden_ui_21, source_buf, existing, project_mode)
    if (existing and existing["ui-hidden"] and maybe_restore_hidden_ui_21 and existing.meta and existing.meta.buf and (clj.boolean(existing["project-mode"]) == clj.boolean(project_mode)) and (source_buf == existing.meta.buf.buffer)) then
      router_util_mod["clear-file-caches!"](router_state, existing)
      maybe_restore_hidden_ui_21(existing, true)
      return existing.meta
    else
      return nil
    end
  end
  local function build_session_condition(query, mode, source_view, project_mode)
    local condition = session_view["setup-state"](query, mode, source_view)
    if (project_mode and (mode == "start")) then
      condition["selected-index"] = math.max(0, ((source_view.lnum or ((condition["selected-index"] or 0) + 1)) - 1))
    else
      condition["selected-index"] = (condition["selected-index"] or 0)
    end
    return condition
  end
  return {["resolve-start-query-state"] = resolve_start_query_state, ["prompt-animates?"] = prompt_animates_3f, ["restored-hidden-session"] = restored_hidden_session, ["build-session-condition"] = build_session_condition, ["build-prompt-window"] = build_prompt_window, ["build-session-state"] = build_session_state}
end
return M
