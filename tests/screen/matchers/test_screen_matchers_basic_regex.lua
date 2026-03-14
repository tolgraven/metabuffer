local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regex matcher supports regex tokens and returns expected hits'] = H.timed_case(function()
  H.open_meta_with_lines({
    'valid abc',
    'valid xyz',
    'valid 123',
    'other row',
  })

  H.type_prompt('<C-^><C-^>')
  H.wait_for(function() return H.session_matcher_name() == 'regex' end)

  H.type_prompt_text('valid')
  H.type_prompt(' ')
  H.type_prompt_text('\\w.*')

  H.wait_for(function() return H.session_query_text() == 'valid \\w.*' end)
  H.wait_for(function() return H.session_hit_count() == 3 end)

  H.type_prompt_tokens({ '<BS>', '<BS>' }, 0)
  H.wait_for(function() return H.session_query_text() == 'valid \\w' end)
  H.wait_for(function() return H.session_hit_count() == 3 end)
end)

return T
