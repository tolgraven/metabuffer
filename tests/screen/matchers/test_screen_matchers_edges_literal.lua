local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['all matcher treats unclosed regex-like token as literal'] = H.timed_case(function()
  H.open_meta_with_lines({
    '(let [x 1] x)',
    '(if cond then)',
    'plain line',
  })

  H.type_prompt_text('(let')
  H.type_prompt(' ')
  H.wait_for(function() return H.session_query_text() == '(let' end)
  H.wait_for(function() return H.session_hit_count() == 1 end)
end)

return T
