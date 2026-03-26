local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['prompt height persists between invocations'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')

  local start_h = H.session_prompt_win_height()
  eq(start_h > 0, true)
  local target_h = start_h + 2
  H.set_prompt_win_height(target_h)
  H.wait_for(function() return H.session_prompt_win_height() == target_h end)

  H.close_meta_prompt()
  H.wait_for(H.session_not_visible)

  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_prompt_win_height() == target_h end)
end)

return T
