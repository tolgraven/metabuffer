local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['Meta !! replay restores prompt after accept'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha meta',
    'beta token',
    'gamma',
  })

  H.type_prompt_text('alpha meta')
  H.wait_for(function() return H.session_query_text() == 'alpha meta' end)
  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end)

  H.child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  H.child.cmd('Meta !!')
  H.wait_for(function() return H.session_active() end)
  H.wait_for(function() return H.session_query_text() == 'alpha meta' end)
end)

return T
