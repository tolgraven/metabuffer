local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['preview stays right-anchored and widens when editor widens'] = H.timed_case(function()
  local lines = {}
  for i = 1, 160 do
    lines[#lines + 1] = ('preview resize line ' .. i)
  end
  H.open_meta_with_lines(lines)

  H.wait_for(function()
    return H.session_preview_visible()
  end, 3000)

  local before_width = H.session_preview_width()
  local before_cols = H.editor_columns()

  H.resize_editor_columns(before_cols + 24)

  H.wait_for(function()
    return H.session_preview_width() > before_width
  end, 3000)

  eq(H.session_preview_screen_right(), H.editor_columns())
end)

return T
