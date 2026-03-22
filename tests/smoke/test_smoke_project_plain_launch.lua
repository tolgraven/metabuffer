local H = require('tests.screen.support.screen_helpers')
local eq = H.eq

local T = MiniTest.new_set({ hooks = H.case_hooks() })

T['plain :Meta! launches project session with prompt and info window'] = H.timed_case(function()
  H.child.lua([[
    require('metabuffer').setup({
      project_bootstrap_delay_ms = 400,
      project_bootstrap_idle_delay_ms = 400,
      ui = {
        animation = {
          enabled = true,
          loading_indicator = true,
          backend = 'mini',
        },
      },
    })
  ]])

  H.child.cmd('cd ' .. H.child.fn.getcwd())
  H.child.cmd('edit README.md')
  H.child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  H.child.type_keys(':', 'Meta!', '<CR>')
  vim.loop.sleep(150)
  H.child.lua("if vim.g.meta_test_no_startinsert then pcall(vim.cmd, 'stopinsert') end")

  H.wait_for(function()
    return H.session_prompt_win_height() > 0
  end, 6000)

  H.wait_for(function()
    local snap = H.session_info_snapshot()
    return type(snap) == 'table' and snap.count > 0
  end, 6000)

  H.wait_for(function()
    return H.session_preview_visible()
  end, 6000)

  vim.loop.sleep(800)

  eq(H.session_active(), true)
  eq(H.session_ui_hidden(), false)
  eq(H.session_prompt_win_height() > 0, true)
  eq(type(H.session_info_snapshot()), 'table')
  eq(H.session_preview_visible(), true)
end)

return T
