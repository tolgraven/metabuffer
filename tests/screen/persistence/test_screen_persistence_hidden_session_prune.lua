local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['hidden regular session is removed when results buffer falls out of jumplist'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha meta one',
    'alpha meta two',
    'beta other',
  })

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_hit_count() == 2 end, 3000)
  H.type_prompt('<CR>')
  H.wait_for(function() return H.session_ui_hidden() end, 3000)

  child.cmd('clearjumps')
  child.cmd('enew')

  H.wait_for(function() return not H.session_active() end, 3000)
  eq(H.session_active(), false)
end)

return T
