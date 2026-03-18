local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['project bootstrap keeps initial results viewport stable after startup handoff'] = H.timed_case(function()
  local root = H.make_temp_project()

  H.child.cmd('cd ' .. root)
  H.child.cmd('edit ' .. root .. '/main.txt')
  H.child.lua([[
    _G.__meta_source_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_cursor(0, { 180, 0 })
    vim.fn.winrestview({ topline = 165, lnum = 180, col = 0, leftcol = 0 })
  ]])

  H.child.type_keys(':', 'Meta!', '<CR>')
  vim.loop.sleep(150)
  H.child.lua("if vim.g.meta_test_no_startinsert then pcall(vim.cmd, 'stopinsert') end")

  H.wait_for(function()
    return H.session_active()
  end, 6000)

  H.wait_for(function()
    local view = H.session_main_view()
    return view and view.lnum == 180 and view.topline == 165
  end, 6000)

  local before = H.session_main_view()
  eq(before.lnum, 180)
  eq(before.topline, 165)

  H.wait_for(function()
    return H.session_source_path_count() > 1
  end, 6000)

  H.wait_for(function()
    local view = H.session_main_view()
    return view and view.lnum == 180 and view.topline == 165
  end, 6000)

  local after = H.session_main_view()
  eq(after.lnum, 180)
  eq(after.topline, 165)
end)

return T
