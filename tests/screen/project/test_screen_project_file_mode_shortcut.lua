local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['file shortcut token ./query enables file mode and applies file token'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('./README.md')
  H.wait_for(function() return H.session_query_text() == '' end, 6000)
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)

  local first_line = H.session_first_file_entry_line()
  eq(type(first_line), 'string')
  eq(string.find(string.lower(first_line), 'readme', 1, true) ~= nil, true)

  local dbg = H.session_debug_out()
  eq(H.str_contains(dbg, '+fil'), true)
end)

return T
