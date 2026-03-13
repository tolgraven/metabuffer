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
  local hidden_on = ((tok == "#hidden") or (tok == "+hidden") or (tok == "#+hidden") or (tok == (prefix .. "hidden")))
  local hidden_off = ((tok == "#nohidden") or (tok == "-hidden") or (tok == "#-hidden") or (tok == (prefix .. "nohidden")))
  local ignored_on = ((tok == "#ignored") or (tok == "+ignored") or (tok == "#+ignored") or (tok == (prefix .. "ignored")))
  local ignored_off = ((tok == "#noignored") or (tok == "-ignored") or (tok == "#-ignored") or (tok == (prefix .. "noignored")))
  local deps_on = ((tok == "#deps") or (tok == "+deps") or (tok == "#+deps") or (tok == (prefix .. "deps")))
  local deps_off = ((tok == "#nodeps") or (tok == "-deps") or (tok == "#-deps") or (tok == (prefix .. "nodeps")))
  local binary_on = ((tok == "#binary") or (tok == "+binary") or (tok == "#+binary") or (tok == (prefix .. "binary")))
  local binary_off = ((tok == "#nobinary") or (tok == "-binary") or (tok == "#-binary") or (tok == (prefix .. "nobinary")))
  local hex_on = ((tok == "#hex") or (tok == "+hex") or (tok == "#+hex") or (tok == (prefix .. "hex")))
  local hex_off = ((tok == "#nohex") or (tok == "-hex") or (tok == "#-hex") or (tok == (prefix .. "nohex")))
  local prefilter_off = ((tok == "#escape") or (tok == "+escape") or (tok == "#+escape") or (tok == (prefix .. "escape")) or (tok == "#noprefilter") or (tok == "-prefilter") or (tok == "#-prefilter") or (tok == (prefix .. "noprefilter")))
  local prefilter_on = ((tok == "#prefilter") or (tok == "+prefilter") or (tok == "#+prefilter") or (tok == (prefix .. "prefilter")))
  local lazy_off = ((tok == "#nolazy") or (tok == "-lazy") or (tok == "#-lazy") or (tok == (prefix .. "nolazy")))
  local lazy_on = ((tok == "#lazy") or (tok == "+lazy") or (tok == "#+lazy") or (tok == (prefix .. "lazy")))
  local files_off = ((tok == "#nofile") or (tok == "-file") or (tok == "#-file") or (tok == (prefix .. "nofile")))
  local files_on = ((tok == "#file") or (tok == "+file") or (tok == "#+file") or (tok == (prefix .. "file")))
  local history_merge_3f = (tok == "#history")
  local save_tag = (string.match(tok, "^#save:(.+)$") or string.match(tok, ("^" .. vim.pesc(prefix) .. "save:(.+)$")))
  local saved_tag = string.match(tok, "^##(.+)$")
  local saved_browser_3f = (tok == "##")
  if hidden_on then
    return {"hidden", true}
  elseif hidden_off then
    return {"hidden", false}
  elseif ignored_on then
    return {"ignored", true}
  elseif ignored_off then
    return {"ignored", false}
  elseif deps_on then
    return {"deps", true}
  elseif deps_off then
    return {"deps", false}
  elseif binary_on then
    return {"binary", true}
  elseif binary_off then
    return {"binary", false}
  elseif hex_on then
    return {"hex", true}
  elseif hex_off then
    return {"hex", false}
  elseif prefilter_off then
    return {"prefilter", false}
  elseif prefilter_on then
    return {"prefilter", true}
  elseif lazy_off then
    return {"lazy", false}
  elseif lazy_on then
    return {"lazy", true}
  elseif files_off then
    return {"files", false}
  elseif files_on then
    return {"files", true}
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
local function escaped_prefix_token(tok)
  local t = (tok or "")
  local prefix = option_prefix()
  local escaped_prefix = ("\\" .. prefix)
  if ((#t > #escaped_prefix) and vim.startswith(t, escaped_prefix)) then
    return string.sub(t, 2)
  else
    return nil
  end
end
local function prefix_directive_token_3f(tok)
  local t = (tok or "")
  local prefix = option_prefix()
  return ((t ~= prefix) and vim.startswith(t, prefix))
end
local function assoc_option(acc, k, v)
  local next = vim.deepcopy(acc)
  next[k] = v
  return next
end
local function unquote_token(tok)
  local t = (tok or "")
  local n = #t
  if (n >= 2) then
    local lead = string.sub(t, 1, 1)
    local tail = string.sub(t, n, n)
    if (((lead == "\"") and (tail == "\"")) or ((lead == "'") and (tail == "'"))) then
      return string.sub(t, 2, (n - 1))
    else
      return t
    end
  else
    return t
  end
end
local function file_query_shortcut_token(tok)
  local t = (tok or "")
  if (t == "./") then
    return "await"
  else
    return string.match(t, "^%./(.+)$")
  end
end
local function parse_parts(parts, idx, state)
  if (idx > #parts) then
    return state
  else
    local tok = parts[idx]
    local val_111_auto = escaped_prefix_token(tok)
    if val_111_auto then
      local escaped = val_111_auto
      local next = vim.deepcopy(state)
      table.insert(next.keep, escaped)
      return parse_parts(parts, (idx + 1), next)
    else
      local val_111_auto0 = file_query_shortcut_token(tok)
      if val_111_auto0 then
        local shortcut = val_111_auto0
        local next = assoc_option(state, "files", true)
        if (shortcut == "await") then
          return parse_parts(parts, (idx + 1), assoc_option(next, "file-await-token", true))
        else
          local next2 = vim.deepcopy(next)
          table.insert(next2["file-lines"], unquote_token(shortcut))
          next2["file-await-token"] = false
          return parse_parts(parts, (idx + 1), next2)
        end
      else
        local val_111_auto1 = parse_option_token(tok)
        if val_111_auto1 then
          local parsed = val_111_auto1
          local next = assoc_option(state, parsed[1], parsed[2])
          if (parsed[1] == "files") then
            return parse_parts(parts, (idx + 1), assoc_option(next, "file-await-token", true))
          else
            return parse_parts(parts, (idx + 1), next)
          end
        else
          if prefix_directive_token_3f(tok) then
            return parse_parts(parts, (idx + 1), state)
          else
            if (state["file-await-token"] and (vim.trim(tok) ~= "")) then
              local next = vim.deepcopy(state)
              table.insert(next["file-lines"], unquote_token(tok))
              next["file-await-token"] = false
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
    next["file-await-token"] = false
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
  local init = {lines = {}, hidden = nil, ignored = nil, deps = nil, binary = nil, hex = nil, prefilter = nil, lazy = nil, files = nil, history = nil, ["save-tag"] = nil, ["saved-tag"] = nil, ["saved-browser"] = nil, ["file-lines"] = {}, ["file-await-token"] = false}
  local parsed = parse_lines((lines or {}), 1, init)
  parsed["include-hidden"] = parsed.hidden
  parsed["include-ignored"] = parsed.ignored
  parsed["include-deps"] = parsed.deps
  parsed["include-binary"] = parsed.binary
  parsed["include-hex"] = parsed.hex
  parsed["include-files"] = parsed.files
  return parsed
end
M["parse-query-text"] = function(query)
  if ((type(query) == "string") and (query ~= "")) then
    local lines = vim.split(query, "\n", {plain = true})
    local parsed = M["parse-query-lines"](lines)
    return {query = table.concat(parsed.lines, "\n"), lines = (parsed.lines or {}), ["include-hidden"] = parsed.hidden, ["include-ignored"] = parsed.ignored, ["include-deps"] = parsed.deps, ["include-binary"] = parsed.binary, ["include-hex"] = parsed.hex, ["include-files"] = parsed.files, prefilter = parsed.prefilter, lazy = parsed.lazy, ["file-lines"] = (parsed["file-lines"] or {}), history = parsed.history, ["save-tag"] = parsed["save-tag"], ["saved-tag"] = parsed["saved-tag"], ["saved-browser"] = parsed["saved-browser"]}
  else
    local _18_
    if ((type(query) == "string") and (query ~= "")) then
      _18_ = vim.split(query, "\n", {plain = true})
    else
      _18_ = {}
    end
    return {query = query, lines = _18_, ["include-hidden"] = nil, ["include-ignored"] = nil, ["include-deps"] = nil, ["include-binary"] = nil, ["include-hex"] = nil, ["include-files"] = nil, prefilter = nil, lazy = nil, ["file-lines"] = {}, history = nil, ["save-tag"] = nil, ["saved-tag"] = nil, ["saved-browser"] = nil}
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
