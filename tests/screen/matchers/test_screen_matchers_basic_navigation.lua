local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['main-window hotkeys move selection and keep statusline live'] = H.timed_case(function()
  H.open_meta_with_lines({
    'meta one',
    'meta two',
    'meta three',
    'meta four',
  })

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_hit_count() == 4 end)

  child.cmd('stopinsert')
  H.type_prompt('<C-n>')
  H.type_prompt('<C-n>')
  local ref = H.session_selected_ref()
  eq(type(ref), 'table')
  eq(ref.lnum > 1, true)

  local sl = H.session_statusline()
  eq(type(sl), 'string')
  eq(#sl > 0, true)
end)

return T
