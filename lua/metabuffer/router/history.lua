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
M.new = function(opts)
  local history_store = opts["history-store"]
  local router_util_mod = opts["router-util-mod"]
  local query_mod = opts["query-mod"]
  local history_browser_window = opts["history-browser-window"]
  local settings = opts.settings
  local api = {}
  api["history-entry-query"] = function(entry)
    local parsed = query_mod["parse-query-text"](entry)
    return (parsed.query or "")
  end
  api["history-entry-token"] = function(entry)
    local parts = vim.split(api["history-entry-query"](entry), "%s+", {trimempty = true})
    if (#parts > 0) then
      return parts[#parts]
    else
      return ""
    end
  end
  api["history-entry-tail"] = function(entry)
    local parts = vim.split(api["history-entry-query"](entry), "%s+", {trimempty = true})
    if (#parts > 1) then
      return table.concat(vim.list_slice(parts, 2), " ")
    else
      return ""
    end
  end
  api["history-entry-with-settings"] = function(session, prompt)
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
  api["push-history-entry!"] = function(session, text)
    return history_store["push!"](api["history-entry-with-settings"](session, text), settings["history-max"])
  end
  api["merge-history-into-session!"] = function(session)
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
  api["save-current-prompt-tag!"] = function(_session, tag, prompt)
    if ((type(tag) == "string") and (vim.trim(tag) ~= "") and (type(prompt) == "string") and (vim.trim(prompt) ~= "")) then
      return history_store["save-tag!"](tag, prompt)
    else
      return nil
    end
  end
  api["restore-saved-prompt-tag!"] = function(session, tag)
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
  api["history-browser-filter"] = function(session)
    return vim.trim((router_util_mod["prompt-text"](session) or ""))
  end
  api["history-browser-items"] = function(session)
    local mode = (session["history-browser-mode"] or "history")
    local filter0 = string.lower(api["history-browser-filter"](session))
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
      local h = (session["history-cache"] or history_store.list())
      for i = #h, 1, -1 do
        local entry = (h[i] or "")
        local hay = string.lower(entry)
        if ((filter0 == "") or (nil ~= string.find(hay, filter0, 1, true))) then
          table.insert(out, {label = entry, prompt = entry})
        else
        end
      end
    end
    return out
  end
  api["refresh-history-browser!"] = function(session)
    if (session and history_browser_window and session["history-browser-active"]) then
      session["history-browser-filter"] = api["history-browser-filter"](session)
      return history_browser_window["refresh!"](session, api["history-browser-items"](session))
    else
      return nil
    end
  end
  api["close-history-browser!"] = function(session)
    if history_browser_window then
      return history_browser_window["close!"](session)
    else
      return nil
    end
  end
  api["open-history-browser!"] = function(session, mode)
    if history_browser_window then
      history_browser_window["open!"](session, (mode or "history"))
      return api["refresh-history-browser!"](session)
    else
      return nil
    end
  end
  api["apply-history-browser-selection!"] = function(session)
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
      return api["close-history-browser!"](session)
    else
      return nil
    end
  end
  api["history-latest"] = function(session)
    local h = ((session and session["history-cache"]) or history_store.list())
    local n = #h
    if (n > 0) then
      return h[n]
    else
      return ""
    end
  end
  api["history-latest-token"] = function(session)
    return api["history-entry-token"](api["history-latest"](session))
  end
  api["history-latest-tail"] = function(session)
    return api["history-entry-tail"](api["history-latest"](session))
  end
  api["last-prompt-entry"] = function(prompt_buf, active_by_prompt)
    return api["history-latest"](active_by_prompt[prompt_buf])
  end
  api["last-prompt-token"] = function(prompt_buf, active_by_prompt)
    return api["history-latest-token"](active_by_prompt[prompt_buf])
  end
  api["last-prompt-tail"] = function(prompt_buf, active_by_prompt)
    return api["history-latest-tail"](active_by_prompt[prompt_buf])
  end
  api["saved-prompt-entry"] = function(tag)
    return history_store["saved-entry"](tag)
  end
  api["history-or-move"] = function(prompt_buf, delta, active_by_prompt, move_selection_fn)
    local session = active_by_prompt[prompt_buf]
    if session then
      if session["history-browser-active"] then
        return history_browser_window["move!"](session, delta)
      else
        local txt = router_util_mod["prompt-text"](session)
        local can_history = ((txt == "") or (txt == session["initial-prompt-text"]) or (txt == session["last-history-text"]) or (txt == api["history-entry-query"](session["last-history-text"])))
        if can_history then
          local h = (session["history-cache"] or history_store.list())
          local n = #h
          if (n > 0) then
            session["history-index"] = math.max(0, math.min((session["history-index"] + delta), n))
            if (session["history-index"] == 0) then
              session["last-history-text"] = ""
              router_util_mod["set-prompt-text!"](session, session["initial-prompt-text"])
            else
              local entry = h[((n - session["history-index"]) + 1)]
              if entry then
                session["last-history-text"] = entry
                router_util_mod["set-prompt-text!"](session, entry)
              else
              end
            end
          else
          end
          return move_selection_fn(prompt_buf, delta)
        else
          return nil
        end
      end
    else
      return nil
    end
  end
  api["open-history-searchback"] = function(prompt_buf, active_by_prompt)
    local session = active_by_prompt[prompt_buf]
    if session then
      if not session["history-cache"] then
        session["history-cache"] = vim.deepcopy(history_store.list())
      else
      end
      return api["open-history-browser!"](session, "history")
    else
      return nil
    end
  end
  api["merge-history-cache"] = function(prompt_buf, active_by_prompt)
    local session = active_by_prompt[prompt_buf]
    if session then
      api["merge-history-into-session!"](session)
      return api["refresh-history-browser!"](session)
    else
      return nil
    end
  end
  api["insert-last-prompt"] = function(prompt_buf, active_by_prompt, prompt_insert_at_cursor_21)
    local session = active_by_prompt[prompt_buf]
    local entry = api["history-latest"](session)
    prompt_insert_at_cursor_21(session, entry)
    if (session and (entry ~= "")) then
      session["last-history-text"] = entry
      return nil
    else
      return nil
    end
  end
  api["insert-last-token"] = function(prompt_buf, active_by_prompt, prompt_insert_at_cursor_21)
    local session = active_by_prompt[prompt_buf]
    local token = api["history-latest-token"](session)
    local entry = api["history-latest"](session)
    prompt_insert_at_cursor_21(session, token)
    if (session and (token ~= "")) then
      session["last-history-text"] = entry
      return nil
    else
      return nil
    end
  end
  api["insert-last-tail"] = function(prompt_buf, active_by_prompt, prompt_insert_at_cursor_21)
    local session = active_by_prompt[prompt_buf]
    local tail = api["history-latest-tail"](session)
    local entry = api["history-latest"](session)
    prompt_insert_at_cursor_21(session, tail)
    if (session and (tail ~= "")) then
      session["last-history-text"] = entry
      return nil
    else
      return nil
    end
  end
  return api
end
return M
