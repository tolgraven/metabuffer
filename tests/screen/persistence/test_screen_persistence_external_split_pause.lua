local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['opening help while Meta is visible hides Meta auxiliary UI'] = H.timed_case(function()
  H.open_fixture_file('README.md')

  H.child.type_keys(':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active()
  end, 4000)

  H.wait_for(function()
    return H.session_prompt_win_height() > 0
  end, 4000)

  H.type_prompt('<Esc>')
  H.child.type_keys(':', 'help help', '<CR>')

  H.wait_for(function()
    return H.session_ui_hidden()
  end, 4000)

  eq(H.session_ui_hidden(), true)
  eq(H.session_prompt_win_height(), -1)
  eq(H.child.lua_get("return vim.bo.filetype"), 'help')
end)

T['opening help while project Meta is visible hides Meta auxiliary UI'] = H.timed_case(function()
  H.open_project_meta_from_file('README.md')

  H.wait_for(function()
    return H.session_active()
  end, 4000)

  H.wait_for(function()
    return H.session_prompt_win_height() > 0
  end, 4000)

  H.type_prompt('<Esc>')
  H.child.type_keys(':', 'help help', '<CR>')

  H.wait_for(function()
    return H.session_ui_hidden()
  end, 4000)

  eq(H.session_ui_hidden(), true)
  eq(H.session_prompt_win_height(), -1)
  eq(H.child.lua_get("return vim.bo.filetype"), 'help')
end)

T['opening messages while Meta is visible hides Meta auxiliary UI'] = H.timed_case(function()
  H.open_fixture_file('README.md')

  H.child.type_keys(':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active()
  end, 4000)

  H.wait_for(function()
    return H.session_prompt_win_height() > 0
  end, 4000)

  H.type_prompt('<Esc>')
  H.child.type_keys(':', 'messages', '<CR>')

  H.wait_for(function()
    return H.session_ui_hidden()
  end, 4000)

  eq(H.session_ui_hidden(), true)
  eq(H.session_prompt_win_height(), -1)
end)

return T
