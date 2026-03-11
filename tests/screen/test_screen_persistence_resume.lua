local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['Meta with initial query argument applies immediately'] = H.timed_case(function()
  child.cmd('enew')
  child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha',
    'meta plugin',
    'metamorph',
    'other',
  })
  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.cmd('Meta meta')

  H.wait_for(function()
    return child.lua_get("require('metabuffer.router')['active-by-source'][_G.__meta_source_buf] ~= nil")
  end)
  H.wait_for(function() return H.session_query_text() == 'meta' end)
  H.wait_for(function() return H.session_hit_count() == 2 end)
end)

T['prompt height persists between invocations'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')

  local start_h = H.session_prompt_win_height()
  eq(start_h > 0, true)
  local target_h = start_h + 2
  H.set_prompt_win_height(target_h)
  H.wait_for(function() return H.session_prompt_win_height() == target_h end)

  H.close_meta_prompt()
  H.wait_for(function() return not H.session_active() end)

  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_prompt_win_height() == target_h end)
end)

T['accept hit then MetaResume restores previous prompt and mode state'] = H.timed_case(function()
  H.open_meta_with_lines({
    'metabuffer alpha',
    'metabuffer beta',
    'metabuffer gamma',
    'other',
  })

  H.type_prompt_human('metabuffer', 90)
  H.wait_for(function() return H.session_query_text() == 'metabuffer' end)

  H.type_prompt('<C-^>')
  H.wait_for(function() return H.session_matcher_name() == 'fuzzy' end)
  H.type_prompt('<C-o>')
  local saved_case = H.session_case_mode()

  H.type_prompt('<C-n>')
  local selected = H.session_selected_ref()
  eq(type(selected), 'table')

  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end)
  H.wait_for(function() return vim.api.nvim_win_get_cursor(0)[1] == selected.lnum end)

  child.cmd('MetaResume')
  H.wait_for(function() return H.session_active() end)
  H.wait_for(function() return H.session_query_text() == 'metabuffer' end)
  H.wait_for(function() return H.session_matcher_name() == 'fuzzy' end)
  H.wait_for(function() return H.session_case_mode() == saved_case end)
end)

return T
