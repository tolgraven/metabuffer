local H = require('tests.screen.support.screen_helpers')
local child = H.child

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['history up-recall does not accumulate duplicate consumed setting tokens'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_text('#deps meta')
  H.wait_for(function() return H.session_prompt_text() == 'meta' end, 6000)
  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end, 6000)

  H.set_source_buf_to_current()
  child.cmd('Meta!')
  H.wait_for(function() return H.session_active() end, 6000)
  H.type_prompt('<Up>')
  H.wait_for(function() return H.str_contains(H.session_prompt_text(), '#+deps') end, 6000)
  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end, 6000)

  H.set_source_buf_to_current()
  child.cmd('Meta!')
  H.wait_for(function() return H.session_active() end, 6000)
  H.type_prompt('<Up>')
  H.wait_for(function()
    local txt = H.session_prompt_text()
    if txt == '' then return false end
    local _, count = string.gsub(txt, '#%+deps', '')
    return count == 1
  end, 6000)
end)

return T
