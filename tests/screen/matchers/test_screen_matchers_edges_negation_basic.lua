local H = require('tests.screen.support.screen_helpers')

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['negation token excludes matching rows and broadens on delete'] = H.timed_case(function()
  H.open_meta_with_lines({
    'vim.api.nvim_buf_get_lines',
    'vim.api with pcall wrapper',
    'pcall only row',
    'vim.api other function',
  })

  H.type_prompt_text('vim.api !pcall')
  H.wait_for(function() return H.session_query_text() == 'vim.api !pcall' end)
  H.wait_for(function() return H.session_hit_count() == 2 end)

  H.type_prompt_text(' extra')
  H.wait_for(function() return H.session_query_text() == 'vim.api !pcall extra' end)
  H.wait_for(function() return H.session_hit_count() == 0 end)

  H.type_prompt_tokens({ '<BS>', '<BS>', '<BS>', '<BS>', '<BS>', '<BS>' }, 0)
  H.wait_for(function() return H.session_query_text() == 'vim.api !pcall' end)
  H.wait_for(function() return H.session_hit_count() == 2 end)
end)

return T
