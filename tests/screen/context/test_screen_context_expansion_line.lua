local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['expansion directive opens and closes context window'] = H.timed_case(function()
  H.open_meta_with_lines({
    'local alpha = 1',
    'local beta = alpha + 1',
    'return alpha + beta',
  })

  H.type_prompt_text('#exp:line alpha')
  H.wait_for(function() return H.session_query_text() == 'alpha' end, 4000)
  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return s and s['expansion-mode'] == 'line'
      end)()
    ]])
  end, 4000)
  H.wait_for(function() return H.session_hit_count() > 1 end, 4000)

  local result_lines = H.session_result_lines()
  eq(#result_lines > 1, true)
  eq(vim.tbl_contains(result_lines, 'local alpha = 1'), true)

  H.child.lua([[
    local router = require('metabuffer.router')
    local s = router['active-by-source'][_G.__meta_source_buf]
    vim.api.nvim_buf_set_lines(s['prompt-buf'], 0, -1, false, { '#exp:none alpha' })
    router['on-prompt-changed'](s['prompt-buf'], true)
  ]])

  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return s and s['expansion-mode'] == 'none'
      end)()
    ]])
  end, 4000)
  H.wait_for(function() return H.session_hit_count() == 1 end, 4000)
end)

T['expansion follows the visible result viewport instead of expanding every hit'] = H.timed_case(function()
  H.child.g.meta_context_around_lines = 1
  H.open_meta_with_lines({
    'ctx A1',
    'alpha A',
    'ctx A2',
    'ctx B1',
    'alpha B',
    'ctx B2',
    'ctx C1',
    'alpha C',
    'ctx C2',
    'ctx D1',
    'alpha D',
    'ctx D2',
  })

  H.set_session_main_view(1, 1, 2)
  H.type_prompt_text('#exp:context alpha')
  H.wait_for(function() return H.session_query_text() == 'alpha' end, 4000)
  H.wait_for(function()
    local lines = H.session_result_lines()
    return vim.tbl_contains(lines, 'ctx A1') and not vim.tbl_contains(lines, 'ctx D1')
  end, 4000)

  H.set_session_main_view(7, 7, 2)
  H.child.cmd('doautocmd <nomodeline> WinScrolled')
  H.wait_for(function()
    local lines = H.session_result_lines()
    return vim.tbl_contains(lines, 'ctx D1') and vim.tbl_contains(lines, 'ctx D2')
  end, 4000)
end)

return T
