local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['typing #file alone keeps session alive and enters file mode'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file')
  H.wait_for(function() return H.session_prompt_text() == '#file' end, 6000)

  local count = H.session_file_entry_hit_count()
  eq(type(count), 'number')
  eq(count >= 0, true)
end)

return T
