local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular meta keeps info window with line numbers only'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha one',
    'alpha two',
    'beta three',
    'alpha four',
  })

  H.type_prompt_text('alpha')
  H.wait_for(function() return H.session_hit_count() == 3 end)
  H.wait_for(function() return type(H.session_info_snapshot()) == 'table' end)

  local snap = H.session_info_snapshot()
  eq(type(snap.line), 'string')
  eq(string.find(snap.line, 'alpha', 1, true) == nil, true)
  eq(string.find(snap.line, 'one', 1, true) == nil, true)
  eq(string.find(snap.line, '1', 1, true) ~= nil, true)
end)

return T
