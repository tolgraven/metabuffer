local M = {}

local api = vim.api
local fn = vim.fn

local MATCHERS = { "all", "fuzzy", "regex" }
local CASES = { "smart", "ignore", "normal" }
local SYNTAX = { "buffer", "meta" }

M.sessions = {}
M.active_by_meta = {}

local function split_words(text)
  local out = {}
  for token in string.gmatch(text or "", "%S+") do
    table.insert(out, token)
  end
  return out
end

local function esc_vim_pat(text)
  local escaped = (text or ""):gsub("([\\^$~%.%*%[%]])", "\\%1")
  return escaped
end

local function chars(text)
  return vim.fn.split(text or "", [[\zs]])
end

local function query_is_lower(query)
  return query == string.lower(query or "")
end

local function valid_buf(bufnr)
  return bufnr and api.nvim_buf_is_valid(bufnr)
end

local function current_session()
  local bufnr = api.nvim_get_current_buf()
  local source = vim.b._meta_source_bufnr
  if source and M.sessions[source] then
    return M.sessions[source]
  end
  local source_by_meta = M.active_by_meta[bufnr]
  if source_by_meta then
    return M.sessions[source_by_meta]
  end
end

local function resolve_source_bufnr()
  local bufnr = api.nvim_get_current_buf()
  if vim.b._meta_source_bufnr then
    return vim.b._meta_source_bufnr
  end
  local source = M.active_by_meta[bufnr]
  return source or bufnr
end

local function matcher_pattern(session, query)
  if query == "" then
    return ""
  end
  local matcher = MATCHERS[session.matcher_idx]
  if matcher == "all" then
    local pats = {}
    for _, w in ipairs(split_words(query)) do
      table.insert(pats, esc_vim_pat(w))
    end
    return ([[\%%(%s\)]]):format(table.concat(pats, [[\|]]))
  elseif matcher == "fuzzy" then
    local chars = chars(query)
    local chunks = {}
    for _, ch in ipairs(chars) do
      local e = esc_vim_pat(ch)
      table.insert(chunks, ([[%s[^%s]\\{-}]]):format(e, e))
    end
    return table.concat(chunks)
  end
  return table.concat(split_words(query), [[\|]])
end

local function regex_for_filter(session, query)
  local matcher = MATCHERS[session.matcher_idx]
  if matcher == "fuzzy" then
    local chars = chars(query)
    local pat = {}
    for _, ch in ipairs(chars) do
      local e = vim.pesc(ch)
      table.insert(pat, ([[%s[^%s]*]]):format(e, e))
    end
    return table.concat(pat)
  end
  return query
end

local function ignorecase(session)
  local mode = CASES[session.case_idx]
  if mode == "ignore" then
    return true
  end
  if mode == "normal" then
    return false
  end
  return query_is_lower(session.query)
end

local function apply_syntax(session)
  if not valid_buf(session.meta_bufnr) then
    return
  end
  local ft = vim.bo[session.source_bufnr].syntax
  local mode = SYNTAX[session.syntax_idx]
  if mode == "buffer" and ft and ft ~= "" then
    vim.bo[session.meta_bufnr].syntax = ft
  else
    vim.bo[session.meta_bufnr].syntax = "metabuffer"
  end
end

local function source_line_from_cursor(session)
  local line = api.nvim_win_get_cursor(0)[1]
  if line <= 1 then
    return session.indices[1] or session.source_cursor[1]
  end
  return session.indices[line - 1] or session.source_cursor[1]
end

local function statusline(session)
  local mode = "Insert"
  local matcher = MATCHERS[session.matcher_idx]
  local case_mode = CASES[session.case_idx]
  local syntax_mode = SYNTAX[session.syntax_idx]
  local selected = source_line_from_cursor(session)
  local hits = #session.indices
  local total = #session.source_lines
  return table.concat({
    "%#MetaStatuslineModeInsert#", " ", mode,
    "%#MetaStatuslineQuery#", " # ", session.query,
    "%#MetaStatuslineFile#", " ", vim.fn.fnamemodify(session.source_name, ":t"),
    "%#MetaStatuslineIndicator#", (" %d/%d %d"):format(hits, total, selected),
    "%#MetaStatuslineMiddle#%=",
    "%#MetaStatuslineMatcher", matcher:gsub("^%l", string.upper), "# ", matcher,
    "%#MetaStatuslineKey# C^",
    "%#MetaStatuslineCase", case_mode:gsub("^%l", string.upper), "# ", case_mode,
    "%#MetaStatuslineKey# C_",
    "%#MetaStatuslineSyntax", syntax_mode:gsub("^%l", string.upper), "# ", syntax_mode,
    "%#MetaStatuslineKey# Cs ",
  })
end

local function clear_hl(session)
  if session.match_id then
    pcall(fn.matchdelete, session.match_id)
    session.match_id = nil
  end
  if session.char_match_id then
    pcall(fn.matchdelete, session.char_match_id)
    session.char_match_id = nil
  end
end

local function apply_hl(session)
  clear_hl(session)
  if session.query == "" or #session.indices == 0 then
    return
  end
  local ic = ignorecase(session) and [[\c]] or [[\C]]
  local pat = matcher_pattern(session, session.query)
  if pat == "" then
    return
  end
  local group = "MetaSearchHit" .. MATCHERS[session.matcher_idx]:gsub("^%l", string.upper)
  session.match_id = fn.matchadd(group, ([[\%%>1l%s%s]]):format(ic, pat), 0)
  if MATCHERS[session.matcher_idx] == "fuzzy" then
    session.char_match_id = fn.matchadd("MetaSearchHitFuzzyBetween", ([[\%%>1l%s]]):format(table.concat(chars(session.query), [[\|]])), 0)
  end
end

local function filter_indices(session)
  local q = session.query or ""
  if q == "" then
    local all = {}
    for i = 1, #session.source_lines do
      all[i] = i
    end
    return all
  end

  local idx = {}
  local matcher = MATCHERS[session.matcher_idx]
  local ic = ignorecase(session)
  local candidates = session.source_lines
  local qfilter = regex_for_filter(session, q)

  if matcher == "all" then
    local words = split_words(q)
    if ic then
      for i, w in ipairs(words) do
        words[i] = string.lower(w)
      end
    end
    for i, line in ipairs(candidates) do
      local s = ic and string.lower(line) or line
      local ok = true
      for _, w in ipairs(words) do
        if not string.find(s, w, 1, true) then
          ok = false
          break
        end
      end
      if ok then
        table.insert(idx, i)
      end
    end
  elseif matcher == "fuzzy" then
    local ok_pat = qfilter
    for i, line in ipairs(candidates) do
      local ok = pcall(function()
        return string.find(line, ok_pat)
      end)
      if ok and string.find(line, ok_pat) then
        table.insert(idx, i)
      elseif ic then
        local low_line = string.lower(line)
        local low_pat = string.lower(ok_pat)
        local ok2 = pcall(function()
          return string.find(low_line, low_pat)
        end)
        if ok2 and string.find(low_line, low_pat) then
          table.insert(idx, i)
        end
      end
    end
  else
    local parts = split_words(q)
    local working = {}
    for i = 1, #candidates do
      working[i] = true
    end
    for _, rex in ipairs(parts) do
      for i, line in ipairs(candidates) do
        if working[i] then
          local ok, found = pcall(string.find, line, rex)
          if not ok or not found then
            if ic then
              local ok2, found2 = pcall(string.find, string.lower(line), string.lower(rex))
              if not ok2 or not found2 then
                working[i] = false
              end
            else
              working[i] = false
            end
          end
        end
      end
    end
    for i = 1, #candidates do
      if working[i] then
        table.insert(idx, i)
      end
    end
  end

  return idx
end

local function render(session, preserve_source_line)
  if not valid_buf(session.meta_bufnr) then
    return
  end
  local prev_src = preserve_source_line or source_line_from_cursor(session)
  session.indices = filter_indices(session)
  local out = { "# " .. (session.query or "") }
  for _, src_line in ipairs(session.indices) do
    table.insert(out, session.source_lines[src_line])
  end

  vim.bo[session.meta_bufnr].modifiable = true
  api.nvim_buf_set_lines(session.meta_bufnr, 0, -1, false, out)
  vim.bo[session.meta_bufnr].modifiable = true

  local cursor = 2
  if #session.indices == 0 then
    cursor = 1
  else
    for i, src in ipairs(session.indices) do
      if src >= prev_src then
        cursor = i + 1
        break
      end
      cursor = i + 1
    end
  end
  api.nvim_win_set_cursor(0, { cursor, 0 })

  vim.wo.statusline = statusline(session)
  apply_syntax(session)
  apply_hl(session)

  vim.b._meta_source_bufnr = session.source_bufnr
  vim.b._meta_context = {
    text = session.query,
    matcher_index = session.matcher_idx,
    case_index = session.case_idx,
    syntax_index = session.syntax_idx,
    selected_source_line = source_line_from_cursor(session),
  }
  vim.b._meta_indexes = session.indices
end

local function configure_meta_buffer(session)
  local b = session.meta_bufnr
  vim.bo[b].buftype = "nofile"
  vim.bo[b].bufhidden = "hide"
  vim.bo[b].swapfile = false
  vim.bo[b].buflisted = false
  vim.bo[b].modifiable = true
  vim.bo[b].filetype = "metabuffer"

  local opts = { buffer = b, silent = true }
  vim.keymap.set({ "n", "i" }, "<CR>", function() M.accept() end, opts)
  vim.keymap.set({ "n", "i" }, "<Esc>", function() M.cancel() end, opts)
  vim.keymap.set({ "n", "i" }, "<C-z>", function() M.pause() end, opts)
  vim.keymap.set({ "n", "i" }, "<Tab>", function() M.move_selection(1) end, opts)
  vim.keymap.set({ "n", "i" }, "<S-Tab>", function() M.move_selection(-1) end, opts)
  vim.keymap.set({ "n", "i" }, "<C-j>", function() M.move_selection(1) end, opts)
  vim.keymap.set({ "n", "i" }, "<C-k>", function() M.move_selection(-1) end, opts)
  vim.keymap.set({ "n", "i" }, "<C-n>", function() M.move_selection(1) end, opts)
  vim.keymap.set({ "n", "i" }, "<C-p>", function() M.move_selection(-1) end, opts)
  vim.keymap.set({ "n", "i" }, "<PageDown>", function() M.move_selection(1) end, opts)
  vim.keymap.set({ "n", "i" }, "<PageUp>", function() M.move_selection(-1) end, opts)
  vim.keymap.set({ "n", "i" }, "<C-^>", function() M.switch_matcher() end, opts)
  vim.keymap.set({ "n", "i" }, "<C-6>", function() M.switch_matcher() end, opts)
  vim.keymap.set({ "n", "i" }, "<C-_>", function() M.switch_case() end, opts)
  vim.keymap.set({ "n", "i" }, "<C-o>", function() M.switch_case() end, opts)
  vim.keymap.set({ "n", "i" }, "<C-s>", function() M.switch_syntax() end, opts)

  local grp = api.nvim_create_augroup(("Metabuffer_%d"):format(b), { clear = true })
  api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = grp,
    buffer = b,
    callback = function() M.on_text_changed() end,
  })

  api.nvim_buf_set_name(b, vim.fn.fnamemodify(session.source_name, ":.") .. "-meta")
end

local function jump_to_source(session, line, keep_query)
  clear_hl(session)
  if not valid_buf(session.source_bufnr) then
    return
  end
  api.nvim_set_current_buf(session.source_bufnr)
  line = math.max(1, math.min(#api.nvim_buf_get_lines(session.source_bufnr, 0, -1, false), line or 1))
  pcall(api.nvim_win_set_cursor, 0, { line, 0 })
  vim.cmd("normal! zv")

  if keep_query and session.query ~= "" then
    local ic = ignorecase(session) and [[\c]] or [[\C]]
    local pat = matcher_pattern(session, session.query)
    if pat ~= "" then
      fn.setreg("/", ic .. pat)
    end
  end
end

local function init_session(source_bufnr, query, resume)
  local source_name = api.nvim_buf_get_name(source_bufnr)
  local source_cursor = api.nvim_win_get_cursor(0)
  local existing = M.sessions[source_bufnr]

  if resume and existing and valid_buf(existing.meta_bufnr) then
    existing.query = (query ~= nil and query ~= "") and query or existing.query
    existing.source_lines = api.nvim_buf_get_lines(source_bufnr, 0, -1, false)
    existing.source_cursor = source_cursor
    api.nvim_set_current_buf(existing.meta_bufnr)
    return existing
  end

  local session = {
    source_bufnr = source_bufnr,
    source_name = source_name,
    source_cursor = source_cursor,
    source_lines = api.nvim_buf_get_lines(source_bufnr, 0, -1, false),
    meta_bufnr = api.nvim_create_buf(false, false),
    query = query or "",
    matcher_idx = 1,
    case_idx = 1,
    syntax_idx = 1,
    indices = {},
  }

  if resume and existing then
    session.query = (query ~= nil and query ~= "") and query or existing.query
    session.matcher_idx = existing.matcher_idx
    session.case_idx = existing.case_idx
    session.syntax_idx = existing.syntax_idx
  end

  M.sessions[source_bufnr] = session
  M.active_by_meta[session.meta_bufnr] = source_bufnr

  api.nvim_set_current_buf(session.meta_bufnr)
  configure_meta_buffer(session)

  return session
end

function M.start(opts)
  opts = opts or {}
  local source_bufnr = resolve_source_bufnr()
  if not valid_buf(source_bufnr) then
    return
  end

  if opts.new and M.sessions[source_bufnr] then
    local old = M.sessions[source_bufnr]
    if old then
      clear_hl(old)
    end
  end

  local session = init_session(source_bufnr, opts.query or "", opts.resume and not opts.new)
  render(session)
  vim.cmd("startinsert")
end

function M.resume(opts)
  opts = opts or {}
  M.start({ resume = true, query = opts.query })
end

function M.on_text_changed()
  local session = current_session()
  if not session then
    return
  end
  local line1 = (api.nvim_buf_get_lines(session.meta_bufnr, 0, 1, false)[1] or "")
  local query = line1:gsub("^#%s?", "")
  if query ~= session.query then
    session.query = query
    render(session)
  else
    vim.wo.statusline = statusline(session)
  end
end

function M.move_selection(delta)
  local session = current_session()
  if not session then
    return
  end
  local row, col = table.unpack(api.nvim_win_get_cursor(0))
  local lo = (#session.indices > 0) and 2 or 1
  local hi = (#session.indices > 0) and (#session.indices + 1) or 1
  row = math.max(lo, math.min(hi, row + delta))
  api.nvim_win_set_cursor(0, { row, col })
  vim.wo.statusline = statusline(session)
end

function M.switch_matcher()
  local session = current_session()
  if not session then
    return
  end
  session.matcher_idx = (session.matcher_idx % #MATCHERS) + 1
  render(session)
end

function M.switch_case()
  local session = current_session()
  if not session then
    return
  end
  session.case_idx = (session.case_idx % #CASES) + 1
  render(session)
end

function M.switch_syntax()
  local session = current_session()
  if not session then
    return
  end
  session.syntax_idx = (session.syntax_idx % #SYNTAX) + 1
  render(session)
end

function M.accept()
  local session = current_session()
  if not session then
    return
  end
  local line = source_line_from_cursor(session)
  jump_to_source(session, line, true)
end

function M.cancel()
  local session = current_session()
  if not session then
    return
  end
  jump_to_source(session, session.source_cursor[1], false)
end

function M.pause()
  local session = current_session()
  if not session then
    return
  end
  local line = source_line_from_cursor(session)
  jump_to_source(session, line, false)
end

function M.sync(query)
  local session = current_session()
  if not session then
    local source = resolve_source_bufnr()
    session = M.sessions[source]
  end
  if not session then
    vim.notify("No active metabuffer session", vim.log.levels.WARN)
    return
  end
  session.query = query or ""
  if valid_buf(session.meta_bufnr) then
    api.nvim_set_current_buf(session.meta_bufnr)
    render(session)
  end
end

function M.push()
  local session = current_session()
  if not session then
    vim.notify("MetaPush requires an active metabuffer", vim.log.levels.WARN)
    return
  end
  if not valid_buf(session.source_bufnr) then
    vim.notify("Source buffer is no longer valid", vim.log.levels.ERROR)
    return
  end

  local visible = api.nvim_buf_get_lines(session.meta_bufnr, 1, -1, false)
  local count = math.min(#visible, #session.indices)
  for i = 1, count do
    local src = session.indices[i]
    local old = api.nvim_buf_get_lines(session.source_bufnr, src - 1, src, false)[1]
    if old ~= visible[i] then
      api.nvim_buf_set_lines(session.source_bufnr, src - 1, src, false, { visible[i] })
      session.source_lines[src] = visible[i]
    end
  end
end

function M.cursor_word(resume)
  local word = fn.expand("<cword>")
  if resume then
    M.resume({ query = word })
  else
    M.start({ query = word })
  end
end

function M.setup()
  vim.api.nvim_create_user_command("Meta", function(args)
    M.start({ query = args.args, new = args.bang, resume = false })
  end, { nargs = "?", bang = true })

  vim.api.nvim_create_user_command("MetaResume", function(args)
    M.resume({ query = args.args })
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("MetaCursorWord", function()
    M.cursor_word(false)
  end, { nargs = 0 })

  vim.api.nvim_create_user_command("MetaResumeCursorWord", function()
    M.cursor_word(true)
  end, { nargs = 0 })

  vim.api.nvim_create_user_command("MetaSync", function(args)
    M.sync(args.args)
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("MetaPush", function()
    M.push()
  end, { nargs = 0 })
end

return M
