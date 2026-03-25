local H = require('tests.screen.support.screen_helpers')
local child = H.child
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['saved prompt replay does not duplicate explicit hidden and deps flags with synthetic variants'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_active() end, 6000)

  H.type_prompt_text('#hidden #deps')
  H.wait_for(function()
    return H.session_prompt_text() == ''
  end, 6000)

  H.child.type_keys(':', 'MetaPush #save:flags', '<CR>')
  H.wait_for(function() return H.session_active() end, 6000)

  H.close_meta_prompt()
  H.wait_for(H.session_not_visible, 6000)

  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.cmd('Meta! ##flags')
  H.wait_for(function() return H.session_active() end, 6000)

  H.wait_for(function()
    local txt = H.session_prompt_text()
    if txt == '' then return false end
    local _, hidden_explicit = string.gsub(txt, '#hidden', '')
    local _, deps_explicit = string.gsub(txt, '#deps', '')
    local _, hidden_synth = string.gsub(txt, '#%+hidden', '')
    local _, deps_synth = string.gsub(txt, '#%+deps', '')
    return hidden_explicit == 1 and deps_explicit == 1 and hidden_synth == 0 and deps_synth == 0
  end, 6000)

  eq(H.session_prompt_text(), '#hidden #deps')
end)

return T
