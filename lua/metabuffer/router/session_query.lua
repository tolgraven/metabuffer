-- [nfnl] fnl/metabuffer/router/session_query.fnl
local transform_mod = require("metabuffer.transform")
local M = {}
M.new = function(opts)
  local _let_1_ = (opts or {})
  local history_api = _let_1_["history-api"]
  local query_mod = _let_1_["query-mod"]
  local function expand_history_query(start_query)
    local latest_history = history_api["history-latest"](nil)
    if (start_query == "!!") then
      return latest_history
    elseif (start_query == "!$") then
      return history_api["history-entry-token"](latest_history)
    elseif (start_query == "!^!") then
      return history_api["history-entry-tail"](latest_history)
    else
      return start_query
    end
  end
  local function start_option_value(parsed_query, settings, parsed_key, settings_key)
    local val_113_auto = parsed_query[parsed_key]
    if (nil ~= val_113_auto) then
      local v = val_113_auto
      return v
    else
      return query_mod["truthy?"](settings[settings_key])
    end
  end
  local function prompt_query_text(parsed_query, expanded_query)
    local query0 = parsed_query.query
    local prompt_query0
    if (parsed_query["include-files"] ~= nil) then
      prompt_query0 = expanded_query
    else
      prompt_query0 = query0
    end
    local _5_
    if ((type(prompt_query0) == "string") and (prompt_query0 ~= "") and not vim.endswith(prompt_query0, " ") and not vim.endswith(prompt_query0, "\n")) then
      _5_ = (prompt_query0 .. " ")
    else
      _5_ = prompt_query0
    end
    return {query = query0, ["prompt-query"] = _5_}
  end
  local function resolve_start_query_state(query, settings)
    local start_query = (query or "")
    local expanded_query = expand_history_query(start_query)
    local parsed_query = query_mod["apply-default-source"](query_mod["parse-query-text"](expanded_query), query_mod["truthy?"](settings["default-include-lgrep"]))
    local _let_7_ = prompt_query_text(parsed_query, expanded_query)
    local query0 = _let_7_.query
    local prompt_query = _let_7_["prompt-query"]
    local start_transforms = transform_mod["enabled-map"](parsed_query, nil, settings)
    return {["parsed-query"] = parsed_query, query = query0, ["prompt-query"] = prompt_query, ["start-hidden"] = start_option_value(parsed_query, settings, "include-hidden", "default-include-hidden"), ["start-ignored"] = start_option_value(parsed_query, settings, "include-ignored", "default-include-ignored"), ["start-deps"] = start_option_value(parsed_query, settings, "include-deps", "default-include-deps"), ["start-binary"] = start_option_value(parsed_query, settings, "include-binary", "default-include-binary"), ["start-files"] = start_option_value(parsed_query, settings, "include-files", "default-include-files"), ["start-prefilter"] = start_option_value(parsed_query, settings, "prefilter", "project-lazy-prefilter-enabled"), ["start-lazy"] = start_option_value(parsed_query, settings, "lazy", "project-lazy-enabled"), ["start-expansion"] = (parsed_query.expansion or "none"), ["start-transforms"] = start_transforms}
  end
  return {["resolve-start-query-state"] = resolve_start_query_state}
end
return M
