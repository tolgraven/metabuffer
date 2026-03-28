local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['regular Meta started low in file keeps info synced on immediate page-up'] = H.timed_case(function()
  local lines = {}
  for i = 1, 320 do
    lines[#lines + 1] = string.format('line %03d', i)
  end

  H.child.cmd('enew')
  H.child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  H.child.cmd('normal! 240G')
  H.set_source_buf_to_current()
  H.child.type_keys(':', 'Meta', '<CR>')

  H.wait_for(function()
    return H.session_active()
      and H.session_preview_visible()
      and type(H.session_info_snapshot()) == 'table'
  end, 3000)

  H.feed_prompt_key('<C-b>', 'normal')

  H.wait_for(function()
    local main_view = H.session_main_view()
    local info_view = H.session_info_view()
    return type(main_view) == 'table'
      and type(info_view) == 'table'
      and info_view.topline == main_view.topline
  end, 3000)

  eq(H.session_prompt_focused(), true)
end)

return T
