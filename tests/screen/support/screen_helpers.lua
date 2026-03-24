local M = {}
local profiler = require('tests.support.profiler')

M.child = MiniTest.new_child_neovim()
M.eq = MiniTest.expect.equality

local debug_dump_path = "/tmp/metabuffer-mini-integration.log"
local debug_dump_enabled = vim.env.TEST_DEBUG_DUMP == '1'

function M.wait_for(pred, timeout_ms)
  local ok = profiler.measure('wait', profiler.caller_label(2, 'wait_for'), function()
    return vim.wait(timeout_ms or 3000, pred, 20)
  end)
  M.eq(ok, true)
end

function M.child_setup()
  local root = vim.fn.getcwd()
  local worker_idx = tonumber(vim.env.TEST_WORKER_INDEX or '') or 1
  local startup_jitter = (worker_idx % 8) * 35

  if startup_jitter > 0 then
    vim.loop.sleep(startup_jitter)
  end

  profiler.measure('child', 'child.restart', function()
    local last_err = nil
    for attempt = 1, 4 do
      local ok, err = pcall(function()
        M.child.restart(
          { "-u", root .. "/tests/minimal_init.lua", "-n", "-i", "NONE" },
          { connection_timeout = 20000 }
        )
      end)
      if ok then
        return
      end
      last_err = err
      vim.loop.sleep(80 * attempt)
    end
    error(last_err)
  end)
  M.child.o.hidden = true
  M.child.o.swapfile = false
  M.child.cmd("cd " .. root)
  M.child.lua(string.format([[
    _G.__meta_debug_dump_path = %q
    local ok = pcall(vim.fn.delete, _G.__meta_debug_dump_path)
    if not ok then end
    vim.v.errmsg = ''
    pcall(vim.cmd, 'messages clear')
  ]], debug_dump_path))
end

function M.stop_child_once()
  if M.child.is_running() then
    pcall(function()
      M.child.lua([[
        pcall(vim.cmd, 'stopinsert')
        vim.schedule(function()
          pcall(vim.cmd, 'silent! qa!')
        end)
      ]])
    end)
    M.child.stop()
  end
end

local function ensure_prompt_insert()
  M.child.lua([[
    local router = require('metabuffer.router')
    local session = router['active-by-source'][_G.__meta_source_buf]
    assert(session and session['prompt-win'], 'missing prompt window')
    if vim.api.nvim_win_is_valid(session['prompt-win']) then
      vim.api.nvim_set_current_win(session['prompt-win'])
      local mode = vim.fn.mode(1)
      if mode ~= 'i' and mode ~= 'ic' and mode ~= 'ix' then
        vim.cmd('startinsert')
      end
    end
  ]])
end

function M.focus_prompt(mode)
  M.child.lua(string.format([[
    (function()
      local router = require('metabuffer.router')
      local session = router['active-by-source'][_G.__meta_source_buf]
      assert(session and session['prompt-win'], 'missing prompt window')
      if vim.api.nvim_win_is_valid(session['prompt-win']) then
        vim.api.nvim_set_current_win(session['prompt-win'])
        local want = %q
        local cur = vim.fn.mode(1)
        if want == 'insert' then
          if cur ~= 'i' and cur ~= 'ic' and cur ~= 'ix' then
            vim.cmd('startinsert')
          end
        elseif cur ~= 'n' then
          pcall(vim.cmd, 'stopinsert')
        end
      end
    end)()
  ]], mode or 'normal'))
end

function M.feed_prompt_key(key, mode)
  M.child.lua(string.format([[
    (function()
      local router = require('metabuffer.router')
      local session = router['active-by-source'][_G.__meta_source_buf]
      assert(session and session['prompt-win'], 'missing prompt window')
      if vim.api.nvim_win_is_valid(session['prompt-win']) then
        vim.api.nvim_set_current_win(session['prompt-win'])
        local want = %q
        local cur = vim.fn.mode(1)
        if want == 'insert' then
          if cur ~= 'i' and cur ~= 'ic' and cur ~= 'ix' then
            vim.cmd('startinsert')
          end
        elseif cur ~= 'n' then
          pcall(vim.cmd, 'stopinsert')
        end
        local keys = vim.api.nvim_replace_termcodes(%q, true, false, true)
        vim.api.nvim_feedkeys(keys, 'xt', false)
      end
    end)()
  ]], mode or 'normal', key))
end

function M.session_prompt_focused()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      return not not (s and s['prompt-win'] and vim.api.nvim_get_current_win() == s['prompt-win'])
    end)()
  ]])
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
      M.child_setup()
    end,
    post_case = function()
      local errmsg = M.child.lua_get("return vim.v.errmsg or ''")
      if type(errmsg) == 'string' then
        errmsg = errmsg:gsub('^%s+', ''):gsub('%s+$', '')
      end
      M.eq(errmsg, '')

      local messages = M.child.lua_get([[
        local ok, out = pcall(function()
          return vim.api.nvim_exec2('silent messages', { output = true }).output or ''
        end)
        return ok and out or ''
      ]])
      if type(messages) == 'string' then
        local trimmed = messages:gsub('^%s+', ''):gsub('%s+$', '')
        local bad =
          trimmed:find('stack traceback', 1, true)
          or trimmed:find('torn down after error', 1, true)
          or trimmed:find('_core/editor.lua', 1, true)
          or trimmed:find('expected', 1, true)
          or trimmed:find('nil', 1, true)
        if bad ~= nil then
          io.stdout:write('[screen-helper] unexpected :messages output follows\n')
          io.stdout:write(trimmed .. '\n')
        end
        M.eq(bad == nil, true)
      end
    end,
    post_once = function()
      M.stop_child_once()
    end,
  }
end

function M.timed_case(fn)
  return fn
end

function M.open_meta_with_lines(lines)
  M.child.cmd("enew")
  M.child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  M.child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  M.child.type_keys(":", "Meta", "<CR>")
  vim.loop.sleep(150)
  M.child.lua("if vim.g.meta_test_no_startinsert then pcall(vim.cmd, 'stopinsert') end")
  M.wait_for(function()
    return M.child.lua_get("require('metabuffer.router')['active-by-source'][_G.__meta_source_buf] ~= nil")
  end)
end

function M.configure_animation(opts)
  M.child.lua(string.format([[
    (function()
      require('metabuffer').setup(%s)
    end)()
  ]], vim.inspect(opts or {})))
end

local function project_root_for_tests()
  if vim.env.TEST_REAL_REPO == '1' then
    return M.child.fn.getcwd()
  end

  if M._fixture_root then
    return M._fixture_root
  end

  M._fixture_root = M.child.lua_get([[
    (function()
      local root = vim.fn.tempname()
      local function mkdir(path)
        vim.fn.mkdir(path, 'p')
      end
      local function write(path, lines, mode)
        if mode == nil then
          vim.fn.writefile(lines, path)
          return
        end
        vim.fn.writefile(lines, path, mode)
      end
      local function repeat_lines(prefix, count)
        local out = {}
        for i = 1, count do
          out[#out + 1] = string.format('%s %03d', prefix, i)
        end
        return out
      end
      local function binary_blob()
        return {
          137, 80, 78, 71, 13, 10, 26, 10,
          0, 0, 0, 13, 73, 72, 68, 82,
          0, 0, 0, 1, 0, 0, 0, 1,
          8, 2, 0, 0, 0, 144, 119, 83,
          222, 0, 0, 0, 12, 73, 68, 65,
          84, 8, 153, 99, 248, 15, 4, 0,
          9, 251, 3, 253, 160, 132, 81, 106,
          0, 0, 0, 0, 73, 69, 78, 68,
          174, 66, 96, 130,
        }
      end

      mkdir(root)
      mkdir(root .. '/lua/metabuffer/core')
      mkdir(root .. '/lua/metabuffer/window')
      mkdir(root .. '/fnl/metabuffer/router')
      mkdir(root .. '/fnl/metabuffer/window')
      mkdir(root .. '/doc')
      mkdir(root .. '/deps/demo/src')
      mkdir(root .. '/ignored')
      mkdir(root .. '/nested/deeper/even-deeper')
      mkdir(root .. '/.hidden')

      write(root .. '/.gitignore', {
        'ignored/',
        '*.tmp',
      })

      write(root .. '/README.md', vim.list_extend({
        '# Metabuffer Fixture',
        '',
        'local meta fixture text',
        'metam token lives here',
        'preview-window appears in this readme',
        'info-window appears in this readme',
        'lua file query content for README.md',
      }, repeat_lines('fixture readme line with meta local lua content', 80)))

      write(root .. '/lua/metabuffer/core/init.lua', vim.list_extend({
        'local M = {}',
        '',
        'function M.setup(opts)',
        '  local meta = opts and opts.meta or "meta"',
        '  local metam = opts and opts.metam or "metam"',
        '  return { meta = meta, metam = metam }',
        'end',
        '',
        'return M',
      }, repeat_lines('local fixture_lua_value = "meta local lua"', 60)))

      write(root .. '/lua/metabuffer/window/info_window.lua', vim.list_extend({
        'local function info_window_state()',
        '  local local_value = "info-window"',
        '  return local_value',
        'end',
        '',
        'return info_window_state',
      }, repeat_lines('local info_window_meta = "local lua info-window"', 45)))

      write(root .. '/fnl/metabuffer/router/query_flow.fnl', vim.list_extend({
        '(local M {})',
        '',
        '(fn setup',
        '  [opts]',
        '  (let [local-value "meta"]',
        '    {:meta local-value',
        '     :opts opts}))',
        '',
        'M',
      }, repeat_lines('(local local-meta "local meta fnl")', 55)))

      write(root .. '/fnl/metabuffer/window/preview_window.fnl', vim.list_extend({
        '(fn preview-window',
        '  []',
        '  {:title "preview-window"})',
      }, repeat_lines('(local preview-window-local "preview-window meta")', 35)))

      write(root .. '/doc/testing.md', vim.list_extend({
        '# Testing',
        '',
        'local project docs mention meta and lua',
        'preview-window and info-window are documented here',
      }, repeat_lines('doc file local meta line', 30)))

      write(root .. '/deps/demo/src/lib.lua', vim.list_extend({
        'local dep_meta = true',
        'return dep_meta',
      }, repeat_lines('local dep_line = "meta from deps"', 25)))

      write(root .. '/ignored/generated.log', vim.list_extend({
        'ignored meta content',
      }, repeat_lines('ignored line meta local', 20)))

      write(root .. '/.hidden/secret.lua', vim.list_extend({
        'local hidden_meta = "secret meta"',
        'return hidden_meta',
      }, repeat_lines('local hidden_line = "hidden meta"', 20)))

      write(root .. '/nested/deeper/even-deeper/sample.lua', vim.list_extend({
        'local nested = "meta"',
        'return nested',
      }, repeat_lines('local nested_local = "lua meta local"', 40)))

      write(root .. '/metabuffer.png', binary_blob(), 'b')

      for i = 1, 24 do
        local dir = string.format('%s/fixtures/pack_%02d', root, i)
        mkdir(dir)
        write(dir .. '/module.lua', vim.list_extend({
          string.format('local module_%02d = "meta"', i),
          string.format('local local_value_%02d = "lua"', i),
          string.format('return module_%02d', i),
        }, repeat_lines(string.format('local fixture_pack_%02d = "meta local lua"', i), 24)))
      end

      return root
    end)()
  ]])
  return M._fixture_root
end

function M.open_project_meta_from_file(path)
  local root = project_root_for_tests()
  M.child.cmd("cd " .. root)
  M.child.cmd("edit " .. root .. "/" .. path)
  M.child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  M.child.type_keys(":", "Meta!", "<CR>")
  vim.loop.sleep(150)
  M.child.lua("if vim.g.meta_test_no_startinsert then pcall(vim.cmd, 'stopinsert') end")
  M.wait_for(function()
    return M.child.lua_get("require('metabuffer.router')['active-by-source'][_G.__meta_source_buf] ~= nil")
  end, 6000)
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
  M.child.type_keys(":", "Meta!", "<CR>")
  vim.loop.sleep(150)
  M.child.lua("if vim.g.meta_test_no_startinsert then pcall(vim.cmd, 'stopinsert') end")
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

function M.session_result_lines()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not (s and s.meta and s.meta.buf and vim.api.nvim_buf_is_valid(s.meta.buf.buffer)) then
        return {}
      end
      return vim.api.nvim_buf_get_lines(s.meta.buf.buffer, 0, -1, false)
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
  return M.session_prompt_statusline()
end

function M.session_prompt_statusline()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local win = s and s['prompt-win'] or nil
      if not (win and vim.api.nvim_win_is_valid(win)) then return '' end
      local ok, val = pcall(vim.api.nvim_get_option_value, 'statusline', { win = win })
      if not ok then return '' end
      return val or ''
    end)()
  ]])
end

function M.session_info_snapshot()
  local encoded = M.child.lua_get([[
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
      return vim.json.encode({ row = row, line = line, count = count })
    end)()
  ]])
  if encoded == nil or encoded == vim.NIL then return nil end
  return vim.json.decode(encoded)
end

function M.session_info_view()
  local encoded = M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not (s and s.meta and s.meta.buf) then
        return nil
      end
      local info_win, info_buf = s['info-win'], s['info-buf']
      if not (info_win and vim.api.nvim_win_is_valid(info_win) and info_buf and vim.api.nvim_buf_is_valid(info_buf)) then
        return nil
      end
      local view = vim.api.nvim_win_call(info_win, function()
        return vim.fn.winsaveview()
      end)
      local selected = (s.meta.selected_index or 0) + 1
      local row = selected - (view.topline or 1) + 1
      return vim.json.encode({
        topline = view.topline or 0,
        lnum = view.lnum or 0,
        selected_row = row,
        height = vim.api.nvim_win_get_height(info_win),
      })
    end)()
  ]])
  if encoded == nil or encoded == vim.NIL then return nil end
  return vim.json.decode(encoded)
end

function M.session_info_width()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local info_win = s and s['info-win'] or nil
      if not (info_win and vim.api.nvim_win_is_valid(info_win)) then
        return 0
      end
      return vim.api.nvim_win_get_width(info_win)
    end)()
  ]])
end

function M.session_info_max_line_width()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local info_buf = s and s['info-buf'] or nil
      if not (info_buf and vim.api.nvim_buf_is_valid(info_buf)) then
        return 0
      end
      local lines = vim.api.nvim_buf_get_lines(info_buf, 0, -1, false)
      local maxw = 0
      for _, line in ipairs(lines) do
        maxw = math.max(maxw, vim.fn.strdisplaywidth(line or ''))
      end
      return maxw
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

function M.session_main_view()
  local encoded = M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not (s and s.meta and s.meta.win) then
        return nil
      end
      local win = s.meta.win.window
      if not (win and vim.api.nvim_win_is_valid(win)) then
        return nil
      end
      local view = vim.api.nvim_win_call(win, function()
        return vim.fn.winsaveview()
      end)
      local height = vim.api.nvim_win_get_height(win)
      return vim.json.encode({
        lnum = view.lnum or 0,
        topline = view.topline or 0,
        leftcol = view.leftcol or 0,
        col = view.col or 0,
        height = height,
      })
    end)()
  ]])
  if encoded == nil or encoded == vim.NIL then return nil end
  return vim.json.decode(encoded)
end

function M.session_main_cursor()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not (s and s.meta and s.meta.win) then
        return nil
      end
      local win = s.meta.win.window
      if not (win and vim.api.nvim_win_is_valid(win)) then
        return nil
      end
      local cur = vim.api.nvim_win_get_cursor(win)
      return { cur[1] or 0, cur[2] or 0 }
    end)()
  ]])
end

function M.session_main_statusline()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not (s and s.meta and s.meta.win) then
        return ''
      end
      local win = s.meta.win.window
      if not (win and vim.api.nvim_win_is_valid(win)) then
        return ''
      end
      local ok, val = pcall(vim.api.nvim_get_option_value, 'statusline', { win = win })
      if not ok then return '' end
      return val or ''
    end)()
  ]])
end

function M.set_session_main_view(topline, lnum, height)
  M.child.lua(string.format([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not (s and s.meta and s.meta.win) then
        return
      end
      local win = s.meta.win.window
      if not (win and vim.api.nvim_win_is_valid(win)) then
        return
      end
      pcall(vim.api.nvim_win_set_height, win, %d)
      vim.api.nvim_win_call(win, function()
        vim.fn.winrestview({ topline = %d, lnum = %d, col = 0, leftcol = 0 })
      end)
    end)()
  ]], height, topline, lnum))
end

function M.scroll_main_and_wait(action, timeout_ms)
  local target = M.child.lua_get(string.format([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not (s and s.meta and s.meta.win and vim.api.nvim_win_is_valid(s.meta.win.window)) then
        return nil
      end
      local win = s.meta.win.window
      local target = vim.api.nvim_win_call(win, function()
        local line_count = vim.api.nvim_buf_line_count(s.meta.buf.buffer)
        local win_height = math.max(1, vim.api.nvim_win_get_height(win))
        local half_step = math.max(1, math.floor(win_height / 2))
        local page_step = math.max(1, win_height - 2)
        local step = (%q == 'line-down' or %q == 'line-up') and 1
          or ((%q == 'half-down' or %q == 'half-up') and half_step or page_step)
        local dir = (%q == 'line-down' or %q == 'half-down' or %q == 'page-down') and 1 or -1
        local max_top = math.max(1, (line_count - win_height) + 1)
        local view = vim.fn.winsaveview()
        local old_top = view.topline
        local old_lnum = view.lnum
        local new_top = math.max(1, math.min(old_top + (dir * step), max_top))
        local new_lnum = math.max(1, math.min(old_lnum + (dir * step), line_count))
        return { topline = new_top, lnum = new_lnum }
      end)
      router['scroll-main'](s.prompt_buf, %q)
      return target
    end)()
  ]], action, action, action, action, action, action))
  M.wait_for(function()
    local view = M.session_main_view()
    return view and target and view.topline == target.topline and view.lnum == target.lnum
  end, timeout_ms or 3000)
  return target
end

function M.compute_main_scroll_target(action)
  return M.child.lua_get(string.format([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not (s and s.meta and s.meta.win and vim.api.nvim_win_is_valid(s.meta.win.window)) then
        return nil
      end
      local win = s.meta.win.window
      return vim.api.nvim_win_call(win, function()
        local line_count = vim.api.nvim_buf_line_count(s.meta.buf.buffer)
        local win_height = math.max(1, vim.api.nvim_win_get_height(win))
        local half_step = math.max(1, math.floor(win_height / 2))
        local page_step = math.max(1, win_height - 2)
        local step = (%q == 'line-down' or %q == 'line-up') and 1
          or ((%q == 'half-down' or %q == 'half-up') and half_step or page_step)
        local dir = (%q == 'line-down' or %q == 'half-down' or %q == 'page-down') and 1 or -1
        local max_top = math.max(1, (line_count - win_height) + 1)
        local view = vim.fn.winsaveview()
        local old_top = view.topline
        local old_lnum = view.lnum
        local new_top = math.max(1, math.min(old_top + (dir * step), max_top))
        local new_lnum = math.max(1, math.min(old_lnum + (dir * step), line_count))
        return { topline = new_top, lnum = new_lnum }
      end)
    end)()
  ]], action, action, action, action, action, action))
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

function M.session_preview_visible()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local win = s and s['preview-win'] or nil
      return win and vim.api.nvim_win_is_valid(win) or false
    end)()
  ]])
end

function M.session_preview_view()
  local encoded = M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local win = s and s['preview-win'] or nil
      if not (win and vim.api.nvim_win_is_valid(win)) then
        return nil
      end
      local view = vim.api.nvim_win_call(win, function()
        return vim.fn.winsaveview()
      end)
      return vim.json.encode({
        lnum = view.lnum or 0,
        topline = view.topline or 0,
        height = vim.api.nvim_win_get_height(win),
      })
    end)()
  ]])
  if encoded == nil or encoded == vim.NIL then return nil end
  return vim.json.decode(encoded)
end

function M.session_preview_width()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local win = s and s['preview-win'] or nil
      if not (win and vim.api.nvim_win_is_valid(win)) then
        return 0
      end
      return vim.api.nvim_win_get_width(win)
    end)()
  ]])
end

function M.session_preview_screen_right()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local win = s and s['preview-win'] or nil
      if not (win and vim.api.nvim_win_is_valid(win)) then
        return 0
      end
      local pos = vim.fn.win_screenpos(win)
      local left = (pos and pos[2]) or 0
      local width = vim.api.nvim_win_get_width(win)
      return left + width - 1
    end)()
  ]])
end

function M.resize_editor_columns(columns)
  M.child.lua(string.format([[
    vim.o.columns = %d
    vim.cmd('redraw')
  ]], columns))
end

function M.editor_columns()
  return M.child.lua_get('return vim.o.columns')
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

function M.session_ui_hidden()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      return s and s['ui-hidden'] == true or false
    end)()
  ]])
end

function M.session_project_mode()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      return s and s['project-mode'] == true or false
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
  if not debug_dump_enabled then
    return
  end
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
  ensure_prompt_insert()
  local encoded = M.child.api.nvim_replace_termcodes(keys, true, false, true)
  M.child.api.nvim_input(encoded)
  M.dump_state("type " .. keys)
end

function M.type_prompt_text(text)
  ensure_prompt_insert()
  for i = 1, #text do
    M.child.api.nvim_input(string.sub(text, i, i))
  end
  M.dump_state("type_text " .. text)
end

function M.type_prompt_human(text, per_key_ms)
  local delay = per_key_ms or 25
  local slept = 0
  ensure_prompt_insert()
  for i = 1, #text do
    M.child.api.nvim_input(string.sub(text, i, i))
    if delay > 0 then
      vim.loop.sleep(delay)
      slept = slept + delay
    end
  end
  profiler.record('sleep', profiler.caller_label(2, 'type_prompt_human'), slept)
  M.dump_state("type_human " .. text)
end

function M.type_prompt_tokens(tokens, per_key_ms)
  local delay = per_key_ms or 25
  local slept = 0
  ensure_prompt_insert()
  for _, key in ipairs(tokens) do
    M.child.type_keys(0, key)
    if delay > 0 then
      vim.loop.sleep(delay)
      slept = slept + delay
    end
  end
  profiler.record('sleep', profiler.caller_label(2, 'type_prompt_tokens'), slept)
  M.dump_state("type_tokens " .. table.concat(tokens, " "))
end

return M
