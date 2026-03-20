local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['clearing a zero-hit query restores the previous selection instead of jumping to line 1'] = H.timed_case(function()
  local lines = {}
  for i = 1, 80 do
    lines[i] = ('meta line %03d'):format(i)
  end

  H.open_meta_with_lines(lines)
  child.cmd('stopinsert')

  for _ = 1, 24 do
    H.type_prompt('<C-n>')
  end

  local before = H.session_selected_ref()
  eq(type(before), 'table')
  eq(before.lnum > 20, true)

  H.type_prompt_text('mud')
  H.wait_for(function()
    return H.session_hit_count() == 0
  end, 3000)

  child.lua([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      assert(s and s['prompt-buf'], 'missing session')
      vim.api.nvim_buf_set_lines(s['prompt-buf'], 0, -1, false, { '' })
      router['on-prompt-changed'](s['prompt-buf'], true)
    end)()
  ]])

  H.wait_for(function()
    return H.session_hit_count() == 80
  end, 3000)

  local after = H.session_selected_ref()
  eq(type(after), 'table')
  eq(after.lnum, before.lnum)
end)

return T
