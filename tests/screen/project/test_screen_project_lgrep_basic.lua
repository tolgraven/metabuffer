local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.shared_child_hooks() })

T['project Meta uses lgrep source and positions selection on first hit'] = H.timed_case(function()
  local root = H.make_temp_project()

  H.child.lua([[
    _G.__meta_test_lgrep_runner = function(_settings, spec)
      if spec.kind == 'usages' and spec.query == 'setup' then
        return {
          count = 2,
          results = {
            { file = 'lua/mod.lua', line = 1, score = 0.7, chunk = 'local metabuffer = true\nlocal meta = 1' },
            { file = 'main.txt', line = 205, score = 0.9, chunk = 'contains meta token 5\ncontains meta token 6' },
          },
        }
      end
      return { count = 0, results = {} }
    end
  ]])

  H.open_project_meta_in_dir(root, 'main.txt')
  H.type_prompt_human('#lg:u setup', 20)
  H.wait_for(function() return H.session_query_text() == '' end, 6000)
  H.wait_for(function() return H.session_hit_count() == 4 end, 6000)

  local ref = H.session_selected_ref()
  eq(vim.fn.fnamemodify(ref.path, ':t'), 'main.txt')
  eq(ref.lnum, 205)
end)

T['project Meta plain lgrep search jumps to the first search hit start'] = H.timed_case(function()
  local root = H.make_temp_project()

  H.child.lua([[
    _G.__meta_test_lgrep_runner = function(_settings, spec)
      if spec.kind == 'search' and spec.query == 'setup' then
        return {
          count = 2,
          results = {
            { file = 'lua/mod.lua', line = 40, score = 0.6, chunk = 'local metabuffer = true\nlocal meta = 1' },
            { file = 'main.txt', line = 205, score = 0.9, chunk = 'contains meta token 5\ncontains meta token 6' },
          },
        }
      end
      return { count = 0, results = {} }
    end
  ]])

  H.child.cmd('cd ' .. root)
  H.child.cmd('edit ' .. root .. '/main.txt')
  H.child.cmd('normal! 150G')
  H.child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  H.child.type_keys(':', 'Meta!', '<CR>')
  H.wait_for(H.session_active, 6000)

  H.type_prompt_human('#lg setup', 20)
  H.wait_for(function() return H.session_query_text() == '' end, 6000)
  H.wait_for(function() return H.session_hit_count() == 4 end, 6000)

  local ref = H.session_selected_ref()
  eq(vim.fn.fnamemodify(ref.path, ':t'), 'main.txt')
  eq(ref.lnum, 205)

  local snap = H.session_info_snapshot()
  eq(type(snap), 'table')
  eq(type(snap.line), 'string')
  eq(vim.trim(vim.fn.strcharpart(snap.line, 0, 2)) ~= '', true)
end)

return T
