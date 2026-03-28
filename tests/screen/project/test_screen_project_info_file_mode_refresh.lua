local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project info window refreshes immediately when switching into file mode'] = H.timed_case(function()
  local root = H.make_temp_project()
  H.open_project_meta_in_dir(root, 'main.txt')

  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and snap.line ~= ''
  end, 6000)

  H.child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      vim.api.nvim_buf_set_lines(s['prompt-buf'], 0, -1, false, { '#file:README.md' })
      router['on-prompt-changed'](s['prompt-buf'], true)
    end)()
  ]])

  H.wait_for(function() return H.session_prompt_text() == '#file:README.md' end, 6000)
  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return snap and H.str_contains(snap.line, 'README.md')
  end, 6000)

  local snap = H.session_info_snapshot()
  eq(H.str_contains(snap.line, 'README.md'), true)
end)

return T
