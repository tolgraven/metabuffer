local H = require('tests.screen.support.screen_helpers')
local child = H.child

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['Meta with initial query argument applies immediately'] = H.timed_case(function()
  child.cmd('enew')
  child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha',
    'meta plugin',
    'metamorph',
    'other',
  })
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.cmd('Meta meta')

  H.wait_for(function()
    return child.lua_get("require('metabuffer.router')['active-by-source'][_G.__meta_source_buf] ~= nil")
  end)
  H.wait_for(function() return H.session_query_text() == 'meta' end)
  H.wait_for(function() return H.session_hit_count() == 2 end)
end)

return T
