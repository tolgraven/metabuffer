local M = {}
local profiler = require('tests.support.profiler')

M.child = MiniTest.new_child_neovim()
M.eq = MiniTest.expect.equality

local debug_dump_path = "/tmp/metabuffer-mini-integration.log"
local debug_dump_enabled = vim.env.TEST_DEBUG_DUMP == '1'
local stress_wait_scale = tonumber(vim.env.META_STRESS_WAIT_SCALE or '1') or 1
local session_resolver = [[
  local function resolve_session()
    local router = require('metabuffer.router')
    local source = rawget(_G, '__meta_source_buf')
    local s = source and router['active-by-source'][source] or nil
    if s then
      return s
    end
    local uniq, found = {}, nil
    for _, session in pairs(router['active-by-prompt']) do
      if session and not uniq[session] then
        uniq[session] = true
        if found and found ~= session then
          return nil
        end
        found = session
      end
    end
    if found and found['source-buf'] then
      _G.__meta_source_buf = found['source-buf']
    end
    return found
  end
  local s = resolve_session()
]]

local function session_expr(body)
  return ([[(function()
%s
%s
end)()]]):format(session_resolver, body)
end

local function hook_dump(tag)
  if not debug_dump_enabled then
    return
  end
  vim.fn.writefile({ '[hook] ' .. tag }, debug_dump_path, 'a')
end

function M.wait_for(pred, timeout_ms)
  local ok = profiler.measure('wait', profiler.caller_label(2, 'wait_for'), function()
    local timeout = math.max(50, math.floor((timeout_ms or 3000) * stress_wait_scale))
    return vim.wait(timeout, pred, 20)
  end)
  M.eq(ok, true)
end

function M.child_setup()
  local root = vim.fn.getcwd()
  local worker_idx = tonumber(vim.env.TEST_WORKER_INDEX or '') or 1
  local startup_jitter = (worker_idx % 8) * 15

  if startup_jitter > 0 then
    vim.loop.sleep(startup_jitter)
  end

  profiler.measure('child', 'child.restart', function()
    local last_err = nil
    for attempt = 1, 4 do
      local ok, err = pcall(function()
        M.child.restart(
          {
            "--cmd", "let $TEST_PROFILE=''",
            "--cmd", "let $TEST_PROFILE_PATH=''",
            "-u", root .. "/tests/minimal_init.lua", "-n", "-i", "NONE"
          },
          { connection_timeout = 12000 }
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
  M.child.lua(string.format([[
    vim.o.hidden = true
    vim.o.swapfile = false
    vim.cmd("cd %s")
    _G.__meta_debug_dump_path = %q
    require('tests.support.runtime_guard').clear()
  ]], root, debug_dump_path))
end

function M.stop_child_once()
  if M.child.is_running() then
    local job = M.child.job
    pcall(function()
      if job and job.channel then
        vim.rpcnotify(job.channel, 'nvim_exec_lua', [[
          pcall(vim.cmd, 'stopinsert')
          vim.schedule(function()
            pcall(vim.cmd, 'silent! qa!')
          end)
        ]], {})
      end
    end)
    if job and job.id then
      vim.fn.jobwait({ job.id }, 300)
    end
    pcall(function()
      if job and job.channel then
        vim.fn.chanclose(job.channel)
      end
    end)
    pcall(function()
      if job and job.id then
        vim.fn.chanclose(job.id)
      end
    end)
    pcall(function()
      if job and job.address then
        vim.fn.delete(job.address)
      end
    end)
    M.child.job = nil
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
  return M.child.lua_get(session_expr([[
    return not not (s and s['prompt-win'] and vim.api.nvim_get_current_win() == s['prompt-win'])
  ]]))
end

function M.session_results_focused()
  return M.child.lua_get(session_expr([[
    return not not (s and s.meta and s.meta.win and vim.api.nvim_get_current_win() == s.meta.win.window)
  ]]))
end

function M.set_source_buf_to_current()
  M.child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
end

function M.source_buf()
  return M.child.lua_get('_G.__meta_source_buf')
end

function M.current_buf()
  return M.child.api.nvim_get_current_buf()
end

function M.current_buf_matches(bufnr)
  return M.current_buf() == bufnr
end

function M.current_buf_is_source()
  return M.current_buf() == M.source_buf()
end

function M.buf_name(bufnr)
  return M.child.api.nvim_buf_get_name(bufnr or 0)
end

function M.current_buf_name()
  return M.buf_name(0)
end

function M.current_buf_name_matches(path)
  return M.current_buf_name() == path
end

function M.current_filetype()
  return M.child.bo.filetype
end

function M.current_cursor()
  return M.child.api.nvim_win_get_cursor(0)
end

function M.current_line()
  return M.child.fn.line('.')
end

function M.read_file(path)
  return M.child.fn.readfile(path)
end

function M.file_readable(path)
  return M.child.fn.filereadable(path)
end

function M.write_temp_file(lines, suffix, mode)
  local path = M.child.fn.tempname() .. (suffix or '')
  if mode == nil then
    M.child.fn.writefile(lines, path)
  else
    M.child.fn.writefile(lines, path, mode)
  end
  return path
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
      hook_dump('pre_case/before-child-setup')
      M.child_setup()
      hook_dump('pre_case/after-child-setup')
    end,
    post_case = function()
      hook_dump('post_case/start')
      M.stop_child_once()
      hook_dump('post_case/end')
    end,
    post_once = function()
      hook_dump('post_once/start')
      M.stop_child_once()
      hook_dump('post_once/end')
    end,
  }
end

function M.shared_child_hooks()
  return {
    pre_once = function()
      hook_dump('pre_once/shared-child-setup')
      M.child_setup()
      hook_dump('pre_once/shared-child-setup-done')
    end,
    pre_case = function()
      hook_dump('pre_case/shared-reset')
      pcall(function()
        M.child.lua([[
          (function()
            local r = require('metabuffer.router')
            for k, s in pairs(r['active-by-prompt'] or {}) do
              pcall(function()
                s.closing = true
                if s.meta and s.meta.win then
                  pcall(function() s.meta.win:close() end)
                end
              end)
            end
            r['active-by-prompt'] = {}
            r['active-by-source'] = {}
            r['sessions'] = {}
            vim.cmd('silent! %bwipeout!')
            vim.cmd('enew')
          end)()
        ]])
      end)
      hook_dump('pre_case/shared-reset-done')
    end,
    post_case = function()
      hook_dump('post_case/shared-noop')
    end,
    post_once = function()
      hook_dump('post_once/shared-stop')
      M.stop_child_once()
      hook_dump('post_once/shared-stop-done')
    end,
  }
end

--- Hooks for cross-set child sharing within a MiniTest batch.
--- Unlike shared_child_hooks(), the child is NOT stopped in post_once.
--- This lets multiple test files batched into one MiniTest process share
--- a single child nvim, eliminating ~2s startup per additional file.
--- The child dies when the parent nvim exits at batch end.
function M.batch_child_hooks()
  return {
    pre_once = function()
      hook_dump('pre_once/batch-child-check')
      if not M.child.is_running() then
        hook_dump('pre_once/batch-child-setup')
        M.child_setup()
        hook_dump('pre_once/batch-child-setup-done')
      else
        hook_dump('pre_once/batch-child-reuse')
      end
    end,
    pre_case = function()
      hook_dump('pre_case/batch-reset')
      pcall(function()
        M.child.lua([[
          (function()
            local r = require('metabuffer.router')
            for k, s in pairs(r['active-by-prompt'] or {}) do
              pcall(function()
                s.closing = true
                if s.meta and s.meta.win then
                  pcall(function() s.meta.win:close() end)
                end
              end)
            end
            r['active-by-prompt'] = {}
            r['active-by-source'] = {}
            r['sessions'] = {}
            vim.cmd('silent! %bwipeout!')
            vim.cmd('enew')
          end)()
        ]])
      end)
      hook_dump('pre_case/batch-reset-done')
    end,
    post_case = function()
      hook_dump('post_case/batch-noop')
    end,
    post_once = function()
      hook_dump('post_once/batch-keep-alive')
      -- Intentionally NOT stopping child.
      -- It will be reused by the next test set in this batch,
      -- or killed when the parent nvim process exits.
    end,
  }
end

function M.timed_case(fn)
  return fn
end

function M.open_meta_with_lines(lines)
  M.child.lua(string.format([[
    vim.cmd('enew')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, %s)
    _G.__meta_source_buf = vim.api.nvim_get_current_buf()
    vim.cmd('Meta')
    if vim.g.meta_test_no_startinsert then pcall(vim.cmd, 'stopinsert') end
  ]], vim.inspect(lines)))
  M.wait_for(function()
    return M.session_active()
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

   -- Shared pre-copied fixture: skip in-child file creation, just seed file cache.
  -- Resolve symlinks (macOS /var -> /private/var) so cache key matches getcwd().
  local shared = vim.env.META_TEST_FIXTURE_ROOT
  if shared and shared ~= '' and vim.fn.isdirectory(shared) == 1 then
    local resolved = vim.uv.fs_realpath(shared) or shared
    M._fixture_root = resolved
    M.child.lua(string.format([[
      (function()
        local root = %q
        local all_files = vim.fn.globpath(root, '**/*', true, true)
        local visible = {}
        for _, f in ipairs(all_files) do
          if vim.fn.isdirectory(f) == 0
            and not f:find('/.hidden/', 1, true)
            and not f:find('/ignored/', 1, true) then
            visible[#visible + 1] = f
          end
        end
        local cache = {}
        cache[root .. '|0|0|0'] = visible
        cache[root .. '|0|0|1'] = all_files
        cache[root .. '|0|1|0'] = visible
        cache[root .. '|0|1|1'] = all_files
        cache[root .. '|1|0|0'] = all_files
        cache[root .. '|1|0|1'] = all_files
        cache[root .. '|1|1|0'] = all_files
        cache[root .. '|1|1|1'] = all_files
        vim.g.__meta_project_file_list_cache = cache
      end)()
    ]], resolved))
    return M._fixture_root
  end

  -- Fallback: create fixture inside child nvim (slower).
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
      root = vim.uv.fs_realpath(root) or root
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

      -- Pre-seed project file list cache so rg never runs under test load.
      local all_files = vim.fn.globpath(root, '**/*', true, true)
      local visible = {}
      for _, f in ipairs(all_files) do
        if vim.fn.isdirectory(f) == 0
          and not f:find('/.hidden/', 1, true)
          and not f:find('/ignored/', 1, true) then
          visible[#visible + 1] = f
        end
      end
      -- Cache with all four key variants used by project-file-list.
      local cache = {}
      cache[root .. '|0|0|0'] = visible
      cache[root .. '|0|0|1'] = all_files
      cache[root .. '|0|1|0'] = visible
      cache[root .. '|0|1|1'] = all_files
      cache[root .. '|1|0|0'] = all_files
      cache[root .. '|1|0|1'] = all_files
      cache[root .. '|1|1|0'] = all_files
      cache[root .. '|1|1|1'] = all_files
      vim.g.__meta_project_file_list_cache = cache

      return root
    end)()
  ]])
  return M._fixture_root
end

function M.open_project_meta_from_file(path)
  local root = project_root_for_tests()
  M.child.lua(string.format([[
    vim.cmd("cd %s")
    vim.cmd("edit %s/%s")
    _G.__meta_source_buf = vim.api.nvim_get_current_buf()
    vim.cmd('Meta!')
    if vim.g.meta_test_no_startinsert then pcall(vim.cmd, 'stopinsert') end
  ]], root, root, path))
  M.wait_for(function()
    return M.session_active()
  end, 6000)
end

function M.open_fixture_file(path)
  return M.open_project_meta_from_file(path)
end

function M.edit_fixture_file(path)
  local root = project_root_for_tests()
  M.child.lua(string.format([[
    vim.cmd("cd %s")
    vim.cmd("edit %s/%s")
    _G.__meta_source_buf = vim.api.nvim_get_current_buf()
  ]], root, root, path))
end

local _temp_project_counter = 0

function M.make_temp_project()
  local src = vim.env.META_TEST_TEMP_PROJECT_SRC
  if src and src ~= '' and vim.fn.isdirectory(src) == 1 then
    _temp_project_counter = _temp_project_counter + 1
    local dest = vim.fn.tempname() .. '_tp' .. _temp_project_counter
    vim.fn.system({ 'cp', '-R', src, dest })
    local root = vim.uv.fs_realpath(dest) or dest
    M.child.lua(string.format([[
      (function()
        local root = %q
        local files = {
          root .. "/main.txt",
          root .. "/doc/readme.md",
          root .. "/lua/mod.lua",
          root .. "/README.md",
        }
        local prev = vim.g.__meta_project_file_list_cache or {}
        for _, k in ipairs({
          root .. "|0|0|0", root .. "|0|0|1", root .. "|0|1|0", root .. "|0|1|1",
          root .. "|1|0|0", root .. "|1|0|1", root .. "|1|1|0", root .. "|1|1|1",
        }) do
          prev[k] = files
        end
        vim.g.__meta_project_file_list_cache = prev
      end)()
    ]], root))
    return root
  end

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
      vim.fn.writefile({ "# Temp project README" }, root .. "/README.md")

      -- Seed rg file-list cache so project-file-list skips rg.
      local files = {
        root .. "/main.txt",
        root .. "/doc/readme.md",
        root .. "/lua/mod.lua",
        root .. "/README.md",
      }
      local prev = vim.g.__meta_project_file_list_cache or {}
      prev[root .. "|0|0|0"] = files
      prev[root .. "|0|0|1"] = files
      prev[root .. "|0|1|0"] = files
      prev[root .. "|0|1|1"] = files
      prev[root .. "|1|0|0"] = files
      prev[root .. "|1|0|1"] = files
      prev[root .. "|1|1|0"] = files
      prev[root .. "|1|1|1"] = files
      vim.g.__meta_project_file_list_cache = prev

      return root
    end)()
  ]])
end

function M.open_project_meta_in_dir(root, relpath)
  M.child.lua(string.format([[
    vim.cmd("cd %s")
    vim.cmd("edit %s/%s")
    _G.__meta_source_buf = vim.api.nvim_get_current_buf()
    vim.cmd('Meta!')
    if vim.g.meta_test_no_startinsert then pcall(vim.cmd, 'stopinsert') end
  ]], root, root, relpath))
  M.wait_for(function()
    return M.session_active()
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
  local encoded = M.child.lua_get(session_expr([[
    if not s then return nil end
    local info_win, info_buf = s['info-win'], s['info-buf']
    if not (info_win and vim.api.nvim_win_is_valid(info_win) and info_buf and vim.api.nvim_buf_is_valid(info_buf)) then
      return nil
    end
    local ns = vim.api.nvim_create_namespace('MetaInfoSelection')
    local marks = vim.api.nvim_buf_get_extmarks(info_buf, ns, 0, -1, {})
    local row = nil
    if type(marks) == 'table' and #marks > 0 then
      row = (marks[1][2] or 0) + 1
    else
      row = vim.api.nvim_win_get_cursor(info_win)[1]
    end
    local line = vim.api.nvim_buf_get_lines(info_buf, row - 1, row, false)[1] or ''
    local view = vim.api.nvim_win_call(info_win, function()
      return vim.fn.winsaveview()
    end)
    local topline = math.max(1, (view and view.topline) or 1)
    local first_visible = vim.api.nvim_buf_get_lines(info_buf, topline - 1, topline, false)[1] or ''
    local count = vim.api.nvim_buf_line_count(info_buf)
    return vim.json.encode({
      row = row,
      line = line,
      count = count,
      topline = topline,
      first_visible = first_visible,
    })
  ]]))
  if encoded == nil or encoded == vim.NIL then return nil end
  return vim.json.decode(encoded)
end

function M.session_info_winbar()
  return M.child.lua_get(session_expr([[
    if not s then return nil end
    local info_win = s['info-win']
    if not (info_win and vim.api.nvim_win_is_valid(info_win)) then
      return nil
    end
    return vim.api.nvim_get_option_value('winbar', { win = info_win })
  ]]))
end

function M.start_info_blank_watch(duration_ms)
  M.child.lua(string.format([[
    (function()
      _G.__meta_info_blank_watch_done = false
      _G.__meta_info_blank_seen = false
      local deadline = vim.loop.now() + %d
      local function sample()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        if s then
          local info_win, info_buf = s['info-win'], s['info-buf']
          if info_win and vim.api.nvim_win_is_valid(info_win) and info_buf and vim.api.nvim_buf_is_valid(info_buf) then
            local view = vim.api.nvim_win_call(info_win, function()
              return vim.fn.winsaveview()
            end)
            local topline = math.max(1, (view and view.topline) or 1)
            local height = math.max(1, vim.api.nvim_win_get_height(info_win))
            local bottom = math.min(vim.api.nvim_buf_line_count(info_buf), topline + height - 1)
            if bottom < topline then
              _G.__meta_info_blank_seen = true
            else
              local lines = vim.api.nvim_buf_get_lines(info_buf, topline - 1, bottom, false)
              for _, line in ipairs(lines) do
                if line == '' then
                  _G.__meta_info_blank_seen = true
                  break
                end
              end
            end
          end
        end
        if vim.loop.now() >= deadline then
          _G.__meta_info_blank_watch_done = true
        else
          vim.defer_fn(sample, 10)
        end
      end
      sample()
    end)()
  ]], duration_ms or 800))
end

function M.info_blank_watch_done()
  return M.child.lua_get('not not _G.__meta_info_blank_watch_done')
end

function M.info_blank_seen()
  return M.child.lua_get('not not _G.__meta_info_blank_seen')
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

function M.session_main_wrap()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not (s and s.meta and s.meta.win) then
        return false
      end
      local win = s.meta.win.window
      if not (win and vim.api.nvim_win_is_valid(win)) then
        return false
      end
      local ok, val = pcall(vim.api.nvim_get_option_value, 'wrap', { win = win })
      return ok and not not val or false
    end)()
  ]])
end

function M.set_session_main_wrap(enabled)
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
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_set_option_value('wrap', %s, { win = win })
      vim.api.nvim_set_option_value('linebreak', %s, { win = win })
    end)()
  ]], enabled and 'true' or 'false', enabled and 'true' or 'false'))
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
  ]], action, action, action, action, action, action, action, action))
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
  ]], action, action, action, action, action, action, action))
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
  return M.child.lua_get(session_expr([[
    local win = s and s['preview-win'] or nil
    return win and vim.api.nvim_win_is_valid(win) or false
  ]]))
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
  return M.child.o.columns
end

function M.session_prompt_win_height()
  return M.child.lua_get(session_expr([[
    local win = s and s['prompt-win'] or nil
    if not (win and vim.api.nvim_win_is_valid(win)) then return -1 end
    return vim.api.nvim_win_get_height(win)
  ]]))
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
  return M.child.lua_get(session_expr([[
    return s ~= nil
  ]]))
end

function M.session_ui_hidden()
  return M.child.lua_get(session_expr([[
    return s and s['ui-hidden'] == true or false
  ]]))
end

function M.session_not_visible()
  return M.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      return (s == nil) or (s['ui-hidden'] == true)
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
  M.child.lua(string.format([[
    (function()
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
      local encoded = vim.api.nvim_replace_termcodes(%q, true, false, true)
      vim.api.nvim_input(encoded)
    end)()
  ]], keys))
  M.dump_state("type " .. keys)
end

function M.type_prompt_text(text)
  M.child.lua(string.format([[
    (function()
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
      local text = %q
      for i = 1, #text do
        vim.api.nvim_input(string.sub(text, i, i))
      end
    end)()
  ]], text))
  M.dump_state("type_text " .. text)
end

function M.type_prompt_human(text, per_key_ms)
  local delay = per_key_ms or 25
  local slept = 0
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
