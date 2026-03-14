local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['filters short tokens and supports prompt edit hotkeys'] = H.timed_case(function()
  H.open_meta_with_lines({
    'lua api',
    'meta plugin',
    'metamorph check',
    'tolerance token',
    'topic branch',
    'other',
  })

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_query_text() == 'meta' end)
  H.wait_for(function() return H.session_hit_count() == 2 end)

  H.type_prompt('<C-a>')
  H.type_prompt('^')
  H.type_prompt('<C-e>')
  H.type_prompt('$')
  H.wait_for(function() return H.session_query_text() == '^meta$' end)

  H.type_prompt('<C-u>')
  H.wait_for(function() return H.session_query_text() == '' end)
  H.type_prompt_text('metabuffer')
  H.type_prompt('<C-u>')
  H.type_prompt('<C-y>')
  H.wait_for(function() return H.session_query_text() == 'metabuffer' end)
end)

return T
