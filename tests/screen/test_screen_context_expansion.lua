local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['expansion directive opens and closes context window'] = H.timed_case(function()
  H.open_meta_with_lines({
    'local alpha = 1',
    'local beta = alpha + 1',
    'return alpha + beta',
  })

  H.type_prompt_human('#exp:line alpha', 90)
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
  H.wait_for(function()
    return H.session_context_exists()
  end, 4000)

  local context_line_count = #H.session_context_lines()
  eq(context_line_count > 0, true)

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
  H.wait_for(function()
    return not H.session_context_exists()
  end, 4000)
end)

T['file expansion renders full file context for filtered hits'] = H.timed_case(function()
  H.open_meta_with_lines({
    'local alpha = 1',
    'local beta = alpha + 1',
    'return alpha + beta',
  })

  H.type_prompt_human('#exp:file alpha', 90)
  H.wait_for(function()
    return H.child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return s and s['expansion-mode'] == 'file'
      end)()
    ]])
  end, 4000)
  H.wait_for(function()
    return H.session_context_exists()
  end, 4000)

  local lines = H.session_context_lines()
  eq(vim.tbl_contains(lines, '   1 local alpha = 1'), true)
  eq(vim.tbl_contains(lines, '   2 local beta = alpha + 1'), true)
  eq(vim.tbl_contains(lines, '   3 return alpha + beta'), true)
end)

return T
