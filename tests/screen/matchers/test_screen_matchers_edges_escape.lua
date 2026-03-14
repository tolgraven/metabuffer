local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['escaped control-like token stays literal and is not consumed'] = H.timed_case(function()
  H.open_meta_with_lines({
    'literal #deps marker',
    'plain deps text',
    'other row',
  })

  H.type_prompt_text('\\#deps')
  H.wait_for(function() return H.session_query_text() == '\\#deps' end)
  H.wait_for(function() return H.session_hit_count() == 1 end)
end)

return T
