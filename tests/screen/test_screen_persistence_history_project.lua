local H = require('tests.screen.support.screen_helpers')
local child = H.child

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project history replay keeps typed non-consumed flags and avoids synthetic defaults'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_human('#file README.md', 90)
  H.wait_for(function() return H.session_prompt_text() == '#file README.md' end, 6000)
  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end, 6000)

  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.cmd('Meta! !!')
  H.wait_for(function() return H.session_active() end, 6000)
  H.wait_for(function()
    local txt = H.session_prompt_text()
    if txt ~= '#file README.md' then return false end
    return (not H.str_contains(txt, '#+file'))
      and (not H.str_contains(txt, '#-binary'))
      and (not H.str_contains(txt, '#-hex'))
  end, 6000)
end)

T['history up-recall does not accumulate duplicate consumed setting tokens'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_hit_count() > 0 end, 6000)

  H.type_prompt_human('#deps meta', 90)
  H.wait_for(function() return H.session_prompt_text() == 'meta' end, 6000)
  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end, 6000)

  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
  child.cmd('Meta!')
  H.wait_for(function() return H.session_active() end, 6000)
  H.type_prompt('<Up>')
  H.wait_for(function() return H.str_contains(H.session_prompt_text(), '#+deps') end, 6000)
  H.type_prompt('<CR>')
  H.wait_for(function() return not H.session_active() end, 6000)

  child.lua('_G.__meta_source_buf = vim.api.nvim_get_current_buf()')
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

T['history up-recall normalizes legacy #+file token into #file'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')
  H.wait_for(function() return H.session_active() end, 6000)

  child.lua([[
    table.insert(vim.g.metabuffer_prompt_history, "#+file README.md")
    local router = require('metabuffer.router')
    local s = router['active-by-source'][_G.__meta_source_buf]
    if s then s.history_cache = vim.deepcopy(vim.g.metabuffer_prompt_history) end
  ]])

  H.type_prompt('<Up>')
  H.wait_for(function() return H.session_prompt_text() == '#file README.md' end, 6000)
end)

return T
