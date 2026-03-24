local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['moving to an existing split does not hide Meta UI'] = H.timed_case(function()
  H.open_fixture_file('README.md')
  H.child.cmd('vsplit')
  H.child.cmd('wincmd h')

  H.child.type_keys(':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active()
  end, 4000)

  H.wait_for(function()
    return H.session_prompt_win_height() > 0
  end, 4000)

  H.child.cmd('wincmd l')
  vim.loop.sleep(120)

  eq(H.session_ui_hidden(), false)
  eq(H.session_prompt_win_height() > 0, true)
end)

return T
