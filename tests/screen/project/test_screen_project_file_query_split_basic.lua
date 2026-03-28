local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['file flag token is separate from normal query terms on same line'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#file:README lua')
  H.wait_for(function() return H.session_query_text() == 'lua' end, 6000)
  H.wait_for(function() return H.session_file_entry_hit_count() > 0 end, 6000)
end)

return T
