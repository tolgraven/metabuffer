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

return T
