-- [nfnl] fnl/metabuffer/query.fnl
local directive_mod = require("metabuffer.query.directive")
local source_mod = require("metabuffer.source")
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
local function tokenize_line(line)
  local s = (line or "")
  local n = #s
  local out = {}
  local cur0 = {}
  local quote_char0 = nil
  local cur = cur0
  local quote_char = quote_char0
  local flush_21
  local function _3_()
    if (#cur > 0) then
      table.insert(out, table.concat(cur))
      cur = {}
      return nil
    else
      return nil
    end
  end
  flush_21 = _3_
  local i = 1
  while (i <= n) do
    do
      local ch = string.sub(s, i, i)
      if quote_char then
        table.insert(cur, ch)
        if (ch == quote_char) then
          quote_char = nil
        else
        end
      else
        if ((ch == "\"") or (ch == "'")) then
          table.insert(cur, ch)
          quote_char = ch
        else
          if string.match(ch, "%s") then
            flush_21()
          else
            table.insert(cur, ch)
          end
        end
      end
    end
    i = (i + 1)
  end
  flush_21()
  return out
end
local function parse_option_token(tok)
  local prefix = option_prefix()
  local parsed = directive_mod["parse-token"](prefix, tok)
  if parsed then
    return {parsed.key, parsed.value, parsed.await}
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
local function apply_awaited_directive(state, tok)
  local directive = state["await-directive"]
  local arg = unquote_token(tok)
  return source_mod["apply-awaited-directive"](state, directive, arg)
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
      local val_111_auto0 = source_mod["parse-bare-token"](state, tok, unquote_token)
      if val_111_auto0 then
        local shortcut = val_111_auto0
        return parse_parts(parts, (idx + 1), shortcut)
      else
        local val_111_auto1 = parse_option_token(tok)
        if val_111_auto1 then
          local parsed = val_111_auto1
          local next = source_mod["apply-parsed-directive"](state, parsed[1], parsed[2], parsed[3])
          return parse_parts(parts, (idx + 1), next)
        else
          if prefix_directive_token_3f(tok) then
            return parse_parts(parts, (idx + 1), state)
          else
            if (state["await-directive"] and (vim.trim(tok) ~= "")) then
              return parse_parts(parts, (idx + 1), apply_awaited_directive(state, tok))
            else
              local val_111_auto2 = source_mod["consume-pending-token"](state, tok, unquote_token)
              if val_111_auto2 then
                local next = val_111_auto2
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
end
local function parse_line(acc, line)
  local trimmed = vim.trim((line or ""))
  if (trimmed == "") then
    local next = vim.deepcopy(acc)
    table.insert(next.lines, "")
    table.insert(next["source-lines"], nil)
    return next
  else
    local parts = tokenize_line(trimmed)
    local state = parse_parts(parts, 1, assoc_option(assoc_option(assoc_option(acc, "keep", {}), "line-source", nil), "await-directive", nil))
    local next = vim.deepcopy(state)
    table.insert(next.lines, table.concat(state.keep, " "))
    table.insert(next["source-lines"], state["line-source"])
    next["keep"] = nil
    next["line-source"] = nil
    next["await-directive"] = nil
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
  local init = vim.tbl_extend("force", {lines = {}}, directive_mod["query-state-init"](), source_mod["query-state-init"]())
  local parsed = parse_lines((lines or {}), 1, init)
  directive_mod["finalize-parsed!"](parsed)
  return source_mod["finalize-parsed!"](parsed)
end
M["parse-query-text"] = function(query)
  if ((type(query) == "string") and (query ~= "")) then
    local lines = vim.split(query, "\n", {plain = true})
    local parsed = M["parse-query-lines"](lines)
    local out = {query = table.concat(parsed.lines, "\n"), lines = (parsed.lines or {}), ["source-lines"] = (parsed["source-lines"] or {})}
    return vim.tbl_extend("force", vim.tbl_extend("force", out, directive_mod["query-compat-view"](parsed)), source_mod["query-compat-view"](parsed))
  else
    local out
    local _22_
    if ((type(query) == "string") and (query ~= "")) then
      _22_ = vim.split(query, "\n", {plain = true})
    else
      _22_ = {}
    end
    out = {query = query, lines = _22_, ["source-lines"] = {}}
    return vim.tbl_extend("force", vim.tbl_extend("force", out, directive_mod["empty-query-compat-view"]()), source_mod["empty-query-compat-view"]())
  end
end
M["apply-default-source"] = function(parsed, enabled_3f)
  local next = source_mod["apply-default-query-source"](parsed, enabled_3f, tokenize_line)
  next["query"] = table.concat((next.lines or {}), "\n")
  return next
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
M["tokenize-line"] = tokenize_line
return M
