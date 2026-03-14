local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['fuzzy matcher is testable via key switch and non-contiguous query'] = H.timed_case(function()
  H.open_meta_with_lines({
    'metabuffer router',
    'meta flow',
    'router util',
    'other line',
  })

  eq(H.session_matcher_name(), 'all')
  H.type_prompt('<C-^>')
  H.wait_for(function() return H.session_matcher_name() == 'fuzzy' end)

  H.type_prompt_text('mbr')
  H.wait_for(function() return H.session_query_text() == 'mbr' end)
  H.wait_for(function() return H.session_hit_count() == 1 end)
end)

return T
