local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['saved prompt browser opens with ## and supports keyboard navigation+accept'] = H.timed_case(function()
  H.open_meta_with_lines({ 'alpha one', 'beta two', 'gamma three' })

  H.type_prompt_human('alpha #save:one', 80)
  H.wait_for(function() return H.session_query_text() == 'alpha' end)
  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end)

  H.open_meta_with_lines({ 'alpha one', 'beta two', 'gamma three' })
  H.type_prompt_human('beta #save:two', 80)
  H.wait_for(function() return H.session_query_text() == 'beta' end)
  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end)

  H.open_meta_with_lines({ 'alpha one', 'beta two', 'gamma three' })
  H.type_prompt('##')

  H.wait_for(function()
    local st = H.session_history_browser_state()
    return st and st.active == true and st.mode == 'saved' and st.count >= 2
  end, 6000)

  local before = H.session_history_browser_state()
  H.type_prompt('<Down>')
  H.wait_for(function()
    local st = H.session_history_browser_state()
    return st and st.index ~= before.index
  end)

  H.type_prompt('<CR>')
  H.wait_for(function()
    local st = H.session_history_browser_state()
    return st and st.active == false
  end)

  local q = H.session_query_text()
  eq((q == 'alpha' or q == 'beta'), true)
end)

return T
