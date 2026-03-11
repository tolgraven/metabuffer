local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project deps flag toggle tokens are consumed and state flips deterministically'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')

  H.type_prompt_human('#deps meta', 100)
  H.wait_for(function() return H.session_query_text() == 'meta' end, 6000)
  H.wait_for(function() return H.str_contains(H.session_debug_out(), '+dep') end, 6000)

  H.type_prompt('<C-u>')
  H.wait_for(function() return H.session_query_text() == '' end, 6000)

  H.type_prompt_human('#-deps meta', 100)
  H.wait_for(function() return H.session_query_text() == 'meta' end, 6000)
  H.wait_for(function() return H.str_contains(H.session_debug_out(), '-dep') end, 6000)
end)

return T
