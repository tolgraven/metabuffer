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

T['broadening by delete keeps selected result rank stable'] = H.timed_case(function()
  local lines = {}
  for i = 1, 36 do
    if i % 3 == 0 then
      lines[#lines + 1] = ('needle extra line %d'):format(i)
    elseif i % 2 == 0 then
      lines[#lines + 1] = ('needle line %d'):format(i)
    else
      lines[#lines + 1] = ('other line %d'):format(i)
    end
  end

  H.open_meta_with_lines(lines)

  H.type_prompt_text('needle extra')
  H.wait_for(function() return H.session_query_text() == 'needle extra' end)
  H.wait_for(function() return H.session_hit_count() == 12 end)

  H.child.type_keys('<C-n>', '<C-n>', '<C-n>', '<C-n>')
  H.wait_for(function()
    local cur = H.session_main_cursor()
    return cur and cur[1] == 5
  end)

  H.type_prompt_tokens({ '<BS>', '<BS>', '<BS>', '<BS>', '<BS>', '<BS>' }, 0)
  H.wait_for(function() return H.session_query_text() == 'needle' end)
  H.wait_for(function() return H.session_hit_count() == 24 end)
  H.wait_for(function()
    local cur = H.session_main_cursor()
    return cur and cur[1] == 5
  end)
end)

return T
