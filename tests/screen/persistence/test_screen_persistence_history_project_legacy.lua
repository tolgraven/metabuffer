local H = require('tests.screen.support.screen_helpers')
local child = H.child

local T = MiniTest.new_set({ hooks = H.case_hooks() })

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
