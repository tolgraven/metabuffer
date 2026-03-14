local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['file expansion renders full file context for filtered hits'] = H.timed_case(function()
  H.open_meta_with_lines({
    'local alpha = 1',
    'local beta = alpha + 1',
    'return alpha + beta',
  })

  H.type_prompt_text('#exp:file alpha')
  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return s and s['expansion-mode'] == 'file'
      end)()
    ]])
  end, 4000)
  H.wait_for(function() return H.session_hit_count() == 3 end, 4000)

  local lines = H.session_result_lines()
  eq(vim.tbl_contains(lines, 'local alpha = 1'), true)
  eq(vim.tbl_contains(lines, 'local beta = alpha + 1'), true)
  eq(vim.tbl_contains(lines, 'return alpha + beta'), true)
end)

return T
