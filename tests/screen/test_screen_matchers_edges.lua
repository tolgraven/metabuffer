local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['all matcher treats unclosed regex-like token as literal'] = H.timed_case(function()
  H.open_meta_with_lines({
    '(let [x 1] x)',
    '(if cond then)',
    'plain line',
  })

  H.type_prompt_human('(let', 90)
  H.type_prompt(' ')
  H.wait_for(function() return H.session_query_text() == '(let' end)
  H.wait_for(function() return H.session_hit_count() == 1 end)
end)

T['negation token excludes matching rows and broadens on delete'] = H.timed_case(function()
  H.open_meta_with_lines({
    'vim.api.nvim_buf_get_lines',
    'vim.api with pcall wrapper',
    'pcall only row',
    'vim.api other function',
  })

  H.type_prompt_human('vim.api !pcall', 95)
  H.wait_for(function() return H.session_query_text() == 'vim.api !pcall' end)
  H.wait_for(function() return H.session_hit_count() == 2 end)

  H.type_prompt_human(' extra', 90)
  H.wait_for(function() return H.session_query_text() == 'vim.api !pcall extra' end)
  H.wait_for(function() return H.session_hit_count() == 0 end)

  H.type_prompt_tokens({ '<BS>', '<BS>', '<BS>', '<BS>', '<BS>', '<BS>' }, 90)
  H.wait_for(function() return H.session_query_text() == 'vim.api !pcall' end)
  H.wait_for(function() return H.session_hit_count() == 2 end)
end)

T['escaped control-like token stays literal and is not consumed'] = H.timed_case(function()
  H.open_meta_with_lines({
    'literal #deps marker',
    'plain deps text',
    'other row',
  })

  H.type_prompt_human('\\#deps', 95)
  H.wait_for(function() return H.session_query_text() == '\\#deps' end)
  H.wait_for(function() return H.session_hit_count() == 1 end)
end)

return T
