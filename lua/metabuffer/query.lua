-- [nfnl] fnl/metabuffer/query.fnl
local M = {}
M["truthy?"] = function(v)
  return ((v == true) or (v == 1) or (v == "1") or (v == "true"))
end
local function option_prefix()
  local val_111_auto = vim.g["meta#prefix"]
  if val_111_auto then
    local p = val_111_auto
    if ((type(p) == "string") and (p ~= "")) then
      return p
    else
      return "#"
    end
  else
    return "#"
  end
end
local function parse_option_token(tok)
  local prefix = option_prefix()
  local hidden_toggle = ((tok == "#hidden") or (tok == (prefix .. "hidden")))
  local hidden_on = ((tok == "+hidden") or (tok == "#+hidden"))
  local hidden_off = ((tok == "#nohidden") or (tok == "-hidden") or (tok == "#-hidden") or (tok == (prefix .. "nohidden")))
  local ignored_toggle = ((tok == "#ignored") or (tok == (prefix .. "ignored")))
  local ignored_on = ((tok == "+ignored") or (tok == "#+ignored"))
  local ignored_off = ((tok == "#noignored") or (tok == "-ignored") or (tok == "#-ignored") or (tok == (prefix .. "noignored")))
  local deps_toggle = ((tok == "#deps") or (tok == (prefix .. "deps")))
  local deps_on = ((tok == "+deps") or (tok == "#+deps"))
  local deps_off = ((tok == "#nodeps") or (tok == "-deps") or (tok == "#-deps") or (tok == (prefix .. "nodeps")))
  local prefilter_off = ((tok == "#escape") or (tok == "+escape") or (tok == "#+escape") or (tok == (prefix .. "escape")) or (tok == "#noprefilter") or (tok == "-prefilter") or (tok == "#-prefilter") or (tok == (prefix .. "noprefilter")))
  local prefilter_toggle = ((tok == "#prefilter") or (tok == (prefix .. "prefilter")))
  local prefilter_on = ((tok == "+prefilter") or (tok == "#+prefilter"))
  local lazy_off = ((tok == "#nolazy") or (tok == "-lazy") or (tok == "#-lazy") or (tok == (prefix .. "nolazy")))
  local lazy_toggle = ((tok == "#lazy") or (tok == (prefix .. "lazy")))
  local lazy_on = ((tok == "+lazy") or (tok == "#+lazy"))
  local history_merge_3f = (tok == "#history")
  local save_tag = (string.match(tok, "^#save:(.+)$") or string.match(tok, ("^" .. vim.pesc(prefix) .. "save:(.+)$")))
  local saved_tag = string.match(tok, "^##(.+)$")
  local saved_browser_3f = (tok == "##")
  if hidden_toggle then
    return {"hidden", "toggle"}
  elseif hidden_on then
    return {"hidden", true}
  elseif hidden_off then
    return {"hidden", false}
  elseif ignored_toggle then
    return {"ignored", "toggle"}
  elseif ignored_on then
    return {"ignored", true}
  elseif ignored_off then
    return {"ignored", false}
  elseif deps_toggle then
    return {"deps", "toggle"}
  elseif deps_on then
    return {"deps", true}
  elseif deps_off then
    return {"deps", false}
  elseif prefilter_toggle then
    return {"prefilter", "toggle"}
  elseif prefilter_off then
    return {"prefilter", false}
  elseif prefilter_on then
    return {"prefilter", true}
  elseif lazy_toggle then
    return {"lazy", "toggle"}
  elseif lazy_off then
    return {"lazy", false}
  elseif lazy_on then
    return {"lazy", true}
  elseif history_merge_3f then
    return {"history", true}
  elseif save_tag then
    return {"save-tag", save_tag}
  elseif (saved_tag and (vim.trim(saved_tag) ~= "")) then
    return {"saved-tag", vim.trim(saved_tag)}
  elseif saved_browser_3f then
    return {"saved-browser", true}
  else
    return nil
  end
end
M["resolve-option"] = function(value, current)
  if (value == "toggle") then
    return not M["truthy?"](current)
  else
    local val_113_auto = value
    if (nil ~= val_113_auto) then
      local v = val_113_auto
      return v
    else
      return current
    end
  end
end
local function assoc_option(acc, k, v)
  local next = vim.deepcopy(acc)
  next[k] = v
  return next
end
local function parse_parts(parts, idx, state)
  if (idx > #parts) then
    return state
  else
    local tok = parts[idx]
    if vim.startswith(tok, "\\#") then
      local next = vim.deepcopy(state)
      local literal = string.sub(tok, 2)
      table.insert(next.keep, literal)
      return parse_parts(parts, (idx + 1), next)
    else
      local val_111_auto = parse_option_token(tok)
      if val_111_auto then
        local parsed = val_111_auto
        return parse_parts(parts, (idx + 1), assoc_option(state, parsed[1], parsed[2]))
      else
        if vim.startswith(tok, "#") then
          local next = assoc_option(state, "pending-control", true)
          return parse_parts(parts, (idx + 1), next)
        else
          local next = vim.deepcopy(state)
          table.insert(next.keep, tok)
          return parse_parts(parts, (idx + 1), next)
        end
      end
    end
  end
end
local function parse_line(acc, line)
  local trimmed = vim.trim((line or ""))
  if (trimmed == "") then
    local next = vim.deepcopy(acc)
    table.insert(next.lines, "")
    return next
  else
    local parts = vim.split(trimmed, "%s+", {trimempty = true})
    local state = parse_parts(parts, 1, assoc_option(acc, "keep", {}))
    local next = vim.deepcopy(state)
    table.insert(next.lines, table.concat(state.keep, " "))
    next["keep"] = nil
    return next
  end
end
local function parse_lines(lines, idx, state)
  if (idx > #lines) then
    return state
  else
    return parse_lines(lines, (idx + 1), parse_line(state, lines[idx]))
  end
end
M["parse-query-lines"] = function(lines)
  local init = {lines = {}, hidden = nil, ignored = nil, deps = nil, prefilter = nil, lazy = nil, history = nil, ["save-tag"] = nil, ["saved-tag"] = nil, ["saved-browser"] = nil, ["pending-control"] = false}
  return parse_lines((lines or {}), 1, init)
end
M["parse-query-text"] = function(query)
  if ((type(query) == "string") and (query ~= "")) then
    local lines = vim.split(query, "\n", {plain = true})
    local parsed = M["parse-query-lines"](lines)
    return {query = table.concat(parsed.lines, "\n"), ["include-hidden"] = parsed.hidden, ["include-ignored"] = parsed.ignored, ["include-deps"] = parsed.deps, prefilter = parsed.prefilter, lazy = parsed.lazy, history = parsed.history, ["save-tag"] = parsed["save-tag"], ["saved-tag"] = parsed["saved-tag"], ["saved-browser"] = parsed["saved-browser"], ["pending-control"] = parsed["pending-control"]}
  else
    return {query = query, ["include-hidden"] = nil, ["include-ignored"] = nil, ["include-deps"] = nil, prefilter = nil, lazy = nil, history = nil, ["save-tag"] = nil, ["saved-tag"] = nil, ["saved-browser"] = nil, ["pending-control"] = false}
  end
end
local function lines_has_active_3f(lines, idx)
  if (idx > #lines) then
    return false
  else
    return ((vim.trim((lines[idx] or "")) ~= "") or lines_has_active_3f(lines, (idx + 1)))
  end
end
M["query-lines-has-active?"] = function(lines)
  return lines_has_active_3f((lines or {}), 1)
end
return M
