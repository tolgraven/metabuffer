local H = require('tests.screen.support.screen_helpers')
local child = H.child

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['Meta !! and Meta !$ expand from previous invocation history'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha meta',
    'beta token',
    'gamma',
  })

  H.type_prompt_text('alpha meta')
  H.wait_for(function() return H.session_query_text() == 'alpha meta' end)
  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end)

  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.cmd('Meta !!')
  H.wait_for(function() return H.session_active() end)
  H.wait_for(function() return H.session_query_text() == 'alpha meta' end)
  H.close_meta_prompt()
  H.wait_for(function() return not H.session_active() end)

  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.cmd('Meta !$')
  H.wait_for(function() return H.session_active() end)
  H.wait_for(function() return H.session_query_text() == 'meta' end)
end)

return T
