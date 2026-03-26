-- [nfnl] fnl/metabuffer/query/directive.fnl
local clj = require("io.gitlab.andreyorst.cljlib.core")
local file_source = require("metabuffer.source.file")
local lgrep_source = require("metabuffer.source.lgrep")
local scope_directives = require("metabuffer.query.scope")
local transform_directives = require("metabuffer.transform")
local prompt_directives = require("metabuffer.query.prompt_directives")
local M = {}
local directive_providers = {{type = "option", provider = prompt_directives}, {type = "scope", provider = scope_directives}, {type = "transform", provider = transform_directives}, {type = "source", provider = file_source}, {type = "source", provider = lgrep_source}}
local function split_directive_name(name)
  local txt = (name or "")
  local stem = (string.match(txt, "^([^:]+)") or txt)
  local suffix = (string.match(txt, "(:.+)$") or "")
  return {stem, suffix}
end
local function provider_specs()
  local out = {}
  for provider_idx, entry in ipairs(directive_providers) do
    local provider = entry.provider
    local provider_type = entry.type
    local function _1_()
      if (type(provider["query-directive-specs"]) == "function") then
        return {pcall(provider["query-directive-specs"])}
      else
        return {true, (provider["query-directive-specs"] or {})}
      end
    end
    local _let_2_ = _1_()
    local ok = _let_2_[1]
    local raw = _let_2_[2]
    local specs
    if (ok and (type(raw) == "table")) then
      specs = raw
    else
      specs = {}
    end
    for spec_idx, spec in ipairs(specs) do
      table.insert(out, vim.tbl_extend("force", spec, {["provider-type"] = provider_type, ["provider-idx"] = provider_idx, ["spec-idx"] = spec_idx}))
    end
  end
  return out
end
local function resolve_short_stems()
  local used = {}
  local entries = {}
  for _, spec in ipairs(provider_specs()) do
    local val_110_auto = spec.long
    if val_110_auto then
      local long_name = val_110_auto
      local _let_4_ = split_directive_name(long_name)
      local stem = _let_4_[1]
      if (stem ~= "") then
        if not entries[stem] then
          entries[stem] = {stem = stem, ["provider-idx"] = spec["provider-idx"], ["spec-idx"] = spec["spec-idx"]}
        else
        end
      else
      end
    else
    end
  end
  local ordered = {}
  for _, entry in pairs(entries) do
    table.insert(ordered, entry)
  end
  local function _8_(a, b)
    if ((a["provider-idx"] or 0) == (b["provider-idx"] or 0)) then
      return ((a["spec-idx"] or 0) < (b["spec-idx"] or 0))
    else
      return ((a["provider-idx"] or 0) < (b["provider-idx"] or 0))
    end
  end
  table.sort(ordered, _8_)
  local shorts = {}
  for _, entry in ipairs(ordered) do
    local stem = (entry.stem or "")
    for len = 1, #stem do
      if ((shorts[stem] == nil) and (used[string.sub(stem, 1, len)] == nil)) then
        local prefix = string.sub(stem, 1, len)
        used[prefix] = true
        shorts[stem] = prefix
      else
      end
    end
    if (shorts[stem] == nil) then
      shorts[stem] = stem
    else
    end
  end
  return shorts
end
local function all_specs()
  local out = {}
  do
    local short_stems = resolve_short_stems()
    for _, spec in ipairs(provider_specs()) do
      local long_name = (spec.long or "")
      local _let_12_ = split_directive_name(long_name)
      local stem = _let_12_[1]
      local suffix = _let_12_[2]
      local resolved_short
      if (stem ~= "") then
        resolved_short = ((short_stems[stem] or stem) .. suffix)
      else
        resolved_short = nil
      end
      table.insert(out, vim.tbl_extend("force", spec, {short = resolved_short}))
    end
  end
  return out
end
local function names_for_spec(spec)
  local out = {}
  local short = (spec.short or "")
  local long = (spec.long or "")
  if (short ~= "") then
    table.insert(out, short)
  else
  end
  if (long ~= "") then
    table.insert(out, long)
  else
  end
  return out
end
local function display_token(prefix, spec)
  local name = (spec.short or spec.long or "")
  local arg = (spec.arg or "")
  if ((spec.kind or "") == "literal") then
    return (spec.literal or "")
  elseif ((spec.kind or "") == "prefix-value") then
    return ((spec.prefix or "") .. arg)
  elseif ((spec.kind or "") == "suffix") then
    return (prefix .. name .. ":" .. arg)
  elseif "else" then
    local _16_
    if (arg ~= "") then
      _16_ = (" " .. arg)
    else
      _16_ = ""
    end
    return (prefix .. name .. _16_)
  else
    return nil
  end
end
local function helptext(prefix, spec)
  local long_name = (spec.long or "")
  local short_name = (spec.short or "")
  local label
  if ((spec.kind or "") == "literal") then
    label = (spec.literal or "")
  elseif ((spec.kind or "") == "prefix-value") then
    label = ((spec.prefix or "") .. (spec.arg or "{value}"))
  elseif (short_name == "") then
    local _19_
    if ((spec.arg or "") == "") then
      _19_ = ""
    else
      _19_ = (" " .. spec.arg)
    end
    label = (prefix .. long_name .. _19_)
  elseif "else" then
    local _21_
    if ((spec.arg or "") == "") then
      _21_ = ""
    else
      _21_ = (" " .. spec.arg)
    end
    local _23_
    if ((spec.arg or "") == "") then
      _23_ = ""
    else
      _23_ = (" " .. spec.arg)
    end
    label = (prefix .. long_name .. _21_ .. " / " .. prefix .. short_name .. _23_)
  else
    label = nil
  end
  local doc = (spec.doc or "")
  return vim.trim((label .. " \226\128\148 " .. doc))
end
local function statusline_label(spec)
  local override = spec.statusline
  local name = (spec.long or "")
  local _let_26_ = split_directive_name(name)
  local stem = _let_26_[1]
  local suffix = _let_26_[2]
  local await_mode = (spec.await and spec.await.mode)
  local stem_label = string.sub(stem, 1, math.min(3, #stem))
  local suffix_label = (((suffix ~= "") and (#suffix > 1) and string.sub(suffix, 2, 2)) or "")
  if ((type(override) == "string") and (override ~= "")) then
    return override
  else
    if (((spec.await and spec.await.kind) == "query-source") and (type(await_mode) == "string") and (await_mode ~= "")) then
      return (string.sub(stem, 1, math.min(2, #stem)) .. string.sub(await_mode, 1, 1))
    else
      if (suffix_label == "") then
        return stem_label
      else
        local prefix_len = math.max(1, math.min(2, #stem_label))
        return (string.sub(stem_label, 1, prefix_len) .. suffix_label)
      end
    end
  end
end
local function status_group_key(spec)
  local kind = (spec.kind or "")
  local await = (spec.await and spec.await.kind)
  if ((kind == "toggle") or ((kind == "flag") and ((type(spec.value) == "boolean") or (spec["compat-key"] ~= nil)))) then
    return ("state:" .. (spec["compat-key"] or spec["token-key"] or spec.long or ""))
  else
    if (await == "query-source") then
      return ("source:" .. (spec.long or ""))
    else
      return nil
    end
  end
end
local function session_state_value(session, spec)
  local parsed = ((session and session["last-parsed-query"]) or {})
  local token_key = (spec["token-key"] or "")
  local compat_key = (spec["compat-key"] or "")
  local effective_key
  if (token_key ~= "") then
    effective_key = ("effective-" .. token_key)
  else
    effective_key = ""
  end
  local parsed_v = ((token_key ~= "") and parsed[token_key])
  local compat_v = ((compat_key ~= "") and session[compat_key])
  local session_v = ((token_key ~= "") and session[token_key])
  local effective_v = ((effective_key ~= "") and session[effective_key])
  if (parsed_v ~= nil) then
    return parsed_v
  else
    if (compat_v ~= nil) then
      return compat_v
    else
      if (effective_v ~= nil) then
        return effective_v
      else
        return session_v
      end
    end
  end
end
local function query_source_active_3f(session, spec)
  local parsed = ((session and session["last-parsed-query"]) or {})
  local want_source = (spec.await and spec.await["source-key"])
  local want_mode = (spec.await and spec.await.mode)
  local active_3f = false
  local matched = active_3f
  for _, item in ipairs((parsed["source-lines"] or {})) do
    if (not matched and item and ((item.key or "") == (want_source or "")) and ((item.kind or "") == (want_mode or ""))) then
      matched = true
    else
    end
  end
  return matched
end
local function status_specs()
  local seen = {}
  local out = {}
  for _, spec in ipairs(all_specs()) do
    local group_key = status_group_key(spec)
    if (group_key and not seen[group_key]) then
      seen[group_key] = true
      table.insert(out, spec)
    else
    end
  end
  return out
end
local function status_item_active_3f(session, spec)
  local await_kind = (spec.await and spec.await.kind)
  if (await_kind == "query-source") then
    return query_source_active_3f(session, spec)
  else
    return clj.boolean(session_state_value(session, spec))
  end
end
local function status_item_show_3f(spec, active_3f)
  local provider_type = (spec["provider-type"] or "")
  if ((spec.await and spec.await.kind) == "query-source") then
    return active_3f
  else
    if ((provider_type == "transform") or (provider_type == "source")) then
      return active_3f
    else
      return true
    end
  end
end
M["statusline-items"] = function(session)
  local out = {}
  for _, spec in ipairs(status_specs()) do
    local active_3f = status_item_active_3f(session, spec)
    if status_item_show_3f(spec, active_3f) then
      table.insert(out, {label = statusline_label(spec), active = active_3f, ["provider-type"] = spec["provider-type"], kind = spec.kind, long = spec.long})
    else
    end
  end
  return out
end
local function literal_token_3f(prefix, tok, name)
  return ((tok == ("#" .. name)) or (tok == (prefix .. name)))
end
local function toggle_match(prefix, tok, spec)
  local key = spec["token-key"]
  local await = (spec["await-when-true"] and spec.await)
  local found = nil
  local out = found
  for _, name in ipairs(names_for_spec(spec)) do
    if not out then
      if (literal_token_3f(prefix, tok, name) or (tok == ("+" .. name)) or (tok == ("#+" .. name))) then
        out = {key = key, value = true, await = await}
      elseif ((tok == ("-" .. name)) or (tok == ("#-" .. name))) then
        out = {key = key, value = false}
      elseif (literal_token_3f(prefix, tok, ("no" .. name)) or (tok == ("#no" .. name))) then
        out = {key = key, value = false}
      else
      end
    else
    end
  end
  return out
end
local function flag_match(prefix, tok, spec)
  local out = nil
  local parsed = out
  for _, name in ipairs(names_for_spec(spec)) do
    if (not parsed and literal_token_3f(prefix, tok, name)) then
      parsed = {key = spec["token-key"], value = spec.value, await = spec.await}
    else
    end
  end
  return parsed
end
local function suffix_match(prefix, tok, spec)
  local out = nil
  local parsed = out
  for _, name in ipairs(names_for_spec(spec)) do
    if not parsed then
      local hash_name = ("#" .. name .. ":")
      local pref_name = (prefix .. name .. ":")
      local matched = (string.match(tok, ("^" .. vim.pesc(hash_name) .. "(.+)$")) or string.match(tok, ("^" .. vim.pesc(pref_name) .. "(.+)$")))
      local val_110_auto = matched
      if val_110_auto then
        local value = val_110_auto
        local trimmed
        if spec["trim-value"] then
          trimmed = vim.trim(value)
        else
          trimmed = value
        end
        if (trimmed ~= "") then
          parsed = {key = spec["token-key"], value = trimmed}
        else
        end
      else
      end
    else
    end
  end
  return parsed
end
local function prefix_value_match(tok, spec)
  local prefix0 = (spec.prefix or "")
  local matched = string.match(tok, ("^" .. vim.pesc(prefix0) .. "(.+)$"))
  local val_110_auto = matched
  if val_110_auto then
    local value = val_110_auto
    local trimmed
    if spec["trim-value"] then
      trimmed = vim.trim(value)
    else
      trimmed = value
    end
    if (trimmed ~= "") then
      return {key = spec["token-key"], value = trimmed}
    else
      return nil
    end
  else
    return nil
  end
end
local function parse_directive_token(prefix, tok, spec)
  local kind = (spec.kind or "flag")
  if (kind == "toggle") then
    return toggle_match(prefix, tok, spec)
  elseif (kind == "flag") then
    return flag_match(prefix, tok, spec)
  elseif (kind == "suffix") then
    return suffix_match(prefix, tok, spec)
  elseif (kind == "prefix-value") then
    return prefix_value_match(tok, spec)
  elseif (kind == "literal") then
    if (tok == (spec.literal or "")) then
      return {key = spec["token-key"], value = spec.value}
    else
      return nil
    end
  elseif "else" then
    return nil
  else
    return nil
  end
end
M["parse-token"] = function(prefix, tok)
  local out = nil
  local parsed = out
  for _, spec in ipairs(all_specs()) do
    if not parsed then
      local val_110_auto = parse_directive_token(prefix, tok, spec)
      if val_110_auto then
        local parsed_token = val_110_auto
        parsed = vim.tbl_extend("force", parsed_token, spec)
      else
      end
    else
    end
  end
  return parsed
end
M.catalog = function(prefix)
  local out = {}
  for _, spec in ipairs(all_specs()) do
    table.insert(out, vim.tbl_extend("force", spec, {display = display_token(prefix, spec), help = helptext(prefix, spec)}))
  end
  return out
end
M["matching-catalog"] = function(prefix, token)
  local needle = (token or "")
  local out = {}
  for _, spec in ipairs(M.catalog(prefix)) do
    local display = (spec.display or "")
    local long_token = display_token(prefix, vim.tbl_extend("force", spec, {short = spec.long}))
    if ((needle == "") or vim.startswith(display, needle) or ((long_token ~= "") and vim.startswith(long_token, needle)) or (spec.literal and vim.startswith(spec.literal, needle)) or (spec.prefix and vim.startswith(spec.prefix, needle))) then
      table.insert(out, spec)
    else
    end
  end
  return out
end
M["complete-items"] = function(prefix, token)
  local out = {}
  for _, spec in ipairs(M["matching-catalog"](prefix, token)) do
    table.insert(out, {word = spec.display, abbr = spec.display, menu = ("[" .. (spec["provider-type"] or "directive") .. "]"), info = spec.help})
  end
  return out
end
local function token_span(line, col1)
  local txt = (line or "")
  local cursor = math.max(1, math.min((#txt + 1), (col1 or 1)))
  local left = string.sub(txt, 1, math.max(0, (cursor - 1)))
  local start = string.match(left, "()%S+$")
  if start then
    local finish0 = (string.find(txt, "%s", start) or (#txt + 1))
    local finish
    if finish0 then
      finish = math.max(start, (finish0 - 1))
    else
      finish = #txt
    end
    return {start = start, finish = finish, token = string.sub(txt, start, finish)}
  else
    return nil
  end
end
M["token-under-cursor"] = function(line, col1)
  return token_span(line, col1)
end
local function option_prefix()
  local p = vim.g["meta#prefix"]
  if ((type(p) == "string") and (p ~= "")) then
    return p
  else
    return "#"
  end
end
M.completefunc = function(findstart, base)
  local line = vim.api.nvim_get_current_line()
  local col1 = ((vim.api.nvim_win_get_cursor(0)[2] or 0) + 1)
  local span = token_span(line(), col1)
  if (findstart == 1) then
    if span then
      return (span.start - 1)
    else
      return -2
    end
  else
    if (span and vim.startswith((span.token or ""), option_prefix())) then
      return M["complete-items"](option_prefix(), (base or ""))
    else
      return {}
    end
  end
end
M["query-state-init"] = function()
  local out = {}
  for _, spec in ipairs(all_specs()) do
    local key = spec["token-key"]
    if (key and (out[key] == nil)) then
      out[key] = nil
    else
    end
  end
  return out
end
M["all-specs"] = function()
  return all_specs()
end
M["finalize-parsed!"] = function(parsed)
  for _, spec in ipairs(all_specs()) do
    local key = spec["token-key"]
    local compat_key = spec["compat-key"]
    if (key and compat_key) then
      parsed[compat_key] = parsed[key]
    else
    end
  end
  return parsed
end
M["query-compat-view"] = function(parsed)
  local out = {}
  for _, spec in ipairs(all_specs()) do
    local key = spec["token-key"]
    local compat_key = spec["compat-key"]
    if key then
      out[key] = parsed[key]
    else
    end
    if (key and compat_key) then
      out[compat_key] = parsed[compat_key]
    else
    end
  end
  return out
end
M["empty-query-compat-view"] = function()
  local out = {}
  for _, spec in ipairs(all_specs()) do
    local key = spec["token-key"]
    local compat_key = spec["compat-key"]
    if key then
      out[key] = nil
    else
    end
    if compat_key then
      out[compat_key] = nil
    else
    end
  end
  return out
end
return M
