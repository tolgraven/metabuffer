local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['json transform edits write back as compact source, not pretty-printed lines'] = H.timed_case(function()
  local path = child.lua_get([[
    (function()
      local path = vim.fn.tempname() .. '.jsonl'
      vim.fn.writefile({ '{"alpha":1,"beta":2}', 'tail' }, path)
      return path
    end)()
  ]])

  child.cmd('edit ' .. path)
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.type_keys(':', 'Meta', '<CR>')
  H.wait_for(H.session_active, 3000)

  H.type_prompt_text('#json')
  H.wait_for(function()
    local lines = H.session_result_lines()
    return type(lines) == 'table' and lines[1] == '{'
  end, 3000)

  H.type_prompt('<M-CR>')
  H.wait_for(function()
    return child.lua_get([[
      (function()
        local router = require('metabuffer.router')
        local s = router['active-by-source'][_G.__meta_source_buf]
        return s and s.meta and s.meta.win and vim.api.nvim_get_current_win() == s.meta.win.window or false
      end)()
    ]])
  end, 3000)

  child.type_keys('j')
  child.type_keys('c', 'c')
  child.type_keys('  "alpha": 3,')
  child.type_keys('<Esc>')
  child.cmd('write')

  eq(child.lua_get(string.format([[
    vim.fn.readfile(%q)
  ]], path)), {
    '{"alpha":3,"beta":2}',
    'tail',
  })
end)

return T
