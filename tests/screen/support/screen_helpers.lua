local M = {}

M.child = MiniTest.new_child_neovim()
M.eq = MiniTest.expect.equality

local debug_dump_path = "/tmp/metabuffer-mini-integration.log"

function M.wait_for(pred, timeout_ms)
  local ok = vim.wait(timeout_ms or 3000, pred, 20)
  M.eq(ok, true)
end

function M.child_setup()
  local root = vim.fn.getcwd()
  M.child.restart(
    { "-u", root .. "/tests/minimal_init.lua", "-n", "-i", "NONE" },
    { connection_timeout = 20000 }
  )
  M.child.o.hidden = true
  M.child.o.swapfile = false
  M.child.cmd("cd " .. root)
  M.child.lua(string.format([[
    _G.__meta_debug_dump_path = %q
    local ok = pcall(vim.fn.delete, _G.__meta_debug_dump_path)
    if not ok then end
  ]], debug_dump_path))
end

function M.stop_child_once()
  if M.child.is_running() then
    M.child.stop()
  end
end

function M.case_name()
  local case = MiniTest.current and MiniTest.current.case or nil
  local desc = case and case.desc or {}
  if type(desc) ~= 'table' then
    return tostring(desc)
  end
  local out = {}
  for _, part in ipairs(desc) do
    out[#out + 1] = tostring(part)
  end
  return table.concat(out, ' > ')
end

function M.case_hooks()
  return {
    pre_case = function()
      if M._timings == nil then
        M._timings = {}
      end
      M.child_setup()
    end,
    post_once = function()
      if type(M._timings) == 'table' and #M._timings > 0 then
        io.stdout:write('\n[mini-runner] CASE TIMINGS SUMMARY\n')
        for i, item in ipairs(M._timings) do
          io.stdout:write(string.format('[mini-runner]   %02d. %s | %.1fms\n', i, item.name, item.ms))
        end
        io.stdout:flush()
      end
      M._timings = nil
      M.stop_child_once()
    end,
  }
end

function M.timed_case(fn)
  return function(...)
    local args = { ... }
    local t0 = vim.loop.hrtime() / 1e6
    local name = M.case_name()
    io.stdout:write(string.format('\n[mini-runner] CASE START %s\n', name))
    io.stdout:flush()

    local ok, res = xpcall(function()
      return fn(unpack(args))
    end, debug.traceback)

    local dt = (vim.loop.hrtime() / 1e6) - t0
    if type(M._timings) ~= 'table' then
      M._timings = {}
    end
    table.insert(M._timings, { name = name, ms = dt })
    io.stdout:write(string.format('\n[mini-runner] CASE DONE  %s | %.1fms\n', name, dt))
    io.stdout:flush()

    if not ok then
      error(res)
    end
    return res
  end
end

function M.open_meta_with_lines(lines)
  M.child.cmd("enew")
  M.child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  M.child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  M.child.cmd("Meta")

  M.wait_for(function()
    return M.child.lua_get("require('metabuffer.router')['active-by-source'][_G.__meta_source_buf] ~= nil")
  end)

  M.wait_for(function()
    local mode = M.child.fn.mode(1)
    return mode == "i" or mode == "ic" or mode == "ix"
  end)
end

function M.open_project_meta_from_file(path)
  M.child.cmd("edit " .. path)
  M.child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  M.child.cmd("Meta!")

  M.wait_for(function()
    return M.child.lua_get("require('metabuffer.router')['active-by-source'][_G.__meta_source_buf] ~= nil")
  end, 6000)

  M.wait_for(function()
    local mode = M.child.fn.mode(1)
    return mode == "i" or mode == "ic" or mode == "ix"
  end)
end

function M.make_temp_project()
  return M.child.lua_get([[
    (function()
      local root = vim.fn.tempname()
      vim.fn.mkdir(root, "p")
      vim.fn.mkdir(root .. "/lua", "p")
      vim.fn.mkdir(root .. "/doc", "p")

      local main = {}
      for i = 1, 200 do
        main[#main + 1] = ("line " .. i .. " plain content")
      end
      for i = 1, 60 do
        main[#main + 1] = ("contains meta token " .. i)
      end
      for i = 1, 20 do
        main[#main + 1] = ("contains metam token " .. i)
      end

      vim.fn.writefile(main, root .. "/main.txt")
      vim.fn.writefile({ "meta docs", "metam docs", "other" }, root .. "/doc/readme.md")
      vim.fn.writefile({ "local metabuffer = true", "local meta = 1", "return metabuffer" }, root .. "/lua/mod.lua")
      return root
    end)()
  ]])
end

function M.open_project_meta_in_dir(root, relpath)
  M.child.cmd("cd " .. root)
  M.child.cmd("edit " .. root .. "/" .. relpath)
  M.child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  M.child.cmd("Meta!")
  M.wait_for(function()
    return M.child.lua_get("require('metabuffer.router')['active-by-source'][_G.__meta_source_buf] ~= nil")
  end, 6000)
end

function M.session_query_text()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return '' end
      return table.concat((s.meta['query-lines'] or {}), '\n')
    end)()
  ]])
end

function M.session_prompt_text()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return '' end
      local lines = vim.api.nvim_buf_get_lines(s['prompt-buf'], 0, -1, false)
      return table.concat(lines or {}, '\n')
    end)()
  ]])
end

function M.session_hit_count()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return -1 end
      return #(s.meta.buf.indices or {})
    end)()
  ]])
end

function M.session_source_path_count()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return -1 end
      local idxs = s.meta.buf.indices or {}
      local refs = s.meta.buf['source-refs'] or {}
      local seen = {}
      local n = 0
      for _, src_idx in ipairs(idxs) do
        local ref = refs[src_idx]
        local path = ref and ref.path or ''
        if path ~= '' and not seen[path] then
          seen[path] = true
          n = n + 1
        end
      end
      return n
    end)()
  ]])
end

function M.session_file_entry_hit_count()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return -1 end
      local idxs = s.meta.buf.indices or {}
      local refs = s.meta.buf['source-refs'] or {}
      local n = 0
      for _, src_idx in ipairs(idxs) do
        local ref = refs[src_idx]
        if ref and ref.kind == 'file-entry' then
          n = n + 1
        end
      end
      return n
    end)()
  ]])
end

function M.session_first_file_entry_line()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return '' end
      local idxs = s.meta.buf.indices or {}
      local refs = s.meta.buf['source-refs'] or {}
      local lines = s.meta.buf.content or {}
      for _, src_idx in ipairs(idxs) do
        local ref = refs[src_idx]
        if ref and ref.kind == 'file-entry' then
          return lines[src_idx] or ''
        end
      end
      return ''
    end)()
  ]])
end

function M.session_context_exists()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      return s and s['context-win'] and vim.api.nvim_win_is_valid(s['context-win']) or false
    end)()
  ]])
end

function M.session_context_lines()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not (s and s['context-buf'] and vim.api.nvim_buf_is_valid(s['context-buf'])) then
        return {}
      end
      return vim.api.nvim_buf_get_lines(s['context-buf'], 0, -1, false)
    end)()
  ]])
end

function M.session_matcher_name()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return '' end
      local m = s.meta and s.meta.mode and s.meta.mode.matcher
      if not m then return '' end
      local cur = m:current()
      return (cur and cur.name) or ''
    end)()
  ]])
end

function M.session_case_mode()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return '' end
      if not (s.meta and s.meta.mode and s.meta.mode.case) then return '' end
      return s.meta.mode.case:current() or ''
    end)()
  ]])
end

function M.session_debug_out()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s or not s.meta then return '' end
      return s.meta.debug_out or ''
    end)()
  ]])
end

function M.session_statusline()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s or not s.meta or not s.meta['status-win'] then return '' end
      local win_obj = s.meta['status-win']
      local win = win_obj and win_obj.window
      if not (win and vim.api.nvim_win_is_valid(win)) then return '' end
      local ok, val = pcall(vim.api.nvim_get_option_value, 'statusline', { win = win })
      if not ok then return '' end
      return val or ''
    end)()
  ]])
end

function M.session_info_snapshot()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      local info_win, info_buf = s['info-win'], s['info-buf']
      if not (info_win and vim.api.nvim_win_is_valid(info_win) and info_buf and vim.api.nvim_buf_is_valid(info_buf)) then
        return nil
      end
      local row = vim.api.nvim_win_get_cursor(info_win)[1]
      local line = vim.api.nvim_buf_get_lines(info_buf, row - 1, row, false)[1] or ''
      local count = vim.api.nvim_buf_line_count(info_buf)
      return { row = row, line = line, count = count }
    end)()
  ]])
end

function M.session_selected_ref()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s or not s.meta then return nil end
      local meta = s.meta
      local src_idx = (meta.buf.indices or {})[meta.selected_index + 1]
      local ref = src_idx and (meta.buf['source-refs'] or {})[src_idx] or nil
      if not ref then return nil end
      return { path = ref.path or '', lnum = ref.lnum or 0 }
    end)()
  ]])
end

function M.session_preview_contains(needle)
  return M.child.lua_get(string.format([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return false end
      local buf = s['preview-buf']
      if not (buf and vim.api.nvim_buf_is_valid(buf)) then return false end
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      for _, line in ipairs(lines) do
        if string.find(line or '', %q, 1, true) then
          return true
        end
      end
      return false
    end)()
  ]], needle or ''))
end

function M.session_prompt_win_height()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local win = s and s['prompt-win'] or nil
      if not (win and vim.api.nvim_win_is_valid(win)) then return -1 end
      return vim.api.nvim_win_get_height(win)
    end)()
  ]])
end

function M.set_prompt_win_height(h)
  M.child.lua(string.format([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local win = s and s['prompt-win'] or nil
      if not (win and vim.api.nvim_win_is_valid(win)) then return end
      pcall(vim.api.nvim_win_set_height, win, %d)
    end)()
  ]], h))
end

function M.session_active()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      return router['active-by-source'][_G.__meta_source_buf] ~= nil
    end)()
  ]])
end

function M.session_history_browser_state()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return nil end
      local items = s['history-browser-items'] or {}
      return {
        active = s['history-browser-active'] == true,
        index = s['history-browser-index'] or 0,
        count = #items,
        mode = s['history-browser-mode'] or '',
      }
    end)()
  ]])
end

function M.close_meta_prompt()
  M.child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if s then
        router.cancel(s.prompt_buf)
      end
    end)()
  ]])
end

function M.str_contains(hay, needle)
  return (type(hay) == "string") and (string.find(hay, needle, 1, true) ~= nil)
end

function M.dump_state(tag)
  M.child.lua(string.format([[
    (function()
      local path = _G.__meta_debug_dump_path
      local tag = %q
      if not path then return end
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local out = {}
      out[#out + 1] = ("--- " .. tag .. " ---")
      if not s then
        out[#out + 1] = "session=nil"
      else
        local q = table.concat((s.meta['query-lines'] or {}), "\\n")
        local hits = #(s.meta.buf.indices or {})
        local refs = s.meta.buf['source-refs'] or {}
        local seen, src = {}, 0
        for _, src_idx in ipairs(s.meta.buf.indices or {}) do
          local ref = refs[src_idx]
          local p = ref and ref.path or ''
          if p ~= '' and not seen[p] then
            seen[p] = true
            src = src + 1
          end
        end
        out[#out + 1] = ("query=" .. q)
        out[#out + 1] = ("hits=" .. tostring(hits))
        out[#out + 1] = ("sources=" .. tostring(src))
        local lines = vim.api.nvim_buf_get_lines(s.meta.buf.buffer, 0, math.min(25, vim.api.nvim_buf_line_count(s.meta.buf.buffer)), false)
        for i, line in ipairs(lines) do
          out[#out + 1] = (string.format("%%03d: %%s", i, line))
        end
      end
      vim.fn.writefile(out, path, "a")
    end)()
  ]], tag))
end

function M.type_prompt(keys)
  M.child.type_keys(0, keys)
  M.dump_state("type " .. keys)
end

function M.type_prompt_human(text, per_key_ms)
  local delay = per_key_ms or 100
  for i = 1, #text do
    M.child.type_keys(0, string.sub(text, i, i))
    if delay > 0 then
      vim.loop.sleep(delay)
    end
  end
  M.dump_state("type_human " .. text)
end

function M.type_prompt_tokens(tokens, per_key_ms)
  local delay = per_key_ms or 100
  for _, key in ipairs(tokens) do
    M.child.type_keys(0, key)
    if delay > 0 then
      vim.loop.sleep(delay)
    end
  end
  M.dump_state("type_tokens " .. table.concat(tokens, " "))
end

return M
