local H = require('tests.screen.support.screen_helpers')
local child, eq = H.child, H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['MetaCursorWord starts append-ready at end of seeded prompt text'] = H.timed_case(function()
  child.cmd('enew')
  child.api.nvim_buf_set_lines(0, 0, -1, false, {
    'alpha target omega',
    'second line',
  })
  child.api.nvim_win_set_cursor(0, { 1, 7 })
  H.set_source_buf_to_current()

  child.cmd('MetaCursorWord')

  H.wait_for(function()
    return H.session_active()
  end, 3000)

  eq(H.session_prompt_text(), 'target ')

  H.type_prompt_text('beta')
  H.wait_for(function()
    return H.session_prompt_text() == 'target beta'
  end, 3000)
end)

return T
