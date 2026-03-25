local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.shared_child_hooks() })

T['regular Meta uses lgrep source and keeps remaining tokens as normal filters'] = H.timed_case(function()
  local root = H.make_temp_project()

  H.child.lua(string.format([[
    _G.__meta_test_lgrep_runner = function(_settings, spec)
      if spec.query == 'setup' then
        return {
          count = 2,
          results = {
            { file = 'lua/mod.lua', line = 1, score = 0.9, chunk = 'local metabuffer = true\nlocal meta = 1' },
            { file = 'doc/readme.md', line = 1, score = 0.6, chunk = 'meta docs\nmetam docs' },
          },
        }
      end
      return { count = 0, results = {} }
    end
  ]], root))

  H.child.cmd('cd ' .. root)
  H.child.cmd('edit ' .. root .. '/main.txt')
  H.child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  H.child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(H.session_active, 6000)

  H.type_prompt_human('#lg setup metabuffer', 20)
  H.wait_for(function() return H.session_query_text() == 'metabuffer' end, 6000)
  H.wait_for(function() return H.session_hit_count() == 1 end, 6000)

  local ref = H.session_selected_ref()
  eq(vim.fn.fnamemodify(ref.path, ':t'), 'mod.lua')
  eq(ref.lnum, 1)

  local hls = H.child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local ns = s['prompt-hl-ns']
      local prompt = vim.api.nvim_buf_get_extmarks(s['prompt-buf'], ns, { 0, 0 }, { 0, -1 }, { details = true })
      local matches = vim.api.nvim_win_call(s.meta.win.window, function()
        return vim.fn.getmatches()
      end)
      local groups = {}
      for _, item in ipairs(matches) do
        groups[#groups + 1] = item.group
      end
      return { prompt = prompt, groups = groups }
    end)()
  ]])

  local prompt_lgrep = false
  for _, mark in ipairs(hls.prompt or {}) do
    local details = mark[4] or {}
    if details.hl_group == 'MetaPromptLgrep' then
      prompt_lgrep = true
    end
  end
  eq(prompt_lgrep, true)

  local results_lgrep = false
  for _, group in ipairs(hls.groups or {}) do
    if group == 'MetaSearchHitLgrep' then
      results_lgrep = true
    end
  end
  eq(results_lgrep, true)
end)

T['regular Meta plain lgrep search updates visible results buffer content'] = H.timed_case(function()
  local root = H.make_temp_project()

  H.child.lua([[
    _G.__meta_test_lgrep_runner = function(_settings, spec)
      if spec.query == 'search' then
        return {
          count = 2,
          results = {
            { file = 'lua/mod.lua', line = 1, score = 0.9, chunk = 'local metabuffer = true\nlocal meta = 1' },
            { file = 'doc/readme.md', line = 1, score = 0.6, chunk = 'meta docs\nmetam docs' },
          },
        }
      end
      return { count = 0, results = {} }
    end
  ]])

  H.child.cmd('cd ' .. root)
  H.child.cmd('edit ' .. root .. '/main.txt')
  H.child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  H.child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(H.session_active, 6000)

  H.type_prompt_human('#lg search', 20)
  H.wait_for(function() return H.session_query_text() == '' end, 6000)
  H.wait_for(function() return H.session_hit_count() == 4 end, 6000)
  H.wait_for(function() return H.str_contains(H.session_main_statusline(), '+lgs') end, 6000)

  local ref = H.session_selected_ref()
  eq(vim.fn.fnamemodify(ref.path, ':t'), 'mod.lua')
  eq(ref.lnum, 1)

  H.wait_for(function()
    local lines = H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return vim.api.nvim_buf_get_lines(s.meta.buf.buffer, 0, 2, false)
      end)()
    ]])
    return type(lines) == 'table'
      and lines[1] == 'local metabuffer = true'
      and lines[2] == 'local meta = 1'
  end, 6000)
end)

return T
