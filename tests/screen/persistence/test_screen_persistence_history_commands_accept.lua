local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['enter from results window accepts selection and jumps to hit'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha row',
    'beta meta row',
    'gamma meta row',
  })

  H.type_prompt_text('meta')
  H.wait_for(function() return H.session_hit_count() == 2 end)

  H.type_prompt('<C-n>')
  local target = H.session_selected_ref()
  eq(type(target), 'table')

  child.cmd('stopinsert')
  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end)
  H.wait_for(function() return vim.api.nvim_win_get_cursor(0)[1] == target.lnum end)
end)

return T
