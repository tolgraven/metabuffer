local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['plain :Meta launches session with prompt and info window'] = H.timed_case(function()
  H.open_meta_with_lines({
    'alpha one',
    'alpha two',
    'beta three',
    'gamma four',
  })

  H.wait_for(function()
    return H.session_prompt_win_height() > 0
  end, 3000)

  H.wait_for(function()
    return type(H.session_info_snapshot()) == 'table'
  end, 3000)

  H.wait_for(function()
    return H.session_preview_visible()
  end, 3000)

  vim.loop.sleep(800)

  eq(H.session_active(), true)
  eq(H.session_ui_hidden(), false)
  eq(H.session_prompt_win_height() > 0, true)
  eq(type(H.session_info_snapshot()), 'table')
  eq(H.session_preview_visible(), true)
end)

return T
