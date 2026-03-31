-- [nfnl] fnl/metabuffer/router/history.fnl
local M = {}
local function project_setting_token(name, enabled)
  local _1_
  if enabled then
    _1_ = "+"
  else
    _1_ = "-"
  end
  return ("#" .. _1_ .. name)
end
local function changed_setting_token(query_mod, name, enabled, default_enabled)
  local on_3f = query_mod["truthy?"](enabled)
  local default_on_3f = query_mod["truthy?"](default_enabled)
  if (on_3f ~= default_on_3f) then
    return project_setting_token(name, on_3f)
  else
    return nil
  end
end
local function explicit_setting_present_3f(parsed, key)
  return (parsed[key] ~= nil)
end
local function history_entry_query(query_mod, entry)
  local parsed = query_mod["parse-query-text"](entry)
  return (parsed.query or "")
end
local function history_entry_token(query_mod, entry)
  local parts = vim.split(history_entry_query(query_mod, entry), "%s+", {trimempty = true})
  if (#parts > 0) then
    return parts[#parts]
  else
    return ""
  end
end
local function history_entry_tail(query_mod, entry)
  local parts = vim.split(history_entry_query(query_mod, entry), "%s+", {trimempty = true})
  if (#parts > 1) then
    return table.concat(vim.list_slice(parts, 2), " ")
  else
    return ""
  end
end
local function history_entry_with_settings(query_mod, settings, session, prompt)
  local query_text = (prompt or "")
  local parsed = query_mod["parse-query-text"](query_text)
  local seen = {}
  local tokens = {}
  local _
  for _0, part in ipairs(vim.split(query_text, "%s+", {trimempty = true})) do
    if ((type(part) == "string") and (part ~= "")) then
      seen[part] = true
    else
    end
  end
  _ = nil
  local _0
  if (session and session["project-mode"]) then
    local defaults = settings
    do
      local val_110_auto = changed_setting_token(query_mod, "hidden", session["effective-include-hidden"], defaults["default-include-hidden"])
      if val_110_auto then
        local tok = val_110_auto
        if (not explicit_setting_present_3f(parsed, "include-hidden") and not seen[tok]) then
          table.insert(tokens, tok)
        else
        end
      else
      end
    end
    do
      local val_110_auto = changed_setting_token(query_mod, "ignored", session["effective-include-ignored"], defaults["default-include-ignored"])
      if val_110_auto then
        local tok = val_110_auto
        if (not explicit_setting_present_3f(parsed, "include-ignored") and not seen[tok]) then
          table.insert(tokens, tok)
        else
        end
      else
      end
    end
    do
      local val_110_auto = changed_setting_token(query_mod, "deps", session["effective-include-deps"], defaults["default-include-deps"])
      if val_110_auto then
        local tok = val_110_auto
        if (not explicit_setting_present_3f(parsed, "include-deps") and not seen[tok]) then
          table.insert(tokens, tok)
        else
        end
      else
      end
    end
    do
      local val_110_auto = changed_setting_token(query_mod, "prefilter", session["prefilter-mode"], defaults["project-lazy-prefilter-enabled"])
      if val_110_auto then
        local tok = val_110_auto
        if (not explicit_setting_present_3f(parsed, "prefilter") and not seen[tok]) then
          table.insert(tokens, tok)
        else
        end
      else
      end
    end
    local val_110_auto = changed_setting_token(query_mod, "lazy", session["lazy-mode"], defaults["project-lazy-enabled"])
    if val_110_auto then
      local tok = val_110_auto
      if (not explicit_setting_present_3f(parsed, "lazy") and not seen[tok]) then
        _0 = table.insert(tokens, tok)
      else
        _0 = nil
      end
    else
      _0 = nil
    end
  else
    _0 = nil
  end
  local prefix
  if (#tokens > 0) then
    prefix = table.concat(tokens, " ")
  else
    prefix = ""
  end
  if (prefix == "") then
    return query_text
  else
    if (query_text == "") then
      return prefix
    else
      return (prefix .. " " .. query_text)
    end
  end
end
local function merge_history_into_session_21(history_store, settings, session)
  local local0 = (session["history-cache"] or {})
  local merged = vim.deepcopy(local0)
  local incoming = history_store.list()
  local seen = {}
  for _, item in ipairs(merged) do
    if (type(item) == "string") then
      seen[item] = true
    else
    end
  end
  for _, item in ipairs(incoming) do
    if ((type(item) == "string") and (vim.trim(item) ~= "") and not seen[item]) then
      table.insert(merged, item)
      seen[item] = true
    else
    end
  end
  while (#merged > settings["history-max"]) do
    table.remove(merged, 1)
  end
  session["history-cache"] = merged
  return nil
end
local function history_browser_filter(router_util_mod, session)
  return vim.trim((router_util_mod["prompt-text"](session) or ""))
end
local function history_browser_items(history_store, router_util_mod, session)
  local mode = (session["history-browser-mode"] or "history")
  local filter0 = string.lower(history_browser_filter(router_util_mod, session))
  local out = {}
  if (mode == "saved") then
    for _, item in ipairs(history_store["saved-items"]()) do
      local tag = (item.tag or "")
      local prompt = (item.prompt or "")
      local hay = string.lower((tag .. " " .. prompt))
      if ((filter0 == "") or (nil ~= string.find(hay, filter0, 1, true))) then
        table.insert(out, {label = ("##" .. tag .. "  " .. prompt), prompt = prompt, tag = tag})
      else
      end
    end
  else
  end
  if (mode ~= "saved") then
    local h = (session["history-cache"] or history_store.list())
    for i = #h, 1, -1 do
      local entry = (h[i] or "")
      local hay = string.lower(entry)
      if ((filter0 == "") or (nil ~= string.find(hay, filter0, 1, true))) then
        table.insert(out, {label = entry, prompt = entry})
      else
      end
    end
  else
  end
  return out
end
local function history_latest(history_store, session)
  local h = ((session and session["history-cache"]) or history_store.list())
  local n = #h
  if (n > 0) then
    return h[n]
  else
    return ""
  end
end
local function history_or_move_21(history_store, history_browser_window, router_util_mod, query_mod, prompt_buf, delta, active_by_prompt, move_selection_fn)
  local session = active_by_prompt[prompt_buf]
  if session then
    if session["history-browser-active"] then
      return history_browser_window["move!"](session, delta)
    else
      local txt = router_util_mod["prompt-text"](session)
      local can_history = ((txt == "") or (txt == session["initial-prompt-text"]) or (txt == session["last-history-text"]) or (txt == history_entry_query(query_mod, session["last-history-text"])))
      if can_history then
        local h = (session["history-cache"] or history_store.list())
        local n = #h
        if (n > 0) then
          session["history-index"] = math.max(0, math.min((session["history-index"] + delta), n))
          if (session["history-index"] == 0) then
            session["last-history-text"] = ""
            return router_util_mod["set-prompt-text!"](session, session["initial-prompt-text"])
          else
            local entry = h[((n - session["history-index"]) + 1)]
            if entry then
              session["last-history-text"] = entry
              return router_util_mod["set-prompt-text!"](session, entry)
            else
              return nil
            end
          end
        else
          return nil
        end
      else
        return move_selection_fn(prompt_buf, delta)
      end
    end
  else
    return nil
  end
end
local function insert_history_fragment_21(history_store, query_mod, prompt_buf, active_by_prompt, prompt_insert_at_cursor_21, mode)
  local session = active_by_prompt[prompt_buf]
  local entry = history_latest(history_store, session)
  local text
  if (mode == "prompt") then
    text = entry
  else
    if (mode == "token") then
      text = history_entry_token(query_mod, entry)
    else
      text = history_entry_tail(query_mod, entry)
    end
  end
  prompt_insert_at_cursor_21(session, text)
  if (session and (text ~= "")) then
    session["last-history-text"] = entry
    return nil
  else
    return nil
  end
end
M.new = function(opts)
  local history_store = opts["history-store"]
  local router_util_mod = opts["router-util-mod"]
  local query_mod = opts["query-mod"]
  local history_browser_window = opts["history-browser-window"]
  local settings = opts.settings
  local function _37_(entry)
    return history_entry_query(query_mod, entry)
  end
  local function _38_(entry)
    return history_entry_token(query_mod, entry)
  end
  local function _39_(entry)
    return history_entry_tail(query_mod, entry)
  end
  local function _40_(session, prompt)
    return history_entry_with_settings(query_mod, settings, session, prompt)
  end
  local function _41_(session, text)
    return history_store["push!"](history_entry_with_settings(query_mod, settings, session, text), settings["history-max"])
  end
  local function _42_(session)
    return merge_history_into_session_21(history_store, settings, session)
  end
  local function _43_(_session, tag, prompt)
    if ((type(tag) == "string") and (vim.trim(tag) ~= "") and (type(prompt) == "string") and (vim.trim(prompt) ~= "")) then
      return history_store["save-tag!"](tag, prompt)
    else
      return nil
    end
  end
  local function _45_(session, tag)
    if (session and (type(tag) == "string") and (vim.trim(tag) ~= "")) then
      local val_110_auto = history_store["saved-entry"](tag)
      if val_110_auto then
        local saved = val_110_auto
        router_util_mod["set-prompt-text!"](session, saved)
        return true
      else
        return nil
      end
    else
      return nil
    end
  end
  local function _48_(session)
    return history_browser_filter(router_util_mod, session)
  end
  local function _49_(session)
    return history_browser_items(history_store, router_util_mod, session)
  end
  local function _50_(session)
    if (session and history_browser_window and session["history-browser-active"]) then
      session["history-browser-filter"] = history_browser_filter(router_util_mod, session)
      return history_browser_window["refresh!"](session, history_browser_items(history_store, router_util_mod, session))
    else
      return nil
    end
  end
  local function _52_(session)
    if history_browser_window then
      return history_browser_window["close!"](session)
    else
      return nil
    end
  end
  local function _54_(session, mode)
    if history_browser_window then
      history_browser_window["open!"](session, (mode or "history"))
      session["history-browser-filter"] = history_browser_filter(router_util_mod, session)
      return history_browser_window["refresh!"](session, history_browser_items(history_store, router_util_mod, session))
    else
      return nil
    end
  end
  local function _56_(session)
    if (history_browser_window and session["history-browser-active"]) then
      do
        local val_110_auto = history_browser_window["selected!"](session)
        if val_110_auto then
          local selected = val_110_auto
          local val_110_auto0 = selected.prompt
          if val_110_auto0 then
            local prompt = val_110_auto0
            router_util_mod["set-prompt-text!"](session, prompt)
          else
          end
        else
        end
      end
      return history_browser_window["close!"](session)
    else
      return nil
    end
  end
  local function _60_(session)
    return history_latest(history_store, session)
  end
  local function _61_(session)
    return history_entry_token(query_mod, history_latest(history_store, session))
  end
  local function _62_(session)
    return history_entry_tail(query_mod, history_latest(history_store, session))
  end
  local function _63_(prompt_buf, active_by_prompt)
    return history_latest(history_store, active_by_prompt[prompt_buf])
  end
  local function _64_(prompt_buf, active_by_prompt)
    return history_entry_token(query_mod, history_latest(history_store, active_by_prompt[prompt_buf]))
  end
  local function _65_(prompt_buf, active_by_prompt)
    return history_entry_tail(query_mod, history_latest(history_store, active_by_prompt[prompt_buf]))
  end
  local function _66_(tag)
    return history_store["saved-entry"](tag)
  end
  local function _67_(prompt_buf, delta, active_by_prompt, move_selection_fn)
    return history_or_move_21(history_store, history_browser_window, router_util_mod, query_mod, prompt_buf, delta, active_by_prompt, move_selection_fn)
  end
  local function _68_(prompt_buf, active_by_prompt)
    local session = active_by_prompt[prompt_buf]
    if session then
      if not session["history-cache"] then
        session["history-cache"] = vim.deepcopy(history_store.list())
      else
      end
      if history_browser_window then
        history_browser_window["open!"](session, "history")
        session["history-browser-filter"] = history_browser_filter(router_util_mod, session)
        return history_browser_window["refresh!"](session, history_browser_items(history_store, router_util_mod, session))
      else
        return nil
      end
    else
      return nil
    end
  end
  local function _72_(prompt_buf, active_by_prompt)
    local session = active_by_prompt[prompt_buf]
    if session then
      merge_history_into_session_21(history_store, settings, session)
      if (history_browser_window and session["history-browser-active"]) then
        session["history-browser-filter"] = history_browser_filter(router_util_mod, session)
        return history_browser_window["refresh!"](session, history_browser_items(history_store, router_util_mod, session))
      else
        return nil
      end
    else
      return nil
    end
  end
  local function _75_(prompt_buf, active_by_prompt, prompt_insert_at_cursor_21)
    return insert_history_fragment_21(history_store, query_mod, prompt_buf, active_by_prompt, prompt_insert_at_cursor_21, "prompt")
  end
  local function _76_(prompt_buf, active_by_prompt, prompt_insert_at_cursor_21)
    return insert_history_fragment_21(history_store, query_mod, prompt_buf, active_by_prompt, prompt_insert_at_cursor_21, "token")
  end
  local function _77_(prompt_buf, active_by_prompt, prompt_insert_at_cursor_21)
    return insert_history_fragment_21(history_store, query_mod, prompt_buf, active_by_prompt, prompt_insert_at_cursor_21, "tail")
  end
  return {["history-entry-query"] = _37_, ["history-entry-token"] = _38_, ["history-entry-tail"] = _39_, ["history-entry-with-settings"] = _40_, ["push-history-entry!"] = _41_, ["merge-history-into-session!"] = _42_, ["save-current-prompt-tag!"] = _43_, ["restore-saved-prompt-tag!"] = _45_, ["history-browser-filter"] = _48_, ["history-browser-items"] = _49_, ["refresh-history-browser!"] = _50_, ["close-history-browser!"] = _52_, ["open-history-browser!"] = _54_, ["apply-history-browser-selection!"] = _56_, ["history-latest"] = _60_, ["history-latest-token"] = _61_, ["history-latest-tail"] = _62_, ["last-prompt-entry"] = _63_, ["last-prompt-token"] = _64_, ["last-prompt-tail"] = _65_, ["saved-prompt-entry"] = _66_, ["history-or-move"] = _67_, ["open-history-searchback"] = _68_, ["merge-history-cache"] = _72_, ["insert-last-prompt"] = _75_, ["insert-last-token"] = _76_, ["insert-last-tail"] = _77_}
end
return M
