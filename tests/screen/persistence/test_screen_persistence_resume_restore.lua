local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['accept hit then MetaResume restores previous prompt and mode state'] = H.timed_case(function()
  H.open_meta_with_lines({
    'metabuffer alpha',
    'metabuffer beta',
    'metabuffer gamma',
    'other',
  })

  H.type_prompt_text('metabuffer')
  H.wait_for(function() return H.session_query_text() == 'metabuffer' end)

  H.type_prompt('<C-^>')
  H.wait_for(function() return H.session_matcher_name() == 'fuzzy' end)
  H.type_prompt('<C-o>')
  local saved_case = H.session_case_mode()

  H.type_prompt('<C-n>')
  local selected = H.session_selected_ref()
  eq(type(selected), 'table')

  H.type_prompt('<CR>')
  H.wait_for(function() return H.session_ui_hidden() end)
  H.wait_for(function() return vim.api.nvim_win_get_cursor(0)[1] == selected.lnum end)

  child.cmd('MetaResume')
  H.wait_for(function() return H.session_active() end)
  H.wait_for(function() return not H.session_ui_hidden() end)
  H.wait_for(function() return H.session_query_text() == 'metabuffer' end)
  H.wait_for(function() return H.session_matcher_name() == 'fuzzy' end)
  H.wait_for(function() return H.session_case_mode() == saved_case end)
end)

return T
